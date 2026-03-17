import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../chat/presentation/bloc/chat_badge/chat_badge_bloc.dart';
import '../../../pets/presentation/bloc/pet_bloc.dart';
import '../../../pets/presentation/bloc/pet_event.dart';
import '../../../home/presentation/widgets/pet_profile_card.dart';
import '../../../home/presentation/widgets/category_filter_chips.dart';
import '../../../home/presentation/widgets/hot_topic_banner.dart';
import '../../../home/presentation/widgets/magazine_grid.dart';
import '../../../home/presentation/widgets/community_preview.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  Timer? _badgeTimer;
  int _selectedCategory = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        _loadChatBadge();
        _badgeTimer = Timer.periodic(const Duration(seconds: 30), (_) {
          if (mounted) _loadChatBadge();
        });
      }
    });
  }

  void _loadChatBadge() {
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) {
      context.read<ChatBadgeBloc>().add(
        ChatBadgeLoadRequested(userId: authState.user.id),
      );
    }
  }

  @override
  void dispose() {
    _badgeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Image.asset(
          'assets/images/logo.png',
          height: 63.h,
          fit: BoxFit.contain,
        ),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => context.push('/explore'),
          ),
          IconButton(
            icon: const Icon(Icons.notifications_outlined),
            onPressed: () => context.push('/notifications'),
          ),
          BlocBuilder<ChatBadgeBloc, ChatBadgeState>(
            builder: (context, badgeState) {
              final iconColor = IconTheme.of(context).color ?? Colors.black87;
              final chatIcon = SizedBox(
                width: 24.w,
                height: 24.w,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: Size(24.w, 24.w),
                      painter: _ChatBubblePainter(color: iconColor),
                    ),
                    Padding(
                      padding: EdgeInsets.only(bottom: 3.h),
                      child: Icon(Icons.pets, size: 11.w, color: iconColor),
                    ),
                  ],
                ),
              );
              return IconButton(
                icon: badgeState.count > 0
                    ? Badge(
                        label: Text(
                          badgeState.count > 99 ? '99+' : '${badgeState.count}',
                          style: TextStyle(fontSize: 10.sp),
                        ),
                        backgroundColor: AppTheme.highlightColor,
                        child: chatIcon,
                      )
                    : chatIcon,
                onPressed: () => context.push('/chat'),
              );
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          _loadChatBadge();
          context.read<PetBloc>().add(LoadUserPets());
          await Future.delayed(const Duration(milliseconds: 500));
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 8.h),

              // 1. 반려동물 프로필 카드
              const PetProfileCard(),
              SizedBox(height: 20.h),

              // 2. 카테고리 필터 칩
              CategoryFilterChips(
                onSelected: (index) {
                  setState(() => _selectedCategory = index);
                },
              ),
              SizedBox(height: 20.h),

              // 카테고리별 콘텐츠
              _buildCategoryContent(),

              SizedBox(height: 32.h),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCategoryContent() {
    // 0: 인기(전체), 1: 매거진, 2: 커뮤니티, 3: 건강, 4: 훈련
    switch (_selectedCategory) {
      case 1: // 매거진
        return const MagazineGrid();
      case 2: // 커뮤니티
        return const CommunityPreview();
      case 3: // 건강
        return _buildHealthContent();
      case 4: // 훈련
        return _buildTrainingContent();
      default: // 인기 (전체 보기)
        return Column(
          children: [
            const HotTopicBanner(),
            SizedBox(height: 24.h),
            const MagazineGrid(),
            SizedBox(height: 24.h),
            const CommunityPreview(),
          ],
        );
    }
  }

  Widget _buildHealthContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '건강 관련 콘텐츠',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 12.h),
          _buildContentItem(
            icon: Icons.medical_services_outlined,
            iconColor: AppTheme.successColor,
            title: '반려동물 치아 관리 필수 가이드',
            subtitle: '건강 · 2시간 전',
          ),
          SizedBox(height: 10.h),
          _buildContentItem(
            icon: Icons.medical_services_outlined,
            iconColor: AppTheme.successColor,
            title: '겨울철 반려동물 건강 체크리스트',
            subtitle: '건강 · 5시간 전',
          ),
          SizedBox(height: 10.h),
          _buildContentItem(
            icon: Icons.medical_services_outlined,
            iconColor: AppTheme.successColor,
            title: '예방접종 가이드: 시기와 종류',
            subtitle: '건강 · 어제',
          ),
        ],
      ),
    );
  }

  Widget _buildTrainingContent() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16.w),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '훈련 관련 콘텐츠',
            style: TextStyle(
              fontSize: 15.sp,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryTextColor,
            ),
          ),
          SizedBox(height: 12.h),
          _buildContentItem(
            icon: Icons.school_outlined,
            iconColor: AppTheme.accentColor,
            title: '기본 복종 훈련 시작하기',
            subtitle: '훈련 · 3시간 전',
          ),
          SizedBox(height: 10.h),
          _buildContentItem(
            icon: Icons.school_outlined,
            iconColor: AppTheme.accentColor,
            title: '산책 매너 교육 방법',
            subtitle: '훈련 · 어제',
          ),
          SizedBox(height: 10.h),
          _buildContentItem(
            icon: Icons.school_outlined,
            iconColor: AppTheme.accentColor,
            title: '분리불안 극복 훈련 팁',
            subtitle: '훈련 · 2일 전',
          ),
        ],
      ),
    );
  }

  Widget _buildContentItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
  }) {
    return Container(
      decoration: AppTheme.cardDecoration,
      padding: EdgeInsets.all(14.w),
      child: Row(
        children: [
          Container(
            width: 40.w,
            height: 40.w,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10.r),
            ),
            child: Icon(icon, size: 20.w, color: iconColor),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.primaryTextColor,
                  ),
                ),
                SizedBox(height: 2.h),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 10.sp,
                    color: AppTheme.secondaryTextColor,
                  ),
                ),
              ],
            ),
          ),
          Icon(Icons.arrow_forward_ios, size: 14.w, color: AppTheme.secondaryTextColor),
        ],
      ),
    );
  }
}

class _ChatBubblePainter extends CustomPainter {
  final Color color;

  _ChatBubblePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;

    final w = size.width;
    final h = size.height;

    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.05, 0, w * 0.9, h * 0.78),
      Radius.circular(w * 0.35),
    );
    canvas.drawRRect(bubbleRect, paint);

    final tailPath = Path()
      ..moveTo(w * 0.22, h * 0.72)
      ..quadraticBezierTo(w * 0.15, h * 0.95, w * 0.08, h * 0.98)
      ..quadraticBezierTo(w * 0.25, h * 0.88, w * 0.35, h * 0.78);

    canvas.drawPath(tailPath, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
