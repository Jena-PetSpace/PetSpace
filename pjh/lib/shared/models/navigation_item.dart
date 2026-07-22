import 'package:flutter/material.dart';

class NavigationItem {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final String? route;

  const NavigationItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.route,
  });
}

const List<String> rootNavigationPaths = <String>[
  '/home',
  '/health',
  '/emotion',
  '/feed',
  '/my',
];

const List<NavigationItem> rootNavigationItems = <NavigationItem>[
  NavigationItem(
    icon: Icons.cottage_outlined,
    selectedIcon: Icons.cottage,
    label: '홈',
    route: '/home',
  ),
  NavigationItem(
    icon: Icons.monitor_heart_outlined,
    selectedIcon: Icons.monitor_heart,
    label: '건강',
    route: '/health',
  ),
  NavigationItem(
    icon: Icons.auto_awesome_outlined,
    selectedIcon: Icons.auto_awesome,
    label: 'AI 분석',
    route: '/emotion',
  ),
  NavigationItem(
    icon: Icons.photo_library_outlined,
    selectedIcon: Icons.photo_library,
    label: '피드',
    route: '/feed',
  ),
  NavigationItem(
    icon: Icons.pets_outlined,
    selectedIcon: Icons.pets,
    label: 'MY',
    route: '/my',
  ),
];

/// 하단 탭은 다섯 root 화면에서만 보인다.
///
/// ShellRoute 안에 있더라도 작성·편집·상세·설정·채팅 경로에서는 숨긴다.
bool shouldShowRootNavigation(String location) {
  final normalized = location.length > 1 && location.endsWith('/')
      ? location.substring(0, location.length - 1)
      : location;
  return rootNavigationPaths.contains(normalized);
}

int navigationIndexForLocation(String location, {int fallback = 0}) {
  for (var index = 0; index < rootNavigationPaths.length; index++) {
    final root = rootNavigationPaths[index];
    if (location == root || location.startsWith('$root/')) return index;
  }
  return fallback;
}
