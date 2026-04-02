part of 'package:meong_nyang_diary/features/emotion/presentation/pages/emotion_result_page.dart';

// ── 카드 A: Hero · Delta · Distribution ─────────────────────
extension _EmotionResultCardsA on _EmotionResultPageState {
  Widget _buildHeroCard(
      String dominant, String name, IconData icon, double value, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.15),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 14.h, horizontal: 20.w),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [color, color.withValues(alpha: 0.75)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(20.r),
                topRight: Radius.circular(20.r),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 48.w,
                  height: 48.w,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(icon, size: 28.w, color: Colors.white),
                ),
                SizedBox(width: 12.w),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '주요 감정',
                      style: TextStyle(
                        fontSize: 11.sp,
                        color: Colors.white.withValues(alpha: 0.8),
                      ),
                    ),
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 22.sp,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
                const Spacer(),
                Text(
                  '${(value * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 28.sp,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Row(
              children: [
                if (widget.imagePaths.isNotEmpty)
                  _buildImageThumbnails()
                else
                  Container(
                    width: 88.w,
                    height: 88.w,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.pets, size: 40.w, color: color),
                  ),
                SizedBox(width: 14.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.access_time,
                              size: 13.w, color: Colors.grey),
                          SizedBox(width: 4.w),
                          Text(
                            _formatDateTime(widget.analysis.analyzedAt),
                            style: TextStyle(
                                fontSize: 11.sp, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      SizedBox(height: 8.h),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 10.w, vertical: 6.h),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8.r),
                        ),
                        child: Text(
                          _getShortDescription(dominant),
                          style: TextStyle(
                            fontSize: 12.sp,
                            color: color,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── 2. A-5: 이전 분석 대비 카드 ──
  Widget _buildDeltaCard() {
    if (!_historyLoaded) return const SizedBox.shrink();

    if (_previousAnalysis == null) {
      // 첫 분석
      if (widget.analysis.petId == null) return const SizedBox.shrink();
      return Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: _cardContainer(
          child: Row(
            children: [
              Icon(Icons.timeline_rounded, size: 18.w, color: Colors.grey[400]),
              SizedBox(width: 8.w),
              Text(
                '첫 분석이에요! 다음 분석부터 변화를 추적할 수 있어요.',
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final cur = widget.analysis.emotions;
    final prev = _previousAnalysis!.emotions;
    final deltas = [
      ('기쁨', cur.happiness - prev.happiness),
      ('슬픔', cur.sadness - prev.sadness),
      ('불안', cur.anxiety - prev.anxiety),
      ('졸림', cur.sleepiness - prev.sleepiness),
      ('호기심', cur.curiosity - prev.curiosity),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이전 분석 대비 변화',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: deltas.map((d) {
                final delta = d.$2;
                final pct = (delta.abs() * 100).toInt();
                if (pct == 0) return const SizedBox.shrink();
                final isUp = delta > 0;
                return Container(
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: (isUp ? Colors.green : Colors.red)
                        .withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.$1,
                          style: TextStyle(
                              fontSize: 12.sp, color: Colors.grey[700])),
                      SizedBox(width: 4.w),
                      Icon(
                        isUp
                            ? Icons.arrow_upward_rounded
                            : Icons.arrow_downward_rounded,
                        size: 14.w,
                        color: isUp ? Colors.green : Colors.red,
                      ),
                      Text(
                        '$pct%',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.bold,
                          color: isUp ? Colors.green : Colors.red,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 8.h),
            Text(
              '${_formatDateTime(_previousAnalysis!.analyzedAt)} 대비',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_distribution.dart
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildEmotionDistributionCard() {
    final emotions = [
      ('happiness', '😊 기쁨', widget.analysis.emotions.happiness),
      ('sadness', '😢 슬픔', widget.analysis.emotions.sadness),
      ('anxiety', '😰 불안', widget.analysis.emotions.anxiety),
      ('sleepiness', '😴 졸림', widget.analysis.emotions.sleepiness),
      ('curiosity', '🧐 호기심', widget.analysis.emotions.curiosity),
    ];
    emotions.sort((a, b) => b.$3.compareTo(a.$3));
    final dominant = widget.analysis.emotions.dominantEmotion;
    final hasFacial = widget.analysis.emotions.facialFeatures != null &&
        widget.analysis.emotions.facialFeatures!.isNotEmpty;

    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '감정 분포',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 14.h),
          ...emotions.map((e) {
            final key = e.$1;
            final name = e.$2;
            final value = e.$3;
            final color = AppTheme.getEmotionColor(key);
            final isMain = key == dominant;

            return Padding(
              padding: EdgeInsets.only(bottom: 10.h),
              child: Row(
                children: [
                  SizedBox(
                    width: 64.w,
                    child: Text(
                      name,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight:
                            isMain ? FontWeight.bold : FontWeight.normal,
                        color: isMain
                            ? AppTheme.primaryTextColor
                            : Colors.grey[600],
                      ),
                    ),
                  ),
                  SizedBox(width: 6.w),
                  Expanded(
                    child: Stack(
                      children: [
                        Container(
                          height: 10.h,
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(5.r),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: value,
                          child: Container(
                            height: 10.h,
                            decoration: BoxDecoration(
                              color: isMain
                                  ? color
                                  : color.withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(5.r),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(width: 8.w),
                  SizedBox(
                    width: 34.w,
                    child: Text(
                      '${(value * 100).toInt()}%',
                      textAlign: TextAlign.right,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight:
                            isMain ? FontWeight.bold : FontWeight.normal,
                        color: isMain ? color : Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
          SizedBox(height: 4.h),
          // 토글 버튼들
          Row(
            children: [
              Expanded(
                child: _buildToggleButton(
                  label: '감정 레이더',
                  icon: Icons.radar,
                  isActive: _chartMode == _ChartMode.radar,
                  onTap: () => setState(() => _chartMode =
                      _chartMode == _ChartMode.radar
                          ? _ChartMode.none
                          : _ChartMode.radar),
                ),
              ),
              if (hasFacial) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildToggleButton(
                    label: '부위별 분석',
                    icon: Icons.visibility_outlined,
                    isActive: _chartMode == _ChartMode.facial,
                    onTap: () => setState(() => _chartMode =
                        _chartMode == _ChartMode.facial
                            ? _ChartMode.none
                            : _ChartMode.facial),
                  ),
                ),
              ],
            ],
          ),
          // 토글 콘텐츠
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            child: _buildChartModeContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildToggleButton({
    required String label,
    required IconData icon,
    required bool isActive,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8.r),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 10.h),
        decoration: BoxDecoration(
          color: isActive
              ? AppTheme.primaryColor.withValues(alpha: 0.08)
              : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8.r),
          border: isActive
              ? Border.all(color: AppTheme.primaryColor.withValues(alpha: 0.3))
              : null,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isActive ? Icons.keyboard_arrow_up : icon,
              size: 16.w,
              color: AppTheme.primaryColor,
            ),
            SizedBox(width: 4.w),
            Text(
              isActive ? '$label 접기' : label,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartModeContent() {
    switch (_chartMode) {
      case _ChartMode.radar:
        return Padding(
          padding: EdgeInsets.only(top: 56.h, bottom: 8.h),
          child: Center(
            child: EmotionRadarChart(
              emotions: widget.analysis.emotions,
              size: 180.w,
            ),
          ),
        );
      case _ChartMode.facial:
        return _buildFacialFeaturesContent();
      case _ChartMode.none:
        return const SizedBox.shrink();
    }
  }

  // A-1: 부위별 분석 콘텐츠
  Widget _buildFacialFeaturesContent() {
    final features = widget.analysis.emotions.facialFeatures;
    if (features == null || features.isEmpty) return const SizedBox.shrink();

    final partLabels = {
      'eyes': ('눈', Icons.remove_red_eye_outlined),
      'ears': ('귀', Icons.hearing_outlined),
      'mouth': ('입', Icons.mood_outlined),
      'posture': ('자세', Icons.accessibility_new_outlined),
    };

    return Padding(
      padding: EdgeInsets.only(top: 16.h),
      child: Column(
        children: features.entries.map((entry) {
          final part = partLabels[entry.key];
          final label = part?.$1 ?? entry.key;
          final icon = part?.$2 ?? Icons.circle_outlined;
          final feature = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: 8.h),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F6FA),
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 18.w, color: AppTheme.primaryColor),
                  SizedBox(width: 10.w),
                  SizedBox(
                    width: 32.w,
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryTextColor,
                      ),
                    ),
                  ),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      feature.state,
                      style:
                          TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                    ),
                  ),
                  Container(
                    padding:
                        EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(6.r),
                    ),
                    child: Text(
                      feature.signal,
                      style: TextStyle(
                        fontSize: 10.sp,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.primaryColor,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_stress.dart
  // ══════════════════════════════════════════════════════════════════════════

}
