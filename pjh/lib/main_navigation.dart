import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/realtime_service.dart';
import 'features/social/presentation/bloc/notification_badge/notification_badge_bloc.dart';
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

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: _buildCustomBottomNav(),
    );
  }

  Widget _buildCustomBottomNav() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).bottomNavigationBarTheme.backgroundColor ??
            Theme.of(context).colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            height: 60.h,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.w),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: _navigationItems.asMap().entries.map((entry) {
                  final index = entry.key;
                  final item = entry.value;
                  final isSelected = _currentIndex == index;

                  // 중앙 AI분석 FAB 버튼
                  if (index == 2) {
                    return Semantics(
                      label: 'AI 감정 분석',
                      button: true,
                      selected: _currentIndex == 2,
                      child: GestureDetector(
                        onTap: () => _onTabTapped(index),
                        child: Container(
                          width: 56.w,
                          height: 56.w,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(18.r),
                            gradient: const LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [AppTheme.primaryColor, AppTheme.accentColor],
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppTheme.primaryColor.withValues(alpha: 0.3),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(Icons.psychology, color: Colors.white, size: 28.w),
                        ),
                      ),
                    );
                  }

                  return Semantics(
                    label: item.label,
                    button: true,
                    selected: isSelected,
                    child: GestureDetector(
                      onTap: () => _onTabTapped(index),
                      behavior: HitTestBehavior.opaque,
                      child: Container(
                        padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 8.h),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (index == 0)
                              _buildHomeBadgeIcon(isSelected, item)
                            else if (index == 4)
                              _buildMyTabIcon(isSelected, item)
                            else
                              Icon(
                                isSelected ? item.selectedIcon : item.icon,
                                color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
                                size: 24.w,
                              ),
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
                }).toList(),
              ),
            ),
          ),
          SizedBox(height: MediaQuery.of(context).viewPadding.bottom),
        ],
      ),
    );
  }

  Widget _buildMyTabIcon(bool isSelected, NavigationItem item) {
    return BlocBuilder<NotificationBadgeBloc, NotificationBadgeState>(
      builder: (context, badgeState) {
        final icon = Icon(
          isSelected ? item.selectedIcon : item.icon,
          color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
          size: 24.w,
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
        final icon = Icon(
          isSelected ? item.selectedIcon : item.icon,
          color:
              isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextColor,
          size: 24.w,
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
                  color: Colors.red,
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
