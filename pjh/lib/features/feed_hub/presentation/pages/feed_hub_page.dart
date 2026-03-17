import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../social/presentation/pages/feed_page.dart';
import '../widgets/community_post_card.dart';

class FeedHubPage extends StatefulWidget {
  final int initialTab;

  const FeedHubPage({super.key, this.initialTab = 0});

  @override
  State<FeedHubPage> createState() => _FeedHubPageState();
}

class _FeedHubPageState extends State<FeedHubPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTab,
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          '피드',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 2,
          labelColor: AppTheme.primaryColor,
          labelStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w700,
          ),
          unselectedLabelColor: AppTheme.lightTextColor,
          unselectedLabelStyle: TextStyle(
            fontSize: 14.sp,
            fontWeight: FontWeight.w400,
          ),
          tabs: const [
            Tab(text: '추천'),
            Tab(text: '팔로잉'),
            Tab(text: '커뮤니티'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const FeedPage(),
          _buildFollowingTab(),
          _buildCommunityTab(),
        ],
      ),
    );
  }

  Widget _buildFollowingTab() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64.w, color: Colors.grey[400]),
          SizedBox(height: 16.h),
          Text(
            '팔로잉한 사용자의 게시물이\n여기에 표시됩니다',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14.sp,
              color: AppTheme.secondaryTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCommunityTab() {
    final categories = ['전체', '건강Q&A', '사료추천', '자유Q&A', '정보공유'];
    return Column(
      children: [
        // 카테고리 칩
        Container(
          height: 48.h,
          padding: EdgeInsets.symmetric(vertical: 8.h),
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: EdgeInsets.symmetric(horizontal: 16.w),
            itemCount: categories.length,
            separatorBuilder: (_, __) => SizedBox(width: 8.w),
            itemBuilder: (context, index) {
              final isSelected = index == 0;
              return FilterChip(
                label: Text(
                  categories[index],
                  style: TextStyle(
                    fontSize: 12.sp,
                    color: isSelected ? Colors.white : AppTheme.secondaryTextColor,
                  ),
                ),
                selected: isSelected,
                selectedColor: AppTheme.primaryColor,
                backgroundColor: Colors.white,
                side: BorderSide(color: isSelected ? AppTheme.primaryColor : AppTheme.dividerColor),
                onSelected: (_) {},
              );
            },
          ),
        ),
        // 게시글 리스트 (샘플)
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(16.w),
            children: const [
              CommunityPostCard(
                authorName: '몽이맘',
                category: '건강Q&A',
                title: '강아지 눈물자국 관리법 알려주세요',
                content: '말티즈 3살인데 눈물자국이 심해져서 고민이에요. 좋은 방법 있으면 공유해주세요!',
                likes: 12,
                comments: 5,
                timeAgo: '2시간 전',
              ),
              CommunityPostCard(
                authorName: '냥순이아빠',
                category: '사료추천',
                title: '고양이 사료 추천 부탁드려요',
                content: '5살 페르시안 고양이인데 요즘 사료를 안먹으려고 해요. 추천해주실 사료 있으신가요?',
                likes: 8,
                comments: 14,
                timeAgo: '5시간 전',
              ),
              CommunityPostCard(
                authorName: '댕댕이사랑',
                category: '자유Q&A',
                title: '산책할 때 다른 강아지 만나면 흥분해요',
                content: '산책 중에 다른 강아지를 보면 너무 흥분하는데 교정 방법이 있을까요?',
                likes: 23,
                comments: 9,
                timeAgo: '어제',
              ),
            ],
          ),
        ),
      ],
    );
  }
}
