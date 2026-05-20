part of '../../pages/emotion_result_page.dart';

// ── 카드 A: Hero · Delta · Distribution ─────────────────────
extension _EmotionResultCardsA on _EmotionResultPageState {
  /// 사진 장수에 따른 헤더 서브레이블
  String _imageCountLabel() {
    final count = widget.imagePaths.isNotEmpty
        ? widget.imagePaths.length
        : (widget.analysis.imageUrl.isNotEmpty ? 1 : 0);
    if (count == 0) return '주요 감정';
    if (count == 1) return '사진 1장 분석';
    return '사진 $count장 분석';
  }

  Widget _buildHeroCard(
      String dominant, String name, IconData icon, double value, Color color) {
    final paths = widget.imagePaths;
    final networkUrl = widget.analysis.imageUrl;
    final allPaths = paths.isNotEmpty
        ? paths
        : (networkUrl.isNotEmpty ? [networkUrl] : <String>[]);

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
          // 상단 gradient 헤더
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
                      _imageCountLabel(),
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
          // 갤러리 + 설명 영역
          Padding(
            padding: EdgeInsets.all(16.w),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 이미지 갤러리
                if (allPaths.isNotEmpty)
                  MultiImageGalleryWidget(
                    imagePaths: allPaths,
                    height: 200,
                    borderRadius: BorderRadius.circular(12.r),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 80.h,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12.r),
                    ),
                    child: Icon(Icons.pets, size: 40.w, color: color),
                  ),
                SizedBox(height: 12.h),
                // 날짜
                Row(
                  children: [
                    Icon(Icons.access_time, size: 13.w, color: Colors.grey),
                    SizedBox(width: 4.w),
                    Text(
                      _formatDateTime(widget.analysis.analyzedAt),
                      style: TextStyle(fontSize: 11.sp, color: Colors.grey[600]),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                // 설명 박스
                Container(
                  width: double.infinity,
                  padding:
                      EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12.r),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Text(
                    _getShortDescription(dominant),
                    style: TextStyle(
                      fontSize: 13.sp,
                      color: color,
                      fontWeight: FontWeight.w600,
                      height: 1.5,
                    ),
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
      ('기쁨',   cur.happiness  - prev.happiness),
      ('편안함', cur.calm       - prev.calm),
      ('흥분',   cur.excitement - prev.excitement),
      ('호기심', cur.curiosity  - prev.curiosity),
      ('불안',   cur.anxiety    - prev.anxiety),
      ('공포',   cur.fear       - prev.fear),
      ('슬픔',   cur.sadness    - prev.sadness),
      ('불편함', cur.discomfort - prev.discomfort),
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
    final emotions = AppTheme.emotionOrder.map((key) => (
      key,
      '${AppTheme.getEmotionEmoji(key)} ${AppTheme.getEmotionLabel(key)}',
      _getEmotionValue(key),
    )).toList();
    final dominant = widget.analysis.emotions.dominantEmotion;
    // 주요 감정 최상단 고정 + 나머지는 % 내림차순
    emotions.sort((a, b) {
      if (a.$1 == dominant) return -1;
      if (b.$1 == dominant) return 1;
      return b.$3.compareTo(a.$3);
    });
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
                  onTap: () {
                    // ignore: invalid_use_of_protected_member
                    setState(() => _chartMode = _chartMode == _ChartMode.radar ? _ChartMode.none : _ChartMode.radar);
                  },
                ),
              ),
              if (hasFacial) ...[
                SizedBox(width: 8.w),
                Expanded(
                  child: _buildToggleButton(
                    label: '부위별 분석',
                    icon: Icons.visibility_outlined,
                    isActive: _chartMode == _ChartMode.facial,
                    onTap: () {
                      // ignore: invalid_use_of_protected_member
                      setState(() => _chartMode = _chartMode == _ChartMode.facial ? _ChartMode.none : _ChartMode.facial);
                    },
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

  // ── 부위별 signal → 색상 매핑 ──
  Color _signalColor(String signal) {
    final s = signal.toLowerCase();
    if (s.contains('이완') || s.contains('평온') || s.contains('안정') || s.contains('긍정')) {
      return const Color(0xFF2ECC71);
    }
    if (s.contains('경계') || s.contains('긴장') || s.contains('주의') || s.contains('흥분')) {
      return const Color(0xFFF39C12);
    }
    if (s.contains('불안') || s.contains('공포') || s.contains('두려') || s.contains('스트레스') || s.contains('부정')) {
      return const Color(0xFFE74C3C);
    }
    return AppTheme.primaryColor;
  }

  // ── A-1: 부위별 분석 — Option A 카드형 그리드 ──
  Widget _buildFacialFeaturesGrid() {
    final features = widget.analysis.emotions.facialFeatures;
    if (features == null || features.isEmpty) return const SizedBox.shrink();

    final partMeta = {
      'eyes':    ('눈',  Icons.remove_red_eye_outlined, '동공·눈꺼풀 상태'),
      'ears':    ('귀',  Icons.hearing_outlined,        '귀 방향·각도'),
      'mouth':   ('입',  Icons.mood_outlined,           '입 모양·긴장도'),
      'posture': ('자세', Icons.accessibility_new_outlined, '몸 전체 자세'),
    };

    final entries = features.entries.toList();

    return Padding(
      padding: EdgeInsets.only(top: 14.h),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 뷰 전환 토글
          Row(
            children: [
              _buildViewToggle('카드형', _facialViewMode == 0, () {
                // ignore: invalid_use_of_protected_member
                setState(() => _facialViewMode = 0);
              }),
              SizedBox(width: 8.w),
              _buildViewToggle('목록형', _facialViewMode == 1, () {
                // ignore: invalid_use_of_protected_member
                setState(() => _facialViewMode = 1);
              }),
            ],
          ),
          SizedBox(height: 12.h),
          if (_facialViewMode == 0)
            // Option A: 2열 카드 그리드
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10.w,
                mainAxisSpacing: 10.h,
                childAspectRatio: 1.05,
              ),
              itemCount: entries.length,
              itemBuilder: (context, i) {
                final key = entries[i].key;
                final feature = entries[i].value;
                final meta = partMeta[key];
                final label = meta?.$1 ?? key;
                final icon = meta?.$2 ?? Icons.circle_outlined;
                final hint = meta?.$3 ?? '';
                final color = _signalColor(feature.signal);

                return Container(
                  padding: EdgeInsets.all(12.w),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14.r),
                    border: Border.all(color: color.withValues(alpha: 0.25)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 헤더
                      Row(
                        children: [
                          Container(
                            width: 32.w,
                            height: 32.w,
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8.r),
                            ),
                            child: Icon(icon, size: 18.w, color: color),
                          ),
                          SizedBox(width: 8.w),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  label,
                                  style: TextStyle(
                                    fontSize: 13.sp,
                                    fontWeight: FontWeight.w700,
                                    color: AppTheme.primaryTextColor,
                                  ),
                                ),
                                Text(
                                  hint,
                                  style: TextStyle(
                                    fontSize: 9.sp,
                                    color: Colors.grey[400],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const Spacer(),
                      // 설명
                      Text(
                        feature.state,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11.sp,
                          color: Colors.grey[700],
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      // signal 배지
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(6.r),
                        ),
                        child: Text(
                          feature.signal,
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w700,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            )
          else
            // Option B: 타임라인형 목록
            Column(
              children: entries.asMap().entries.map((e) {
                final isLast = e.key == entries.length - 1;
                final key = e.value.key;
                final feature = e.value.value;
                final meta = partMeta[key];
                final label = meta?.$1 ?? key;
                final icon = meta?.$2 ?? Icons.circle_outlined;
                final color = _signalColor(feature.signal);

                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // 타임라인 라인 + 아이콘
                      SizedBox(
                        width: 36.w,
                        child: Column(
                          children: [
                            Container(
                              width: 36.w,
                              height: 36.w,
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.15),
                                shape: BoxShape.circle,
                                border: Border.all(color: color.withValues(alpha: 0.4)),
                              ),
                              child: Icon(icon, size: 18.w, color: color),
                            ),
                            if (!isLast)
                              Expanded(
                                child: Container(
                                  width: 2.w,
                                  color: Colors.grey.withValues(alpha: 0.2),
                                ),
                              ),
                          ],
                        ),
                      ),
                      SizedBox(width: 12.w),
                      // 내용
                      Expanded(
                        child: Padding(
                          padding: EdgeInsets.only(bottom: isLast ? 0 : 16.h),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      label,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontSize: 13.sp,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.primaryTextColor,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8.w),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 7.w, vertical: 2.h),
                                    decoration: BoxDecoration(
                                      color: color.withValues(alpha: 0.13),
                                      borderRadius: BorderRadius.circular(5.r),
                                    ),
                                    child: Text(
                                      feature.signal,
                                      style: TextStyle(
                                        fontSize: 10.sp,
                                        fontWeight: FontWeight.w700,
                                        color: color,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              SizedBox(height: 4.h),
                              Text(
                                feature.state,
                                softWrap: true,
                                style: TextStyle(
                                  fontSize: 12.sp,
                                  color: Colors.grey[600],
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _buildViewToggle(String label, bool isActive, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 5.h),
        decoration: BoxDecoration(
          color: isActive ? AppTheme.primaryColor : const Color(0xFFF5F6FA),
          borderRadius: BorderRadius.circular(8.r),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.sp,
            fontWeight: FontWeight.w600,
            color: isActive ? Colors.white : Colors.grey[500],
          ),
        ),
      ),
    );
  }

  // 하위 호환 — 기존 호출부 유지
  Widget _buildFacialFeaturesContent() => _buildFacialFeaturesGrid();

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_stress.dart
  // ══════════════════════════════════════════════════════════════════════════

}
