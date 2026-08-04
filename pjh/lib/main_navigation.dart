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

class RootNavigationDestination extends StatelessWidget {
  final NavigationItem item;
  final int index;
  final int itemCount;
  final bool isSelected;
  final Widget icon;
  final Color selectedColor;
  final Color unselectedColor;
  final VoidCallback onTap;

  const RootNavigationDestination({
    super.key,
    required this.item,
    required this.index,
    required this.itemCount,
    required this.isSelected,
    required this.icon,
    required this.selectedColor,
    required this.unselectedColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: item.label,
      hint: '${index + 1}/$itemCount',
      button: true,
      selected: isSelected,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Tooltip(
          message: item.label,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 52),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 2.w, vertical: 6.h),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(width: 24.w, height: 24.w, child: icon),
                    SizedBox(height: 4.h),
                    MediaQuery.withClampedTextScaling(
                      maxScaleFactor: 1.3,
                      child: Text(
                        item.label,
                        maxLines: 1,
                        overflow: TextOverflow.fade,
                        softWrap: false,
                        style: TextStyle(
                          fontSize: 11.sp,
                          fontWeight:
                              isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? selectedColor : unselectedColor,
                        ),
                      ),
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

class MainNavigation extends StatefulWidget {
  final Widget child;

  const MainNavigation({super.key, required this.child});

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
    _notificationSubscription = RealtimeService().notificationStream.listen((
      _,
    ) {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (mounted && userId != null) {
        context.read<NotificationBadgeBloc>().add(
              NotificationBadgeRefreshRequested(userId: userId),
            );
      }
    });
  }

  final List<NavigationItem> _navigationItems = rootNavigationItems;

  @override
  Widget build(BuildContext context) {
    final location = GoRouterState.of(context).uri.path;
    _updateCurrentIndex(location);
    final showRootNavigation = shouldShowRootNavigation(location);

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
        bottomNavigationBar: showRootNavigation ? _buildRootNavigation() : null,
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
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10.r),
          ),
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

  static const double _barHeight = 64;

  Widget _buildRootNavigation() {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
      height: _barHeight + bottomPad,
      decoration: BoxDecoration(
        color: isDark ? theme.colorScheme.surface : AppTheme.surfaceColor,
        border: Border(
          top: BorderSide(
            color: isDark ? theme.colorScheme.outlineVariant : AppTheme.border,
          ),
        ),
      ),
      padding: EdgeInsets.only(bottom: bottomPad),
      child: Row(
        children: List.generate(
          _navigationItems.length,
          (index) => Expanded(child: _buildNavItem(index)),
        ),
      ),
    );
  }

  Widget _buildNavigationIcon(int index, bool isSelected, NavigationItem item) {
    if (index == 0) return _buildHomeBadgeIcon(isSelected, item);
    if (index == 4) return _buildMyTabIcon(isSelected, item);

    final theme = Theme.of(context);
    final color = isSelected
        ? (theme.brightness == Brightness.dark
            ? theme.colorScheme.primary
            : AppTheme.brandDeep)
        : (theme.brightness == Brightness.dark
            ? theme.colorScheme.onSurfaceVariant
            : AppTheme.secondaryTextColor);
    final asset = switch (index) {
      1 => 'assets/svg/icon_health.svg',
      _ => null,
    };

    if (asset != null) {
      return SvgPicture.asset(
        asset,
        width: 23.w,
        height: 23.w,
        colorFilter: ColorFilter.mode(color, BlendMode.srcIn),
      );
    }

    return Icon(
      isSelected ? item.selectedIcon : item.icon,
      color: color,
      size: 23.w,
    );
  }

  Widget _buildNavItem(int index) {
    final item = _navigationItems[index];
    final isSelected = _currentIndex == index;
    final icon = _buildNavigationIcon(index, isSelected, item);
    final theme = Theme.of(context);
    final selectedColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.primary
        : AppTheme.brandDeep;
    final unselectedColor = theme.brightness == Brightness.dark
        ? theme.colorScheme.onSurfaceVariant
        : AppTheme.secondaryTextColor;

    return RootNavigationDestination(
      item: item,
      index: index,
      itemCount: _navigationItems.length,
      isSelected: isSelected,
      icon: icon,
      selectedColor: selectedColor,
      unselectedColor: unselectedColor,
      onTap: () => _onTabTapped(index),
    );
  }

  Widget _buildMyTabIcon(bool isSelected, NavigationItem item) {
    return BlocBuilder<NotificationBadgeBloc, NotificationBadgeState>(
      builder: (context, badgeState) {
        final theme = Theme.of(context);
        final color = isSelected
            ? (theme.brightness == Brightness.dark
                ? theme.colorScheme.primary
                : AppTheme.primaryColor)
            : (theme.brightness == Brightness.dark
                ? theme.colorScheme.onSurfaceVariant
                : AppTheme.secondaryTextColor);
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
                  border: Border.all(
                    color: theme.colorScheme.surface,
                    width: 1.5,
                  ),
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
        final theme = Theme.of(context);
        final color = isSelected
            ? (theme.brightness == Brightness.dark
                ? theme.colorScheme.primary
                : AppTheme.primaryColor)
            : (theme.brightness == Brightness.dark
                ? theme.colorScheme.onSurfaceVariant
                : AppTheme.secondaryTextColor);
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
                constraints: BoxConstraints(minWidth: 16.w, minHeight: 16.w),
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
    final newIndex = navigationIndexForLocation(
      location,
      fallback: _currentIndex,
    );

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
