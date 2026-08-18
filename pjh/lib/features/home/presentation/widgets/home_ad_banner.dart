import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

/// 홈의 광고·프로모션 공용 슬롯.
///
/// 외부 광고 SDK가 아직 연결되지 않은 상태에서 빈 광고나 가짜 광고를
/// 노출하지 않는다. 현재는 실제 동작하는 펫페이스 내부 추천을 보여주고,
/// 광고 공급자가 확정되면 이 위치를 SDK 광고 위젯으로 교체한다.
class HomeAdBanner extends StatelessWidget {
  const HomeAdBanner({
    super.key,
    required this.onTap,
  });

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Semantics(
        button: true,
        label: '펫페이스 추천, 플레이스에서 주변 반려동물 장소 찾아보기',
        child: ExcludeSemantics(
          child: Material(
            key: const ValueKey<String>('home-promo-banner'),
            color: AppTheme.actionContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16.r),
              side: const BorderSide(color: AppTheme.border),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: EdgeInsets.fromLTRB(16.w, 14.h, 12.w, 14.h),
                child: Row(
                  children: [
                    Container(
                      width: 48.w,
                      height: 48.w,
                      decoration: const BoxDecoration(
                        color: AppTheme.surfaceColor,
                        shape: BoxShape.circle,
                      ),
                      alignment: Alignment.center,
                      child: Icon(
                        Icons.place_outlined,
                        size: 25.w,
                        color: AppTheme.actionBase,
                      ),
                    ),
                    SizedBox(width: 13.w),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '펫페이스 추천',
                            style: TextStyle(
                              fontSize: 11.sp,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.actionBase,
                            ),
                          ),
                          SizedBox(height: 3.h),
                          Text(
                            '가까운 반려동물 장소를 찾아보세요',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 14.sp,
                              height: 1.25,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primaryTextColor,
                            ),
                          ),
                          SizedBox(height: 2.h),
                          Text(
                            '동물병원부터 함께 가기 좋은 장소까지',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.sp,
                              height: 1.3,
                              color: AppTheme.secondaryTextColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(width: 8.w),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 15.w,
                      color: AppTheme.actionBase,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
