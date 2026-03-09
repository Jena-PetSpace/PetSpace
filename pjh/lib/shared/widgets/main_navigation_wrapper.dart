import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/social/presentation/pages/home_page.dart';
import '../../features/health/presentation/pages/health_main_page.dart';
import '../../features/emotion/presentation/pages/emotion_analysis_page.dart';
import '../../features/feed_hub/presentation/pages/feed_hub_page.dart';
import '../../features/my/presentation/pages/my_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../models/navigation_item.dart';
import 'custom_bottom_navigation_bar.dart';

class MainNavigationWrapper extends StatefulWidget {
  const MainNavigationWrapper({super.key});

  @override
  State<MainNavigationWrapper> createState() => _MainNavigationWrapperState();
}

class _MainNavigationWrapperState extends State<MainNavigationWrapper> {
  int _currentIndex = 0;

  final List<NavigationItem> _navigationItems = [
    const NavigationItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home,
      label: '홈',
    ),
    const NavigationItem(
      icon: Icons.medical_services_outlined,
      selectedIcon: Icons.medical_services,
      label: '건강관리',
    ),
    const NavigationItem(
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      label: 'AI분석',
    ),
    const NavigationItem(
      icon: Icons.dynamic_feed_outlined,
      selectedIcon: Icons.dynamic_feed,
      label: '피드',
    ),
    const NavigationItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: 'MY',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _getCurrentUserId();
  }

  void _getCurrentUserId() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      // User ID retrieval logic - placeholder
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _getCurrentPage(),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        items: _navigationItems,
        onTap: _onTabTapped,
      ),
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const HomePage();
      case 1:
        return const HealthMainPage();
      case 2:
        return const EmotionAnalysisPage();
      case 3:
        return const FeedHubPage();
      case 4:
        return const MyPage();
      default:
        return const HomePage();
    }
  }

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;

    setState(() {
      _currentIndex = index;
    });
  }
}
