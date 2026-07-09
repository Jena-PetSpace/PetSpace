import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/permission_helper.dart';
import '../../../../shared/themes/app_theme.dart';
import '../constants/camera_overlay_content.dart';
import '../constants/capture_guide_content.dart';

/// 부위별 오버레이 가이드를 얹은 인앱 커스텀 카메라 (Phase 2).
///
/// - 결과: `Navigator.pop<String?>(imagePath)` — 촬영 확정 시 압축된 JPEG 경로,
///   취소·실패 시 null. 호출부(analysis_guide_page)가 기존
///   `onImagesSelected([path])` 계약으로 전달한다.
/// - 폴백: 카메라 초기화 실패(CameraException)시에만 image_picker 시스템
///   카메라로 자동 전환. 권한 거부는 설정 안내(BottomSheet) 후 종료 —
///   CAMERA 선언 앱은 권한 미보유 시 ACTION_IMAGE_CAPTURE도 SecurityException
///   이므로 picker 폴백 금지 (실질 폴백은 가이드 화면의 갤러리 CTA).
class GuidedCameraPage extends StatefulWidget {
  final CaptureGuideType type;

  const GuidedCameraPage({super.key, required this.type});

  @override
  State<GuidedCameraPage> createState() => _GuidedCameraPageState();
}

class _GuidedCameraPageState extends State<GuidedCameraPage>
    with WidgetsBindingObserver {
  CameraController? _controller;
  bool _initializing = true;
  bool _overlayVisible = true;
  bool _torchOn = false;
  bool _taking = false;
  bool _saving = false;
  XFile? _captured; // 촬영 후 확인 화면 상태

  CameraOverlayContent get _overlay => CameraOverlayContent.of(widget.type);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setup();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  /// 백그라운드 전환 시 컨트롤러 해제, 복귀 시 재초기화 (크래시 방지 핵심).
  /// inactive는 알림창·다이얼로그·화면캡처 등으로도 수시 발생하므로,
  /// resumed에서 컨트롤러가 비어 있으면 반드시 다시 살린다.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused) {
      final controller = _controller;
      if (controller != null) {
        _controller = null;
        controller.dispose();
        if (mounted) setState(() {});
      }
    } else if (state == AppLifecycleState.resumed) {
      // 권한 다이얼로그도 resumed를 발생시키므로 최초 초기화 성공 후에만 재초기화
      if (_everInitialized && _controller == null) _initCamera();
    }
  }

  Future<void> _setup() async {
    // 주 경로(사진 추가 버튼)는 상류에서 이미 권한 보유.
    // 도움말 아이콘 경로 대비 방어적 확인 — 거부 시 설정 안내 후 종료.
    final granted = await PermissionHelper.ensureGranted(
      context,
      permission: Permission.camera,
      permissionName: '카메라',
      reason: '반려동물 사진 촬영을 위해 카메라 권한이 필요해요.',
    );
    if (!mounted) return;
    if (!granted) {
      Navigator.pop(context);
      return;
    }
    await _initCamera();
  }

  bool _initInFlight = false;
  bool _everInitialized = false;

  Future<void> _initCamera() async {
    if (_initInFlight) return;
    _initInFlight = true;
    CameraController? controller;
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) throw CameraException('noCamera', '카메라 없음');
      final back = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      controller = CameraController(
        back,
        ResolutionPreset.veryHigh, // 1080p — 근접 부위 디테일 유지 (화질 정책)
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      // 백그라운드 전환·이전 인스턴스 해제 지연과 겹치면 initialize()가
      // 완료되지 않을 수 있음 → 타임아웃으로 무한 로딩 차단
      await controller.initialize().timeout(const Duration(seconds: 8));
      if (!mounted) {
        controller.dispose();
        return;
      }
      if (_torchOn) {
        try {
          await controller.setFlashMode(FlashMode.torch);
        } on CameraException {
          _torchOn = false;
        }
      }
      _everInitialized = true;
      setState(() {
        _controller = controller;
        _initializing = false;
      });
    } catch (_) {
      try {
        await controller?.dispose();
      } catch (_) {}
      await _fallbackToSystemCamera();
    } finally {
      _initInFlight = false;
    }
  }

  /// 초기화 실패 폴백 — 권한은 보유 상태이므로 시스템 카메라 사용 가능.
  Future<void> _fallbackToSystemCamera() async {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('카메라를 열 수 없어 기본 카메라로 전환합니다.')),
    );
    XFile? shot;
    try {
      shot = await ImagePicker().pickImage(
        source: ImageSource.camera,
        imageQuality: AppConstants.imageQuality,
        preferredCameraDevice: CameraDevice.rear,
      );
    } catch (_) {
      shot = null;
    }
    if (!mounted) return;
    Navigator.pop(context, shot?.path);
  }

  Future<void> _toggleTorch() async {
    final controller = _controller;
    if (controller == null) return;
    final next = !_torchOn;
    try {
      await controller.setFlashMode(next ? FlashMode.torch : FlashMode.off);
      setState(() => _torchOn = next);
    } on CameraException {
      // 플래시 미지원 기기 — 무시
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized || _taking) {
      return;
    }
    setState(() => _taking = true);
    try {
      final file = await controller.takePicture();
      await controller.pausePreview();
      if (!mounted) return;
      setState(() {
        _captured = file;
        _taking = false;
      });
    } on CameraException {
      if (!mounted) return;
      setState(() => _taking = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('촬영에 실패했어요. 다시 시도해주세요.')),
      );
    }
  }

  Future<void> _retake() async {
    final captured = _captured;
    setState(() => _captured = null);
    if (captured != null) {
      try {
        await File(captured.path).delete();
      } catch (_) {}
    }
    try {
      await _controller?.resumePreview();
    } on CameraException {
      await _initCamera();
    }
  }

  /// 확정 — q85 JPEG 재압축(기존 image_picker 경로와 화질 정합) 후 pop.
  Future<void> _useCaptured() async {
    final captured = _captured;
    if (captured == null || _saving) return;
    setState(() => _saving = true);
    String resultPath = captured.path;
    try {
      final tempDir = await getTemporaryDirectory();
      final targetPath =
          '${tempDir.path}/guided_${DateTime.now().millisecondsSinceEpoch}.jpg';
      resultPath = await compute(
        _compressJpeg,
        _CompressArgs(captured.path, targetPath, AppConstants.imageQuality),
      );
    } catch (_) {
      // 압축 실패 시 원본 경로 그대로 사용
    }
    if (!mounted) return;
    Navigator.pop(context, resultPath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _captured != null ? _buildConfirmView() : _buildCameraView(),
      ),
    );
  }

  // ── 촬영 화면 ──────────────────────────────────────────────

  Widget _buildCameraView() {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 3 / 4,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipRect(child: _buildPreviewCover()),
                  if (_overlayVisible && !_initializing)
                    Image.asset(
                      _overlay.assetPath,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  // 상단 안내 배너
                  Positioned(
                    top: 12.h,
                    left: 16.w,
                    right: 16.w,
                    child: Container(
                      padding: EdgeInsets.symmetric(
                          horizontal: 14.w, vertical: 8.h),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(20.r),
                      ),
                      child: Text(
                        _overlay.hint,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                  // 가이드/기본 토글
                  Positioned(
                    bottom: 12.h,
                    left: 0,
                    right: 0,
                    child: Center(child: _buildOverlayToggle()),
                  ),
                ],
              ),
            ),
          ),
        ),
        _buildControlBar(),
      ],
    );
  }

  Widget _buildPreviewCover() {
    final controller = _controller;
    if (_initializing || controller == null || !controller.value.isInitialized) {
      return const ColoredBox(
        color: Colors.black,
        child: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    // previewSize는 센서 기준 가로형(w>h) — 세로 화면에선 축을 뒤집어
    // 3:4 박스를 cover로 채운다 (기기별 프리뷰 비율과 무관하게 왜곡 없음).
    final previewSize = controller.value.previewSize!;
    return FittedBox(
      fit: BoxFit.cover,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: previewSize.height,
        height: previewSize.width,
        child: CameraPreview(controller),
      ),
    );
  }

  Widget _buildOverlayToggle() {
    return Container(
      padding: EdgeInsets.all(3.w),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleChip(label: '가이드', selected: _overlayVisible),
          _toggleChip(label: '기본', selected: !_overlayVisible),
        ],
      ),
    );
  }

  Widget _toggleChip({required String label, required bool selected}) {
    return GestureDetector(
      onTap: () => setState(() => _overlayVisible = label == '가이드'),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 6.h),
        decoration: BoxDecoration(
          color: selected ? AppTheme.highlightColor : Colors.transparent,
          borderRadius: BorderRadius.circular(15.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12.sp,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : Colors.white70,
          ),
        ),
      ),
    );
  }

  Widget _buildControlBar() {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 18.h, horizontal: 32.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // 플래시(토치) — 근접 부위 촬영용
          IconButton(
            onPressed: _toggleTorch,
            icon: Icon(
              _torchOn ? Icons.flash_on : Icons.flash_off,
              size: 26.w,
              color: _torchOn ? AppTheme.highlightColor : Colors.white,
            ),
            tooltip: '플래시',
          ),
          // 셔터
          GestureDetector(
            onTap: _takePicture,
            child: Container(
              width: 72.w,
              height: 72.w,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 4),
              ),
              padding: EdgeInsets.all(5.w),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _taking
                      ? AppTheme.primaryColor.withValues(alpha: 0.5)
                      : AppTheme.primaryColor,
                ),
              ),
            ),
          ),
          // 닫기
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: Icon(Icons.close, size: 26.w, color: Colors.white),
            tooltip: '닫기',
          ),
        ],
      ),
    );
  }

  // ── 확인 화면 ──────────────────────────────────────────────

  Widget _buildConfirmView() {
    final captured = _captured!;
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Image.file(
            File(captured.path),
            fit: BoxFit.contain,
          ),
        ),
        if (_saving)
          Container(
            color: Colors.black.withValues(alpha: 0.4),
            child: const Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        Positioned(
          left: 20.w,
          right: 20.w,
          bottom: 20.h,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : _retake,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: const BorderSide(color: Colors.white),
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                  ),
                  child: Text(
                    '다시 촬영',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              SizedBox(width: 12.w),
              Expanded(
                child: ElevatedButton(
                  onPressed: _saving ? null : _useCaptured,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.actionBase,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 14.h),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    '이 사진 사용',
                    style: TextStyle(
                      fontSize: 14.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CompressArgs {
  final String sourcePath;
  final String targetPath;
  final int quality;
  const _CompressArgs(this.sourcePath, this.targetPath, this.quality);
}

/// 격리(isolate)에서 실행되는 JPEG 재압축 — EXIF 회전 보정 포함.
/// 디코딩 실패 등 문제 시 원본 경로 반환.
String _compressJpeg(_CompressArgs args) {
  final bytes = File(args.sourcePath).readAsBytesSync();
  final decoded = img.decodeImage(bytes);
  if (decoded == null) return args.sourcePath;
  final oriented = img.bakeOrientation(decoded);
  final encoded = img.encodeJpg(oriented, quality: args.quality);
  File(args.targetPath).writeAsBytesSync(encoded);
  return args.targetPath;
}
