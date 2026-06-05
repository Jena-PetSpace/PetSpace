import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/services/analytics_service.dart';
import '../../domain/entities/mbti_content.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../theme/mbti_theme.dart';
import 'mbti_share_card.dart';

/// MBTI 결과 공유 헬퍼.
///
/// 사진 동의 처리:
/// - 사진 포함 기본 OFF(사용자가 의식적으로 켜야 외부로 사진 나감).
/// - 켜면 다음부터 기억(shared_preferences).
/// - 사진 없는 pet → 토글 비활성 + 기본 발바닥 일러스트.
/// - 최초 1회 "사진 포함 이미지가 만들어져요" 가벼운 토스트 안내(동의 모달 아님,
///   법적 커버는 가입 동의).
class MbtiShareHelper {
  MbtiShareHelper._();

  static final GlobalKey _shareKey = GlobalKey();

  // 사진 포함 토글 기억 / 최초 안내 1회 키
  static const String _kIncludePhotoPref = 'mbti_share_include_photo';
  static const String _kPhotoNoticeShown = 'mbti_share_photo_notice_shown';

  /// 공유 옵션 바텀시트 → 캡처 → 시스템 공유시트.
  static Future<void> share(
    BuildContext context, {
    required PetMbtiResult result,
    required MbtiContent content,
    String? petName,
    String? petAvatarUrl,
  }) async {
    final hasPhoto = petAvatarUrl != null && petAvatarUrl.trim().isNotEmpty;
    final prefs = await SharedPreferences.getInstance();
    // 기본 OFF. 사진 있는 경우에만 이전 선택 기억.
    final remembered = prefs.getBool(_kIncludePhotoPref) ?? false;
    final initialInclude = hasPhoto && remembered;

    if (!context.mounted) return;

    final choice = await showModalBottomSheet<_ShareChoice>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => _ShareOptionsSheet(
        hasPhoto: hasPhoto,
        initialIncludePhoto: initialInclude,
      ),
    );

    if (choice == null || !context.mounted) return;

    // 토글 선택 기억(사진 있을 때만 의미)
    if (hasPhoto) {
      await prefs.setBool(_kIncludePhotoPref, choice.includePhoto);
    }

    // 사진 포함 최초 1회 안내(토스트)
    if (choice.includePhoto) {
      final shown = prefs.getBool(_kPhotoNoticeShown) ?? false;
      if (!shown && context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(const SnackBar(
            content: Text('사진이 포함된 이미지가 만들어져요 🐾'),
            duration: Duration(seconds: 2),
          ));
        await prefs.setBool(_kPhotoNoticeShown, true);
      }
    }

    // 사진 포함 시 미리 바이트 확보(오프스크린 캡처용)
    Uint8List? photoBytes;
    if (choice.includePhoto && hasPhoto) {
      photoBytes = await _fetchBytes(petAvatarUrl);
    }

    if (!context.mounted) return;
    await _captureAndShare(
      context,
      result: result,
      content: content,
      petName: petName,
      photoBytes: photoBytes,
      includePhoto: choice.includePhoto && photoBytes != null,
    );
  }

  static Future<Uint8List?> _fetchBytes(String url) async {
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200) return resp.bodyBytes;
    } catch (_) {}
    return null;
  }

  static Future<void> _captureAndShare(
    BuildContext context, {
    required PetMbtiResult result,
    required MbtiContent content,
    String? petName,
    Uint8List? photoBytes,
    required bool includePhoto,
  }) async {
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -2000, // 화면 밖
        top: 0,
        child: RepaintBoundary(
          key: _shareKey,
          child: MbtiShareCard(
            result: result,
            content: content,
            petName: petName,
            photoBytes: photoBytes,
            includePhoto: includePhoto,
          ),
        ),
      ),
    );

    Overlay.of(context).insert(overlay);
    // 이미지 디코드/레이아웃 완료 대기
    await Future.delayed(const Duration(milliseconds: 250));

    try {
      final boundary =
          _shareKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/petspace_mbti_${result.typeCode}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '#펫스페이스 #반려동물MBTI\n우리 아이의 성격 유형을 알아봤어요! 🐾',
        subject: '반려동물 성격 유형 결과',
      );

      // 공유율 집계(익명). 식별 정보 미포함.
      AnalyticsService.instance.logMbtiShare(
        typeCode: result.typeCode,
        includePhoto: includePhoto,
      );
    } finally {
      overlay.remove();
    }
  }
}

class _ShareChoice {
  final bool includePhoto;
  const _ShareChoice(this.includePhoto);
}

class _ShareOptionsSheet extends StatefulWidget {
  final bool hasPhoto;
  final bool initialIncludePhoto;

  const _ShareOptionsSheet({
    required this.hasPhoto,
    required this.initialIncludePhoto,
  });

  @override
  State<_ShareOptionsSheet> createState() => _ShareOptionsSheetState();
}

class _ShareOptionsSheetState extends State<_ShareOptionsSheet> {
  late bool _includePhoto = widget.initialIncludePhoto;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              '결과 카드 공유',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: MbtiTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
            // 사진 포함 토글 (없으면 비활성 + 안내)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: MbtiTheme.bg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '반려동물 사진 포함',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: widget.hasPhoto
                                ? MbtiTheme.textPrimary
                                : MbtiTheme.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          widget.hasPhoto
                              ? '끄면 기본 이미지로 공유돼요'
                              : '등록된 사진이 없어 기본 이미지로 공유돼요',
                          style: const TextStyle(
                            fontSize: 11,
                            color: MbtiTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch(
                    value: _includePhoto,
                    onChanged: widget.hasPhoto
                        ? (v) => setState(() => _includePhoto = v)
                        : null,
                    activeThumbColor: MbtiTheme.navy,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pop(_ShareChoice(_includePhoto)),
                icon: const Icon(Icons.share, size: 18),
                label: const Text('공유하기',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: MbtiTheme.navy,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
