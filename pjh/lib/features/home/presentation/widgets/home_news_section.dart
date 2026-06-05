import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

/// 뉴스 섹션 — 외부 반려동물 관련 기사를 스크랩해 링크로 바로 열어볼 수 있게 할 영역.
/// 현재는 미구현이라 제목+날짜 텍스트 리스트의 자리만 잡아두는 플레이스홀더.
class HomeNewsSection extends StatelessWidget {
  const HomeNewsSection({super.key});

  // 자리만 잡기 위한 더미 데이터 — 추후 외부 기사 스크랩 결과로 교체
  static const List<Map<String, String>> _placeholderNews = [
    {'title': '우리집 반려견 시내버스 탈 수 있을까... 탑승 규칙', 'date': '2026.06.04.'},
    {'title': "경기도 첫 공설동물장묘시설 '반려마루 추모관' 1일부터 운영 시작", 'date': '2026.06.04.'},
    {'title': '검역본부, 반려동물 질병 연구 협의체 첫 발족', 'date': '2026.06.04.'},
    {'title': '대구 달서 반려견놀이터, 오후 9시까지 야간 운영', 'date': '2026.06.04.'},
    {'title': "영등포구, '동물등록 자진신고' 기간 운영… 기간 내 신고 시", 'date': '2026.06.04.'},
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '뉴스',
                style: TextStyle(
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.primaryTextColor,
                ),
              ),
              const Spacer(),
              Text(
                '준비 중',
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.secondaryTextColor.withValues(alpha: 0.6),
                ),
              ),
            ],
          ),
          SizedBox(height: 12.h),
          ...List.generate(_placeholderNews.length, (i) {
            final item = _placeholderNews[i];
            return _buildNewsRow(
              title: item['title']!,
              date: item['date']!,
              isLast: i == _placeholderNews.length - 1,
            );
          }),
        ],
      ),
    );
  }

  Widget _buildNewsRow({
    required String title,
    required String date,
    required bool isLast,
  }) {
    // 미구현 상태라 탭 동작 없음 — 추후 외부 기사 URL을 link로 열도록 연결
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 12.sp,
                color: AppTheme.primaryTextColor.withValues(alpha: 0.85),
              ),
            ),
          ),
          SizedBox(width: 12.w),
          Text(
            date,
            style: TextStyle(
              fontSize: 10.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }
}
