import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../features/social/presentation/pages/home_page.dart';
import '../../features/social/presentation/pages/explore_page.dart';
import '../../features/social/presentation/pages/create_post_page.dart';
import '../../features/profile/presentation/pages/profile_page.dart';
import '../../features/emotion/presentation/pages/emotion_analysis_page.dart';
import '../../features/auth/presentation/bloc/auth_bloc.dart';
import '../themes/app_theme.dart';
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
      icon: Icons.explore_outlined,
      selectedIcon: Icons.explore,
      label: '탐색',
    ),
    const NavigationItem(
      icon: Icons.add_circle_outline,
      selectedIcon: Icons.add_circle,
      label: '게시',
    ),
    const NavigationItem(
      icon: Icons.psychology_outlined,
      selectedIcon: Icons.psychology,
      label: '감정분석',
    ),
    const NavigationItem(
      icon: Icons.person_outline,
      selectedIcon: Icons.person,
      label: '프로필',
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
      floatingActionButton: _buildFloatingActionButton(),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
    );
  }

  Widget _getCurrentPage() {
    switch (_currentIndex) {
      case 0:
        return const HomePage();
      case 1:
        return const ExplorePage();
      case 2:
        return const CreatePostPage();
      case 3:
        return const EmotionAnalysisPage();
      case 4:
        return const ProfilePage();
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

  Widget? _buildFloatingActionButton() {
    // Show FAB only on home and explore pages for quick post creation
    if (_currentIndex == 0 || _currentIndex == 1) {
      return FloatingActionButton(
        onPressed: () {
          setState(() {
            _currentIndex = 2;
          });
        },
        backgroundColor: AppTheme.primaryColor,
        child: const Icon(
          Icons.add,
          color: Colors.white,
        ),
      );
    }
    return null;
  }
}

