import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/realtime_service.dart';
import 'core/utils/back_press_handler.dart';
import 'features/social/presentation/bloc/notification_badge/notification_badge_bloc.dart';
import 'features/my/presentation/pages/my_page.dart';
import 'shared/models/navigation_item.dart';
import 'shared/themes/app_theme.dart';

class MainNavigation extends StatefulWidget {
  final Widget child;

  const MainNavigation({
    super.key,
    required this.child,
  });

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _currentIndex = 0;
  StreamSubscription<Map<String, dynamic>>? _notificationSubscription;
  DateTime? _lastBackPressTime;

  @override
  void initState() {
    super.initState();
    _subscribeToRealtimeNotifications();
  }

  @override
  void dispose() {
    _notificationSubscription?.cancel();
    super.dispose();
  }

  void _subscribeToRealtimeNotifications() {
    _notificationSubscription =
        RealtimeService().notificationStream.listen((_) {
      if (mounted) {
        context
            .read<NotificationBadgeBloc>()
            .add(const NotificationBadgeIncrementRequested());
      }
    });
  }

  final List<NavigationItem> _navigationItems = [
    const NavigationItem(
      icon: Icons.cottage_outlined,
      selectedIcon: Icons.cottage,
      label: '홈',
      route: '/home',
    ),
    const NavigationItem(
      icon: Icons.monitor_heart_outlined,
      selectedIcon: Icons.monitor_heart,
      label: '건강관리',
      route: '/health',
    ),
    const NavigationItem(
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      label: 'AI분석',
      route: '/emotion',
    ),
    const NavigationItem(
      icon: Icons.photo_library_outlined,
      selectedIcon: Icons.photo_library,
      label: '피드',
      route: '/feed',
    ),
    const NavigationItem(
      icon: Icons.pets_outlined,
      selectedIcon: Icons.pets,
      label: 'MY',
      route: '/my',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    _updateCurrentIndex(location);

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        final router = GoRouter.of(context);
        if (router.canPop()) {
          router.pop();
          return;
        }
        await _handleBackPress();
      },
      child: Scaffold(
        body: widget.child,
        bottomNavigationBar: _buildCustomBottomNav(),
      ),
    );
  }

  Future<void> _handleBackPress() async {
    if (!mounted) return;

    // 홈 탭이 아니면 홈으로 이동
    if (_currentIndex != 0) {
      setState(() => _currentIndex = 0);
      context.go('/home');
      return;
    }

    // 홈 탭 2단계 종료
    final now = DateTime.now();
    final last = _lastBackPressTime;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('한 번 더 누르면 앱이 종료됩니다'),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 70.h, left: 16.w, right: 16.w),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.r)),
        ),
      );
      return;
    }

    // 2초 이내 재입력 → 종료 다이얼로그
    _lastBackPressTime = null;
    if (!mounted) return;
    final shouldExit = await BackPressHandler.showExitDialog(context);
    if (shouldExit) BackPressHandler.exitApp();
  }

  // FAB 직경
  static const double _fabSize = 70.0;
  // FAB 중심이 바 상단 기준으로 위로 나오는 양 (양수=위, 음수=바 안으로)
  static const double _fabProtrude = -14.0;
  // 바 자체 높이
  static const double _barHeight = 58.0;

  Widget _buildCustomBottomNav() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    // FAB bottom: 바 하단(bottomPad)에서 바 높이 절반 + 돌출량
    final fabBottom = bottomPad + _barHeight / 2 + _fabProtrude;

    return SizedBox(
      height: _barHeight + bottomPad,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // ── 흰 바 (하단 고정) ──────────────────────────────
          Positioned(
            left: 0, right: 0, bottom: 0,
            child: Container(
              height: _barHeight + bottomPad,
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  top: BorderSide(color: Color(0xFFE8E8E8), width: 1),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Color(0x14000000),
                    blurRadius: 12,
                    offset: Offset(0, -3),
                  ),
                ],
              ),
              child: Padding(
                padding: EdgeInsets.only(bottom: bottomPad),
                child: Row(
                  children: [
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [_buildNavItem(0), _buildNavItem(1)],
                      ),
                    ),
                    const SizedBox(width: _fabSize + 16),
                    Expanded(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [_buildNavItem(3), _buildNavItem(4)],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // ── 중앙 FAB (바 위로 돌출) ─────────────────────────
          Positioned(
            bottom: fabBottom,
            left: 0,
            right: 0,
            child: Center(
              child: Semantics(
                label: 'AI 감정 분석',
                button: true,
                child: GestureDetector(
                  onTap: () => _onTabTapped(2),
                  child: Container(
                    width: _fabSize.w,
                    height: _fabSize.w,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        ClipOval(
                          child: SvgPicture.asset(
                            'assets/svg/icon_fab_bg.svg',
                            width: _fabSize.w,
                            height: _fabSize.w,
                          ),
                        ),
                        SvgPicture.asset(
                          'assets/svg/icon_paw.svg',
                          width: 39.w,
                          height: 39.w,
                          fit: BoxFit.contain,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navigationItems[index];
    final isSelected = _currentIndex == index;

    Widget icon;
    if (index == 0) {
      icon = _buildHomeBadgeIcon(isSelected, item);
    } else if (index == 1) {
      icon = SvgPicture.asset(
        'assets/svg/icon_health.svg',
        width: 24.w,
        height: 24.w,
        colorFilter: ColorFilter.mode(
          isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
          BlendMode.srcIn,
        ),
      );
    } else if (index == 3) {
      icon = SvgPicture.asset(
        'assets/svg/icon_feed.svg',
        width: 24.w,
        height: 24.w,
        colorFilter: ColorFilter.mode(
          isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
          BlendMode.srcIn,
        ),
      );
    } else if (index == 4) {
      icon = _buildMyTabIcon(isSelected, item);
    } else {
      icon = Icon(
        isSelected ? item.selectedIcon : item.icon,
        color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
        size: 24.w,
      );
    }

    return Semantics(
      label: item.label,
      button: true,
      selected: isSelected,
      child: GestureDetector(
        onTap: () => _onTabTapped(index),
        behavior: HitTestBehavior.opaque,
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 12.w),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              icon,
              SizedBox(height: 4.h),
              Text(
                item.label,
                style: TextStyle(
                  fontSize: 11.sp,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMyTabIcon(bool isSelected, NavigationItem item) {
    return BlocBuilder<NotificationBadgeBloc, NotificationBadgeState>(
      builder: (context, badgeState) {
        final color = isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor;
        final icon = SvgPicture.asset(
          'assets/svg/icon_my.svg',
          width: 24.w,
          height: 24.w,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );

        if (badgeState.count <= 0) return icon;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              right: -3.w,
              top: -2.w,
              child: Container(
                width: 8.w,
                height: 8.w,
                decoration: BoxDecoration(
                  color: AppTheme.highlightColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 1.5),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHomeBadgeIcon(bool isSelected, NavigationItem item) {
    return BlocBuilder<NotificationBadgeBloc, NotificationBadgeState>(
      builder: (context, badgeState) {
        final color = isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor;
        final icon = SvgPicture.asset(
          'assets/svg/icon_home.svg',
          width: 24.w,
          height: 24.w,
          colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
        );

        if (badgeState.count <= 0) return icon;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            icon,
            Positioned(
              right: -6.w,
              top: -4.w,
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 4.w, vertical: 1.h),
                decoration: BoxDecoration(
                  // 뱃지 컬러는 highlightColor로 통일 (원빨강 금지)
                  color: AppTheme.highlightColor,
                  borderRadius: BorderRadius.circular(10.r),
                ),
                constraints: BoxConstraints(
                  minWidth: 16.w,
                  minHeight: 16.w,
                ),
                child: Center(
                  child: Text(
                    badgeState.count > 9 ? '9+' : '${badgeState.count}',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 9.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _updateCurrentIndex(String location) {
    int newIndex = _currentIndex;

    if (location.startsWith('/home')) {
      newIndex = 0;
    } else if (location.startsWith('/health')) {
      newIndex = 1;
    } else if (location.startsWith('/emotion')) {
      newIndex = 2;
    } else if (location.startsWith('/feed')) {
      newIndex = 3;
    } else if (location.startsWith('/my')) {
      newIndex = 4;
    }

    if (newIndex != _currentIndex) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          setState(() {
            _currentIndex = newIndex;
          });
        }
      });
    }
  }

  void _onTabTapped(int index) {
    final route = _navigationItems[index].route;
    if (route == null) return;

    final location = GoRouterState.of(context).uri.path;
    if (index == _currentIndex && location.startsWith(route)) return;

    setState(() {
      _currentIndex = index;
    });

    // 홈 탭 이동 시 알림 뱃지 새로고침
    if (index == 0) {
      _refreshNotificationBadge();
    }

    // MY탭 이동 시 stats 갱신
    if (index == 4) {
      MyPageStatsNotifier.instance.refresh();
    }

    context.go(route);
  }

  void _refreshNotificationBadge() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId != null) {
      context.read<NotificationBadgeBloc>().add(
            NotificationBadgeRefreshRequested(userId: userId),
          );
    }
  }
}
