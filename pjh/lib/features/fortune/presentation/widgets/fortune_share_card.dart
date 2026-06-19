import 'dart:typed_data';

import 'package:flutter/material.dart';
import '../../../../shared/themes/app_theme.dart';

import '../../../mbti/presentation/theme/mbti_theme.dart';
import '../../domain/entities/daily_fortune.dart';
import 'fortune_stars.dart';

/// 공유용 운세 카드. 오프스크린에서 고정 크기로 렌더해 이미지로 캡처한다.
///
/// 구성: (사진 or 기본 🐾) + 날짜 + 종합 별점/이모지 + 종합운 한 줄 +
/// 세부 3개 별점 + 럭키 간식·플레이스 + petspace 워터마크.
///
/// 상세 화면과 동일 톤(흰/네이비/코랄). 말썽 항목 별점도 빨강 미사용.
/// ScreenUtil 대신 고정 px(캡처 일관성) — 별점 위젯엔 .sp 가 있어 폭 고정 박스로 감싼다.
class FortuneShareCard extends StatelessWidget {
  final DailyFortune fortune;
  final String? petName;

  /// 사진 포함 시 표시할 펫 사진 바이트(미리 받아 전달). null 이면 기본 🐾.
  final Uint8List? photoBytes;

  /// 사진 포함 여부(기본 OFF). false 면 photoBytes 가 있어도 기본 일러스트.
  final bool includePhoto;

  const FortuneShareCard({
    super.key,
    required this.fortune,
    this.petName,
    this.photoBytes,
    this.includePhoto = false,
  });

  static const double width = 340;

  @override
  Widget build(BuildContext context) {
    final name = (petName != null && petName!.trim().isNotEmpty)
        ? petName!.trim()
        : '우리 아이';

    return Material(
      type: MaterialType.transparency,
      child: Container(
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 상단 네이비 헤더: 아바타 + 날짜 + 종합 별점/이모지 + 종합운
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(24, 26, 24, 22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    MbtiTheme.navy,
                    MbtiTheme.navy.withValues(alpha: 0.82),
                  ],
                ),
                borderRadius:
                    const BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: Column(
                children: [
                  _avatar(),
                  const SizedBox(height: 12),
                  Text(
                    '$name 의 오늘의 운세',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white.withValues(alpha: 0.9),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _prettyDate(fortune.dateKey),
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.white.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(fortuneStarEmoji(fortune.overallStar),
                      style: const TextStyle(fontSize: 30)),
                  const SizedBox(height: 8),
                  _starsFixed(fortune.overallStar,
                      filled: Colors.white, size: 18),
                  const SizedBox(height: 12),
                  Text(
                    fortune.overall,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
            // 세부 항목 3개 (라벨 + 별점)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 4),
              child: Column(
                children: [
                  for (final item in fortune.items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            item.label,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              color: MbtiTheme.textPrimary,
                            ),
                          ),
                          _starsFixed(item.star,
                              filled: MbtiTheme.coral, size: 15),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            // 럭키 요소
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 6, 24, 4),
              child: Row(
                children: [
                  Expanded(
                    child: _luckyChip('🍖 럭키 간식', fortune.luckyTreat),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _luckyChip('📍 럭키 플레이스', fortune.luckyPlace),
                  ),
                ],
              ),
            ),
            // 워터마크 (유입 유도)
            const Padding(
              padding: EdgeInsets.fromLTRB(24, 10, 24, 18),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('🐾', style: TextStyle(fontSize: 13)),
                  SizedBox(width: 5),
                  Flexible(
                    child: Text(
                      'petspace 에서 우리 아이 오늘의 운세 보기',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: MbtiTheme.textSecondary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar() {
    const size = 72.0;
    final showPhoto = includePhoto && photoBytes != null;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.25),
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.6), width: 3),
      ),
      child: ClipOval(
        child: showPhoto
            ? Image.memory(photoBytes!,
                width: size, height: size, fit: BoxFit.cover)
            : const Center(
                child: Text('🐾', style: TextStyle(fontSize: 34)),
              ),
      ),
    );
  }

  Widget _luckyChip(String title, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: MbtiTheme.bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: const TextStyle(
                  fontSize: 10, color: MbtiTheme.textSecondary)),
          const SizedBox(height: 4),
          Text(value,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: MbtiTheme.navy)),
        ],
      ),
    );
  }

  /// 캡처 일관성을 위해 .sp 의존 없이 고정 크기 별점을 그린다.
  /// (FortuneStars 는 .sp 를 쓰므로 캡처 컨텍스트에서 ScreenUtil 미초기화 시
  ///  대비해 직접 아이콘으로 렌더.)
  Widget _starsFixed(int star, {required Color filled, required double size}) {
    final clamped = star.clamp(1, 5);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (int i = 1; i <= 5; i++)
          Icon(
            i <= clamped ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i <= clamped ? filled : AppTheme.neutral300,
          ),
      ],
    );
  }

  String _prettyDate(String key) {
    if (key.length != 8) return key;
    final y = key.substring(0, 4);
    final m = int.tryParse(key.substring(4, 6)) ?? 0;
    final d = int.tryParse(key.substring(6, 8)) ?? 0;
    return '$y년 $m월 $d일';
  }
}
