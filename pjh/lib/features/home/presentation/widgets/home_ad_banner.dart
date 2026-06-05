import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';

/// 퀵 액션 아래 배너 캐러셀 — 추후 배너형 광고 또는 공지사항이 들어갈 자리.
/// 현재는 미구현이라 자리만 잡아두는 플레이스홀더(좌우 페이지 인디케이터·AD 뱃지 포함).
class HomeAdBanner extends StatefulWidget {
  /// 슬롯(페이지) 개수 — 추후 실제 광고/공지 개수로 교체.
  final int slotCount;

  const HomeAdBanner({super.key, this.slotCount = 5});

  @override
  State<HomeAdBanner> createState() => _HomeAdBannerState();
}

class _HomeAdBannerState extends State<HomeAdBanner> {
  late final PageController _controller;
  int _current = 0;

  @override
  void initState() {
    super.initState();
    _controller = PageController();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16.r),
        child: SizedBox(
          height: 96.h,
          child: Stack(
            children: [
              // 배너 페이지들 (현재는 빈 슬롯)
              PageView.builder(
                controller: _controller,
                itemCount: widget.slotCount,
                onPageChanged: (i) => setState(() => _current = i),
                itemBuilder: (_, __) => _buildSlot(),
              ),

              // 페이지 인디케이터 (예: 2/5)
              Positioned(
                top: 8.h,
                right: 12.w,
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: 8.w, vertical: 3.h),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.45),
                    borderRadius: BorderRadius.circular(10.r),
                  ),
                  child: Text(
                    '${_current + 1}/${widget.slotCount}',
                    style: TextStyle(
                      fontSize: 10.sp,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

              // AD 뱃지
              Positioned(
                bottom: 8.h,
                right: 12.w,
                child: Text(
                  'AD',
                  style: TextStyle(
                    fontSize: 10.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.secondaryTextColor.withValues(alpha: 0.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSlot() {
    return Container(
      color: AppTheme.primaryColor.withValues(alpha: 0.05),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.campaign_outlined,
            size: 22.w,
            color: AppTheme.secondaryTextColor.withValues(alpha: 0.4),
          ),
          SizedBox(height: 4.h),
          Text(
            '광고 · 공지 배너 영역',
            style: TextStyle(
              fontSize: 11.sp,
              fontWeight: FontWeight.w500,
              color: AppTheme.secondaryTextColor.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}
