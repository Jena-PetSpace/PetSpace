part of '../../pages/emotion_result_page.dart';

// ── BottomBar ─────────────────────────────────────────────────
extension _EmotionResultBottom on _EmotionResultPageState {
  Widget _buildBottomBar() {
    return Container(
      padding: EdgeInsets.fromLTRB(16.w, 12.h, 16.w, 24.h),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.06),
            blurRadius: 8,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Row(
        children: [
          // 시스템 공유
          SizedBox(
            height: 48.h,
            width: 48.h,
            child: OutlinedButton(
              onPressed: _shareResult,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Icon(Icons.share_outlined,
                  size: 20.w, color: Colors.grey[700]),
            ),
          ),
          SizedBox(width: 8.w),
          // 피드에 공유 버튼
          SizedBox(
            height: 48.h,
            width: 48.h,
            child: OutlinedButton(
              onPressed: () => _showShareToFeedSheet(context),
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12.r),
                ),
                side: BorderSide(
                    color: AppTheme.primaryColor.withValues(alpha: 0.5)),
              ),
              child: SvgPicture.asset(
                'assets/svg/icon_feed.svg',
                width: 22.w,
                height: 22.w,
                colorFilter: const ColorFilter.mode(
                  AppTheme.primaryColor,
                  BlendMode.srcIn,
                ),
              ),
            ),
          ),
          SizedBox(width: 8.w),
          // AI 히스토리 이동 버튼 (자동 저장 완료)
          Expanded(
            child: SizedBox(
              height: 48.h,
              child: ElevatedButton.icon(
                onPressed: () {
                  context.go('/ai-history-page');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.r),
                  ),
                  elevation: 0,
                ),
                icon: Icon(Icons.history, size: 18.w),
                label: Text(
                  '분석 히스토리 이동하기',
                  style: TextStyle(
                      fontSize: 14.sp, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

enum _ChartMode { none, radar, facial }

class _Recommendation {
  final IconData icon;
  final String title;
  final String body;
  _Recommendation(
      {required this.icon, required this.title, required this.body});
}
