import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'shared/models/navigation_item.dart';

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

  final List<NavigationItem> _navigationItems = [
    const NavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '홈',
      route: '/home',
    ),
    const NavigationItem(
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: '탐색',
      route: '/explore',
    ),
    const NavigationItem(
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      label: '게시',
      route: '/create-post',
    ),
    const NavigationItem(
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      label: '감정분석',
      route: '/emotion',
    ),
    const NavigationItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: '프로필',
      route: '/profile',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    // GoRouter의 현재 경로를 기반으로 탭 인덱스 설정
    final location = GoRouterState.of(context).uri.path;
    _updateCurrentIndex(location);

    return Scaffold(
      body: widget.child,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: _navigationItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item.icon),
          label: item.label,
        )).toList(),
      ),
    );
  }

  void _updateCurrentIndex(String location) {
    int newIndex = _currentIndex;

    if (location.startsWith('/home')) {
      newIndex = 0;
    } else if (location.startsWith('/explore')) {
      newIndex = 1;
    } else if (location.startsWith('/create-post')) {
      newIndex = 2;
    } else if (location.startsWith('/emotion')) {
      newIndex = 3;
    } else if (location.startsWith('/profile')) {
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
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
    });

    final route = _navigationItems[index].route;
    if (route != null) {
      context.go(route);
    }
  }
}

