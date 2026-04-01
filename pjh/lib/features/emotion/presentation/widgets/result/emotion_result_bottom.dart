part of 'emotion_result_page.dart';

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
      child: BlocBuilder<EmotionAnalysisBloc, EmotionAnalysisState>(
        builder: (context, state) {
          final isLoading = state is EmotionAnalysisSaving;
          return Row(
            children: [
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
                  child: Icon(Icons.dynamic_feed_outlined,
                      size: 20.w, color: AppTheme.primaryColor),
                ),
              ),
              SizedBox(width: 8.w),
              Expanded(
                child: SizedBox(
                  height: 48.h,
                  child: ElevatedButton.icon(
                    onPressed: isLoading ? null : _saveAnalysis,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primaryColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12.r),
                      ),
                      elevation: 0,
                    ),
                    icon: isLoading
                        ? SizedBox(
                            width: 18.w,
                            height: 18.w,
                            child: const CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : Icon(Icons.bookmark_add_outlined, size: 18.w),
                    label: Text(
                      isLoading ? '저장 중...' : '결과 저장',
                      style: TextStyle(
                          fontSize: 14.sp, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ),
            ],
          );
        },
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
