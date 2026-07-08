import 'capture_guide_content.dart';

/// 커스텀 카메라(GuidedCameraPage)의 부위별 오버레이·안내 문구.
/// 오버레이 PNG는 1080x1440(3:4) 흰색 스트로크+투명 배경 —
/// 파일명 고정 계약(Phase 1과 동일), 디자인 개선은 PNG 교체만으로 반영.
class CameraOverlayContent {
  final String assetPath;
  final String hint;

  const CameraOverlayContent({required this.assetPath, required this.hint});

  static CameraOverlayContent of(CaptureGuideType type) => _contents[type]!;

  static const String _base = 'assets/images/capture_guide/overlay';

  static const Map<CaptureGuideType, CameraOverlayContent> _contents = {
    CaptureGuideType.emotion: CameraOverlayContent(
      assetPath: '$_base/emotion.png',
      hint: '가이드에 맞춰 정면 얼굴을 담아주세요',
    ),
    CaptureGuideType.eyeEar: CameraOverlayContent(
      assetPath: '$_base/eye_ear.png',
      hint: '틀 안에 눈 또는 귀 안쪽을 맞춰주세요',
    ),
    CaptureGuideType.noseMouth: CameraOverlayContent(
      assetPath: '$_base/nose_mouth.png',
      hint: '틀 안에 코 또는 잇몸을 맞춰주세요',
    ),
    CaptureGuideType.skinFur: CameraOverlayContent(
      assetPath: '$_base/skin_fur.png',
      hint: '영역 안에 이상 부위를 가까이 맞춰주세요',
    ),
    CaptureGuideType.bodyBcs: CameraOverlayContent(
      assetPath: '$_base/body_bcs.png',
      hint: '가이드에 맞춰 옆모습 전신을 담아주세요',
    ),
    CaptureGuideType.posture: CameraOverlayContent(
      assetPath: '$_base/posture.png',
      hint: '가이드에 맞춰 뒷모습을 촬영해주세요',
    ),
    CaptureGuideType.fullBody: CameraOverlayContent(
      assetPath: '$_base/full_body.png',
      hint: '가이드에 맞춰 전신을 담아주세요',
    ),
  };
}
