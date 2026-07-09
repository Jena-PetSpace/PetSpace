// v2-review: 결과 페이지 로컬 팔레트 — 리포트 톤 별도 기획 대상, 치환 보류.
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../domain/entities/emotion_analysis.dart';
import '../../theme/emotion_result_tokens.dart';

/// 부위별 분석 카드 (귀/눈/입/자세).
/// - 헤더: 라벨 + 카드형/목록형 토글
/// - 카드형: 2x2 그리드 (부위별 톤 배경)
/// - 목록형: 4개 행 (아이콘 + 부위명 + signal 칩 + state)
/// - facialFeatures가 null/빈 경우 호출 측에서 빌드하지 않음
class PartAnalysisCard extends StatefulWidget {
  final Map<String, FacialFeature> features;

  const PartAnalysisCard({super.key, required this.features});

  @override
  State<PartAnalysisCard> createState() => _PartAnalysisCardState();
}

enum _LayoutMode { card, list }

/// 부위별 표시 정보. 한글 라벨 + 아이콘 + 톤 색상.
class _PartMeta {
  final String key;
  final String label;
  final IconData icon;
  final Color bgColor;
  final Color borderColor;
  final Color iconColor;
  const _PartMeta({
    required this.key,
    required this.label,
    required this.icon,
    required this.bgColor,
    required this.borderColor,
    required this.iconColor,
  });
}

class _PartAnalysisCardState extends State<PartAnalysisCard> {
  _LayoutMode _mode = _LayoutMode.card;

  static const List<_PartMeta> _allParts = [
    _PartMeta(
      key: 'ears',
      label: '귀',
      icon: Icons.hearing_outlined,
      bgColor: EmotionResultTokens.coralLight,
      borderColor: EmotionResultTokens.coralBorder,
      iconColor: EmotionResultTokens.coral,
    ),
    _PartMeta(
      key: 'eyes',
      label: '눈',
      icon: Icons.visibility_outlined,
      bgColor: EmotionResultTokens.amberLight,
      borderColor: EmotionResultTokens.amberMid,
      iconColor: EmotionResultTokens.amber,
    ),
    _PartMeta(
      key: 'mouth',
      label: '입',
      icon: Icons.sentiment_satisfied_outlined,
      bgColor: Color(0xFFEEEEF1),
      borderColor: Color(0xFFDEDDE8),
      iconColor: EmotionResultTokens.grayDark,
    ),
    _PartMeta(
      key: 'posture',
      label: '자세',
      icon: Icons.accessibility_outlined,
      bgColor: EmotionResultTokens.amberLight,
      borderColor: EmotionResultTokens.amberMid,
      iconColor: EmotionResultTokens.amber,
    ),
  ];

  /// 4개 부위 중 features에 값이 있는 것만.
  List<({_PartMeta meta, FacialFeature feature})> _present() {
    return [
      for (final m in _allParts)
        if (widget.features[m.key] != null) (meta: m, feature: widget.features[m.key]!),
    ];
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: EmotionResultTokens.coralLight,
                borderRadius: BorderRadius.circular(4.r),
              ),
              child: Text(
                'AI가 살펴본 부위',
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: FontWeight.w500,
                  color: EmotionResultTokens.coralDark,
                ),
              ),
            ),
            SizedBox(width: 8.w),
            Text(
              '부위별 신호 4곳',
              style: TextStyle(
                fontSize: 15.sp,
                fontWeight: FontWeight.w500,
                color: EmotionResultTokens.textPrimary,
              ),
            ),
          ],
        ),
        _buildToggle(),
      ],
    );
  }

  Widget _buildToggle() {
    return Container(
      padding: EdgeInsets.all(2.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.amberSoft,
        borderRadius: BorderRadius.circular(8.r),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _toggleButton('카드형', _LayoutMode.card),
          _toggleButton('목록형', _LayoutMode.list),
        ],
      ),
    );
  }

  Widget _toggleButton(String label, _LayoutMode mode) {
    final selected = _mode == mode;
    return GestureDetector(
      onTap: () => setState(() => _mode = mode),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 4.h),
        decoration: BoxDecoration(
          color: selected ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected
                ? EmotionResultTokens.textPrimary
                : EmotionResultTokens.grayDark,
          ),
        ),
      ),
    );
  }

  Widget _signalChip(String signal, Color color) {
    if (signal.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(4.r),
      ),
      child: Text(
        signal,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          fontSize: 9.sp,
          fontWeight: FontWeight.w500,
          color: color,
          height: 1.35,
        ),
      ),
    );
  }

  // ── 카드형 (2x2 그리드) ────────────────────────────
  Widget _buildCardItem(_PartMeta meta, FacialFeature feature) {
    return Container(
      padding: EdgeInsets.all(12.r),
      decoration: BoxDecoration(
        color: meta.bgColor,
        borderRadius: BorderRadius.circular(10.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 24.r,
                height: 24.r,
                decoration: BoxDecoration(
                  color: meta.borderColor,
                  shape: BoxShape.circle,
                ),
                alignment: Alignment.center,
                child: Icon(meta.icon, size: 14.r, color: meta.iconColor),
              ),
              SizedBox(width: 6.w),
              Text(
                meta.label,
                style: TextStyle(
                  fontSize: 12.sp,
                  fontWeight: FontWeight.w500,
                  color: EmotionResultTokens.textPrimary,
                ),
              ),
            ],
          ),
          SizedBox(height: 8.h),
          Text(
            feature.state.isNotEmpty ? feature.state : '관찰 없음',
            style: TextStyle(
              fontSize: 11.sp,
              color: EmotionResultTokens.textSecondary,
              height: 1.4,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (feature.signal.isNotEmpty) ...[
            SizedBox(height: 6.h),
            Align(
              alignment: Alignment.centerLeft,
              child: _signalChip(feature.signal, meta.iconColor),
            ),
          ],
        ],
      ),
    );
  }

  /// 2개씩 묶어 행으로. IntrinsicHeight로 한 행의 두 카드가 높이를 공유하고,
  /// 셀 높이는 내용에 맞춰 늘어나 오버플로우가 발생하지 않는다.
  Widget _buildCardBody() {
    final items = _present();
    final rows = <Widget>[];
    for (int i = 0; i < items.length; i += 2) {
      final left = items[i];
      final hasRight = i + 1 < items.length;
      if (rows.isNotEmpty) rows.add(SizedBox(height: 8.h));
      rows.add(
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: _buildCardItem(left.meta, left.feature)),
              SizedBox(width: 8.w),
              Expanded(
                child: hasRight
                    ? _buildCardItem(items[i + 1].meta, items[i + 1].feature)
                    : const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      );
    }
    return Column(children: rows);
  }

  // ── 목록형 ────────────────────────────
  Widget _buildListItem(_PartMeta meta, FacialFeature feature) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28.r,
            height: 28.r,
            decoration: BoxDecoration(
              color: meta.bgColor,
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Icon(meta.icon, size: 16.r, color: meta.iconColor),
          ),
          SizedBox(width: 10.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      meta.label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w500,
                        color: EmotionResultTokens.textPrimary,
                      ),
                    ),
                    if (feature.signal.isNotEmpty) ...[
                      SizedBox(width: 6.w),
                      Flexible(
                        child: _signalChip(feature.signal, meta.iconColor),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 2.h),
                Text(
                  feature.state.isNotEmpty ? feature.state : '관찰 없음',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: EmotionResultTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildListBody() {
    final items = _present();
    return Column(
      children: [
        for (int i = 0; i < items.length; i++) ...[
          _buildListItem(items[i].meta, items[i].feature),
          if (i < items.length - 1)
            Divider(
              height: 1.h,
              thickness: 1,
              color: EmotionResultTokens.dividerLight,
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final present = _present();
    if (present.isEmpty) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: EmotionResultTokens.cardSurface,
        borderRadius: BorderRadius.circular(EmotionResultTokens.radiusCard.r),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader(),
          SizedBox(height: 12.h),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: _mode == _LayoutMode.card
                ? _buildCardBody()
                : _buildListBody(),
          ),
        ],
      ),
    );
  }
}
