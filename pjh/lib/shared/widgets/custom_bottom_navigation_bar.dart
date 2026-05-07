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

  // AI 버튼이 바 위로 돌출되는 높이
  static const double _fabOverflow = 20.0;
  // 바 자체 높이 (SafeArea 제외)
  static const double _barHeight = 56.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // 돌출분 + 바 높이 + SafeArea 하단
      height: _fabOverflow + _barHeight + MediaQuery.of(context).padding.bottom,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // 바 본체 (하단 정렬)
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: Container(
              height: _barHeight + MediaQuery.of(context).padding.bottom,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE0E0E0), width: 0.5),
                ),
              ),
              child: Padding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.of(context).padding.bottom,
                ),
                child: Row(
                  children: [
                    // 왼쪽 2개 탭 (홈, 건강관리)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTabItem(0),
                          _buildTabItem(1),
                        ],
                      ),
                    ),
                    // 중앙 FAB 자리 확보 (버튼 너비만큼)
                    SizedBox(width: 72.w),
                    // 오른쪽 2개 탭 (피드, MY)
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildTabItem(3),
                          _buildTabItem(4),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // 중앙 AI 분석 FAB — 정확히 수평 중앙, 바 위로 돌출
          Positioned(
            bottom: MediaQuery.of(context).padding.bottom + (_barHeight - 64.w) / 2,
            left: 0,
            right: 0,
            child: Center(
              child: _buildFabButton(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabItem(int index) {
    final item = items[index];
    final isSelected = currentIndex == index;

    return Semantics(
      label: item.label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => onTap(index),
        behavior: HitTestBehavior.opaque,
        child: SizedBox(
          height: _barHeight,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? item.selectedIcon : item.icon,
                color: isSelected
                    ? AppTheme.primaryColor
                    : const Color(0xFFBDBDBD),
                size: 24.w,
              ),
              SizedBox(height: 4.h),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 10.sp,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected
                      ? AppTheme.primaryColor
                      : const Color(0xFFBDBDBD),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFabButton() {
    final isSelected = currentIndex == 2;

    return Semantics(
      label: 'AI 분석',
      button: true,
      child: GestureDetector(
        onTap: () => onTap(2),
        child: Container(
          width: 64.w,
          height: 64.w,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.35),
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
            border: Border.all(
              color: Colors.white,
              width: 3,
            ),
          ),
          child: Icon(
            Icons.pets,
            size: 28.w,
            color: isSelected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.9),
          ),
        ),
      ),
    );
  }
}
