part of 'emotion_result_page.dart';

// ── 카드 C: Wellbeing · Stability · Diary · Recommend · Memo ─
extension _EmotionResultCardsC on _EmotionResultPageState {
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
                  padding:
                      EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
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
                        style:
                            TextStyle(fontSize: 12.sp, color: Colors.grey[700]),
                      ),
                      SizedBox(width: 6.w),
                      Container(
                        padding: EdgeInsets.symmetric(
                            horizontal: 6.w, vertical: 2.h),
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
                          child:
                              const CircularProgressIndicator(strokeWidth: 2),
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

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_social.dart
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildImageThumbnails() {
    final paths = widget.imagePaths;
    if (paths.length == 1) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12.r),
        child: Image.file(
          File(paths.first),
          width: 88.w,
          height: 88.w,
          fit: BoxFit.cover,
        ),
      );
    }
    return SizedBox(
      width: 88.w,
      height: 88.w,
      child: Stack(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(12.r),
            child: Image.file(
              File(paths.first),
              width: 88.w,
              height: 88.w,
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            bottom: 4.h,
            right: 4.w,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 5.w, vertical: 2.h),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.6),
                borderRadius: BorderRadius.circular(6.r),
              ),
              child: Text(
                '${paths.length}장',
                style: TextStyle(fontSize: 9.sp, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 9. 추천 카드 ──
  Widget _buildRecommendCard(String dominant, Color color) {
    final rec = _getSingleRecommendation(dominant);

    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            color.withValues(alpha: 0.08),
            color.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(20.r),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(rec.icon, size: 22.w, color: color),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '오늘의 추천',
                  style: TextStyle(
                    fontSize: 11.sp,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  rec.title,
                  style: TextStyle(
                    fontSize: 14.sp,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                SizedBox(height: 4.h),
                Text(
                  rec.body,
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: Colors.grey[600],
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ══════════════════════════════════════════════════════════════════════════
  // Methods from emotion_result_memo.dart
  // ══════════════════════════════════════════════════════════════════════════

  Widget _buildMemoCard() {
    return _cardContainer(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '메모',
            style: TextStyle(
              fontSize: 14.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 10.h),
          TextField(
            controller: _memoController,
            maxLines: 3,
            style: TextStyle(fontSize: 13.sp),
            decoration: InputDecoration(
              hintText: '이 순간에 대한 메모를 남겨보세요 (선택사항)',
              hintStyle:
                  TextStyle(fontSize: 12.sp, color: Colors.grey.shade400),
              filled: true,
              fillColor: const Color(0xFFF5F6FA),
              contentPadding:
                  EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10.r),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── 공통 카드 컨테이너 ──
  Widget _cardContainer({required Widget child}) {
    return Container(
      padding: EdgeInsets.all(16.w),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20.r),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: child,
    );
  }

  // ── 하단 고정 버튼 ──
}
