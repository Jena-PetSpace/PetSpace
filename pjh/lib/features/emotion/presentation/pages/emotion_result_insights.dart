part of 'emotion_result_page.dart';

  Widget _buildHealthTipsCard() {
    final tips = widget.analysis.emotions.healthTips;
    if (tips.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '건강 체크 알림',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 10.h),
            ...tips.map((tip) => Padding(
              padding: EdgeInsets.only(bottom: 6.h),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline,
                      size: 16.w, color: const Color(0xFF2ECC71)),
                  SizedBox(width: 8.w),
                  Expanded(
                    child: Text(
                      tip,
                      style: TextStyle(fontSize: 12.sp, color: Colors.grey[700], height: 1.4),
                    ),
                  ),
                ],
              ),
            )),
            SizedBox(height: 6.h),
            Text(
              '* AI 분석 결과로 참고용입니다. 정확한 진단은 수의사와 상담하세요.',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  // ── C-1: 멀티펫 비교 카드 ──
  Widget _buildMultiPetCard() {
    if (_otherPetAnalyses.isEmpty) return const SizedBox.shrink();

    final cur = widget.analysis.emotions;
    final emotionNames = {'happiness': '기쁨', 'sadness': '슬픔', 'anxiety': '불안', 'sleepiness': '졸림', 'curiosity': '호기심'};

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '다른 반려동물과 비교',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 12.h),
            ..._otherPetAnalyses.take(3).map((other) {
              final otherE = other.emotions;
              return Padding(
                padding: EdgeInsets.only(bottom: 10.h),
                child: Container(
                  padding: EdgeInsets.all(10.w),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF5F6FA),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '펫 ${other.petId?.substring(0, 6) ?? ""}',
                        style: TextStyle(
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.primaryTextColor,
                        ),
                      ),
                      SizedBox(height: 6.h),
                      Row(
                        children: [
                          ...emotionNames.entries.map((entry) {
                            final curVal = _getEmotionValueByKey(cur, entry.key);
                            final otherVal = _getEmotionValueByKey(otherE, entry.key);
                            final diff = curVal - otherVal;
                            if (diff.abs() < 0.05) return const SizedBox.shrink();
                            return Padding(
                              padding: EdgeInsets.only(right: 8.w),
                              child: Text(
                                '${entry.value} ${diff > 0 ? "+" : ""}${(diff * 100).toInt()}%',
                                style: TextStyle(
                                  fontSize: 10.sp,
                                  color: diff > 0 ? Colors.green : Colors.red,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            );
                          }),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  double _getEmotionValueByKey(EmotionScores e, String key) {
    switch (key) {
      case 'happiness': return e.happiness;
      case 'sadness': return e.sadness;
      case 'anxiety': return e.anxiety;
      case 'sleepiness': return e.sleepiness;
      case 'curiosity': return e.curiosity;
      default: return 0.0;
    }
  }

  // ── C-2: 커뮤니티 벤치마크 카드 ──
  Widget _buildCommunityCard() {
    if (_breedAverage == null) return const SizedBox.shrink();

    final avg = _breedAverage!;
    final count = (avg['count'] as num?)?.toInt() ?? 0;
    if (count == 0) return const SizedBox.shrink();

    final cur = widget.analysis.emotions;
    final comparisons = [
      ('기쁨', cur.happiness, (avg['happiness'] as num?)?.toDouble() ?? 0),
      ('슬픔', cur.sadness, (avg['sadness'] as num?)?.toDouble() ?? 0),
      ('불안', cur.anxiety, (avg['anxiety'] as num?)?.toDouble() ?? 0),
      ('졸림', cur.sleepiness, (avg['sleepiness'] as num?)?.toDouble() ?? 0),
      ('호기심', cur.curiosity, (avg['curiosity'] as num?)?.toDouble() ?? 0),
    ];

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '같은 품종 평균 대비',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '$count건 기준',
                  style: TextStyle(fontSize: 10.sp, color: Colors.grey[500]),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            ...comparisons.map((c) {
              final name = c.$1;
              final mine = c.$2;
              final breedAvg = c.$3;
              final diff = mine - breedAvg;

              return Padding(
                padding: EdgeInsets.only(bottom: 8.h),
                child: Row(
                  children: [
                    SizedBox(
                      width: 44.w,
                      child: Text(name, style: TextStyle(fontSize: 12.sp, color: Colors.grey[700])),
                    ),
                    Expanded(
                      child: Stack(
                        children: [
                          Container(
                            height: 8.h,
                            decoration: BoxDecoration(
                              color: Colors.grey.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4.r),
                            ),
                          ),
                          // 품종 평균 마커
                          Positioned(
                            left: (breedAvg * 100).clamp(0, 100) / 100 *
                                (MediaQuery.of(context).size.width - 130.w),
                            child: Container(
                              width: 2.w,
                              height: 8.h,
                              color: Colors.grey[400],
                            ),
                          ),
                          // 현재 값 바
                          FractionallySizedBox(
                            widthFactor: mine.clamp(0.0, 1.0),
                            child: Container(
                              height: 8.h,
                              decoration: BoxDecoration(
                                color: AppTheme.primaryColor.withValues(alpha: 0.6),
                                borderRadius: BorderRadius.circular(4.r),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 6.w),
                    SizedBox(
                      width: 40.w,
                      child: Text(
                        '${diff > 0 ? "+" : ""}${(diff * 100).toInt()}%',
                        textAlign: TextAlign.right,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight: FontWeight.w600,
                          color: diff.abs() < 0.05
                              ? Colors.grey[500]
                              : diff > 0
                                  ? Colors.green
                                  : Colors.red,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            SizedBox(height: 4.h),
            Text(
              '회색 선: 같은 품종 평균',
              style: TextStyle(fontSize: 10.sp, color: Colors.grey[400]),
            ),
          ],
        ),
      ),
    );
  }

  // ── 9. B-1: 웰빙 점수 카드 ──
  Widget _buildWellbeingCard() {
    if (!_historyLoaded) return const SizedBox.shrink();

    if (!_insights.hasEnoughData) {
      return Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: _cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '웰빙 점수',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _insights.emptyStateMessage,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final score = _insights.wellbeingScore;
    final color = score >= 70
        ? const Color(0xFF2ECC71)
        : score >= 40
            ? const Color(0xFFF39C12)
            : const Color(0xFFE74C3C);
    final label = score >= 70
        ? '좋음'
        : score >= 40
            ? '보통'
            : '관심 필요';

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '웰빙 점수',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6.r),
                  ),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 11.sp,
                      fontWeight: FontWeight.bold,
                      color: color,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${score.toInt()}',
                  style: TextStyle(
                    fontSize: 36.sp,
                    fontWeight: FontWeight.bold,
                    color: color,
                    height: 1,
                  ),
                ),
                Padding(
                  padding: EdgeInsets.only(bottom: 4.h, left: 2.w),
                  child: Text(
                    '/ 100',
                    style: TextStyle(fontSize: 13.sp, color: Colors.grey[400]),
                  ),
                ),
              ],
            ),
            SizedBox(height: 10.h),
            ClipRRect(
              borderRadius: BorderRadius.circular(4.r),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 6.h,
                backgroundColor: Colors.grey.withValues(alpha: 0.1),
                valueColor: AlwaysStoppedAnimation<Color>(color),
              ),
            ),
            SizedBox(height: 8.h),
            Text(
              '최근 분석 기록 기반 종합 웰빙 지수입니다.',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── 10. B-3: 감정 안정성 카드 ──
  Widget _buildStabilityCard() {
    if (!_historyLoaded) return const SizedBox.shrink();

    if (!_insights.hasEnoughData) {
      return Padding(
        padding: EdgeInsets.only(bottom: 14.h),
        child: _cardContainer(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '감정 안정성',
                style: TextStyle(
                  fontSize: 14.sp,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              SizedBox(height: 8.h),
              Text(
                _insights.emptyStateMessage,
                style: TextStyle(fontSize: 12.sp, color: Colors.grey[500]),
              ),
            ],
          ),
        ),
      );
    }

    final emotionNames = {
      'happiness': '기쁨',
      'sadness': '슬픔',
      'anxiety': '불안',
      'sleepiness': '졸림',
      'curiosity': '호기심',
    };

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  '감정 안정성',
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                const Spacer(),
                Text(
                  '종합 ${(_insights.stabilityIndex * 100).toInt()}%',
                  style: TextStyle(
                    fontSize: 12.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryColor,
                  ),
                ),
              ],
            ),
            SizedBox(height: 12.h),
            Wrap(
              spacing: 8.w,
              runSpacing: 8.h,
              children: _insights.emotionStability.entries.map((entry) {
                final name = emotionNames[entry.key] ?? entry.key;
                final stability = entry.value;
                final isStable = stability >= 0.6;
                final color = isStable
                    ? const Color(0xFF2ECC71)
                    : const Color(0xFFF39C12);

                return Container(
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8.r),
                    border: Border.all(color: color.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        name,
                        style: TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6.w, vertical: 2.h),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(4.r),
                        ),
                        child: Text(
                          isStable ? '안정' : '변동',
                          style: TextStyle(
                            fontSize: 10.sp,
                            fontWeight: FontWeight.bold,
                            color: color,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            SizedBox(height: 8.h),
            Text(
              '최근 분석 기록을 기반으로 각 감정의 변동 정도를 분석했어요.',
              style: TextStyle(fontSize: 11.sp, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }

  // ── 11. B-4: 이번주 감정 일기 카드 ──
  Widget _buildDiaryCard() {
    if (!_historyLoaded) return const SizedBox.shrink();

    if (_fullHistory.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: EdgeInsets.only(bottom: 14.h),
      child: _cardContainer(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '이번주 감정 일기',
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.bold,
                color: AppTheme.primaryTextColor,
              ),
            ),
            SizedBox(height: 10.h),
            if (_diaryText != null)
              Container(
                width: double.infinity,
                padding: EdgeInsets.all(12.w),
                decoration: BoxDecoration(
                  color: const Color(0xFF8E44AD).withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                child: Text(
                  _diaryText!,
                  style: TextStyle(
                    fontSize: 13.sp,
                    color: Colors.grey[700],
                    height: 1.6,
                  ),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _diaryLoading ? null : _generateDiary,
                  icon: _diaryLoading
                      ? SizedBox(
                          width: 16.w,
                          height: 16.w,
                          child: const CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.auto_awesome, size: 16.w),
                  label: Text(
                    _diaryLoading ? '생성 중...' : '이번주 일기 생성하기',
                    style: TextStyle(fontSize: 13.sp),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF8E44AD),
                    side: const BorderSide(color: Color(0xFF8E44AD)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.r),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 12.h),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ── 썸네일 ──
