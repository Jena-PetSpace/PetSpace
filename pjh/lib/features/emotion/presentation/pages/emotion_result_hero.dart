part of 'emotion_result_page.dart';

  Widget _buildHeroCard(String dominant, String name, IconData icon,
      double value, Color color) {
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
                  padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
                  decoration: BoxDecoration(
                    color: (isUp ? Colors.green : Colors.red).withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8.r),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(d.$1, style: TextStyle(fontSize: 12.sp, color: Colors.grey[700])),
                      SizedBox(width: 4.w),
                      Icon(
                        isUp ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
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

  // ── 3. 감정 분포 + 레이더/부위별 통합 카드 ──
