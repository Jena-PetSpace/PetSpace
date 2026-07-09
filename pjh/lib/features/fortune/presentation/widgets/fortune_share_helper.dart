import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../mbti/presentation/theme/mbti_theme.dart';
import '../../domain/entities/daily_fortune.dart';
import 'fortune_share_card.dart';

/// 운세 결과 공유 헬퍼. MBTI 공유 정책을 그대로 차용한다.
///
/// 사진 동의 처리:
/// - 사진 포함 기본 OFF(사용자가 의식적으로 켜야 외부로 사진 나감).
/// - 켜면 다음부터 기억(shared_preferences).
/// - 사진 없는 pet → 토글 비활성 + 기본 🐾 일러스트.
/// - 최초 1회 "사진이 포함된 이미지가 만들어져요" 가벼운 토스트(동의 모달 아님,
///   법적 커버는 가입 동의).
class FortuneShareHelper {
  FortuneShareHelper._();

  static final GlobalKey _shareKey = GlobalKey();

  // MBTI 와 동일 키 재사용 — 사진 포함/안내 선택은 기능 무관하게 사용자 1명 기준
  // 일관되게 기억(운세에서 OFF 했다 켜면 MBTI 에도 반영). 통일 UX.
  static const String _kIncludePhotoPref = 'mbti_share_include_photo';
  static const String _kPhotoNoticeShown = 'mbti_share_photo_notice_shown';

  /// 공유 옵션 바텀시트 → 캡처 → 시스템 공유시트.
  ///
  /// [onShared] 는 공유 시트 호출 직후 콜백(분석 이벤트 연결용 — 작업 5).
  /// includePhoto 최종값을 인자로 받는다.
  static Future<void> share(
    BuildContext context, {
    required DailyFortune fortune,
    String? petName,
    String? petAvatarUrl,
    void Function(bool includePhoto)? onShared,
  }) async {
    final hasPhoto = petAvatarUrl != null && petAvatarUrl.trim().isNotEmpty;
    final prefs = await SharedPreferences.getInstance();
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
            content: Text('사진이 포함된 이미지가 만들어져요'),
            duration: Duration(seconds: 2),
          ));
        await prefs.setBool(_kPhotoNoticeShown, true);
      }
    }

    Uint8List? photoBytes;
    if (choice.includePhoto && hasPhoto) {
      photoBytes = await _fetchBytes(petAvatarUrl);
    }

    if (!context.mounted) return;
    await _captureAndShare(
      context,
      fortune: fortune,
      petName: petName,
      photoBytes: photoBytes,
      includePhoto: choice.includePhoto && photoBytes != null,
      onShared: onShared,
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
    required DailyFortune fortune,
    String? petName,
    Uint8List? photoBytes,
    required bool includePhoto,
    void Function(bool includePhoto)? onShared,
  }) async {
    final overlay = OverlayEntry(
      builder: (_) => Positioned(
        left: -2000, // 화면 밖
        top: 0,
        child: RepaintBoundary(
          key: _shareKey,
          child: FortuneShareCard(
            fortune: fortune,
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
      final file = File('${dir.path}/petspace_fortune_${fortune.dateKey}.png');
      await file.writeAsBytes(bytes);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: '#펫스페이스 #오늘의운세\n우리 아이의 오늘 운세를 봤어요! 🔮🐾',
        subject: '반려동물 오늘의 운세',
      );

      // 분석 이벤트(작업 5 에서 연결). 식별 정보 미포함.
      onShared?.call(includePhoto);
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
              '운세 카드 공유',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: MbtiTheme.textPrimary,
              ),
            ),
            const SizedBox(height: 16),
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
                  foregroundColor: Colors.white,
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
