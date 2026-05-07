import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../features/social/presentation/pages/home_page.dart';
import '../../features/health/presentation/pages/health_main_page.dart';
import '../../features/emotion/presentation/pages/emotion_analysis_page.dart';
import '../../features/feed_hub/presentation/pages/feed_hub_page.dart';
import '../../features/my/presentation/pages/my_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../models/navigation_item.dart';
import '../themes/app_theme.dart';
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
      icon: Icons.pets,
      selectedIcon: Icons.pets,
      label: 'AI분석',
    ),
    const NavigationItem(
      icon: Icons.bookmark_border_outlined,
      selectedIcon: Icons.bookmark,
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

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    HapticFeedback.lightImpact();
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: _getCurrentPage(),
      bottomNavigationBar: CustomBottomNavigationBar(
        currentIndex: _currentIndex,
        items: _navigationItems,
        onTap: _onTabTapped,
      ),
      floatingActionButton: _buildCenterFab(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _buildCenterFab() {
    final isSelected = _currentIndex == 2;
    return Semantics(
      label: 'AI 분석',
      button: true,
      child: GestureDetector(
        onTap: () => _onTabTapped(2),
        child: Container(
          width: 62.w,
          height: 62.w,
          decoration: BoxDecoration(
            color: AppTheme.primaryColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 3),
            boxShadow: [
              BoxShadow(
                color: AppTheme.primaryColor.withValues(alpha: 0.4),
                blurRadius: 14,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Icon(
            Icons.pets,
            size: 28.w,
            color: isSelected ? Colors.white : Colors.white.withValues(alpha: 0.92),
          ),
        ),
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
}
