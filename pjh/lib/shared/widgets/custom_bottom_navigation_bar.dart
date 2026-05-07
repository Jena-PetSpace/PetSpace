import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../models/navigation_item.dart';
import '../themes/app_theme.dart';

class CustomBottomNavigationBar extends StatelessWidget {
  final int currentIndex;
  final List<NavigationItem> items;
  final ValueChanged<int> onTap;

  const CustomBottomNavigationBar({
    super.key,
    required this.currentIndex,
    required this.items,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return BottomAppBar(
      color: Colors.white,
      elevation: 8,
      notchMargin: 6,
      shape: const CircularNotchAndBar(),
      padding: EdgeInsets.zero,
      child: SizedBox(
        height: 60.h,
        child: Row(
          children: [
            // 왼쪽 2탭 (홈, 건강관리)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabItem(context, 0),
                  _buildTabItem(context, 1),
                ],
              ),
            ),
            // 중앙 notch 공간
            SizedBox(width: 72.w),
            // 오른쪽 2탭 (피드, MY)
            Expanded(
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildTabItem(context, 3),
                  _buildTabItem(context, 4),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabItem(BuildContext context, int index) {
    final item = items[index];
    final isSelected = currentIndex == index;

    return Semantics(
      label: item.label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected ? AppTheme.primaryColor : const Color(0xFFBDBDBD),
                size: 24.w,
              ),
              SizedBox(height: 3.h),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.primaryColor : const Color(0xFFBDBDBD),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// centerDocked notch 형태
class CircularNotchAndBar extends NotchedShape {
  const CircularNotchAndBar();

  @override
  Path getOuterPath(Rect host, Rect? guest) {
    if (guest == null || !host.overlaps(guest)) {
      return Path()..addRect(host);
    }

    final notchRadius = guest.width / 2.0 + 6.0;
    const s1 = 15.0;
    const s2 = 1.0;

    final cx = guest.center.dx;
    final cy = host.top;

    return Path()
      ..moveTo(host.left, host.top)
      ..lineTo(cx - notchRadius - s1, host.top)
      ..arcToPoint(
        Offset(cx - notchRadius, cy + s2),
        radius: const Radius.circular(s1),
        clockwise: false,
      )
      ..arcToPoint(
        Offset(cx + notchRadius, cy + s2),
        radius: Radius.circular(notchRadius),
        clockwise: true,
      )
      ..arcToPoint(
        Offset(cx + notchRadius + s1, host.top),
        radius: const Radius.circular(s1),
        clockwise: false,
      )
      ..lineTo(host.right, host.top)
      ..lineTo(host.right, host.bottom)
      ..lineTo(host.left, host.bottom)
      ..close();
  }
}
