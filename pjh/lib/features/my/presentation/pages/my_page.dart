import 'dart:developer' as dev;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;

import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../widgets/my_profile_header.dart';
import '../widgets/user_badges_section.dart';

/// MY탭 stats 갱신 신호를 보내는 싱글톤 notifier
class MyPageStatsNotifier extends ChangeNotifier {
  static final MyPageStatsNotifier instance = MyPageStatsNotifier._();
  MyPageStatsNotifier._();

  void refresh() => notifyListeners();
}

class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<Map<String, dynamic>> _myPosts = [];
  List<Map<String, dynamic>> _savedPosts = [];
  bool _postsLoading = true;
  int _statsRefreshKey = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _loadPosts();
    MyPageStatsNotifier.instance.addListener(_onStatsRefresh);
  }

  @override
  void dispose() {
    MyPageStatsNotifier.instance.removeListener(_onStatsRefresh);
    _tabController.dispose();
    super.dispose();
  }

  void _onStatsRefresh() {
    if (mounted) {
      setState(() => _statsRefreshKey++);
    }
  }

  Future<void> _loadPosts() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;
    try {
      final results = await Future.wait([
        Supabase.instance.client
            .from('posts')
            .select('id, image_url, caption, author_id')
            .eq('author_id', userId)
            .order('created_at', ascending: false),
        Supabase.instance.client
            .from('saved_posts')
            .select('post_id, posts(id, image_url, caption, author_id)')
            .eq('user_id', userId)
            .order('created_at', ascending: false),
      ]);
      if (mounted) {
        setState(() {
          _myPosts = List<Map<String, dynamic>>.from(results[0] as List);
          _savedPosts = (results[1] as List)
              .map((e) => e['posts'] as Map<String, dynamic>?)
              .whereType<Map<String, dynamic>>()
              .toList();
          _postsLoading = false;
        });
      }
    } catch (e) {
      dev.log('게시글 로드 실패: $e', name: 'MyPage');
      if (mounted) setState(() => _postsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        if (state is! AuthAuthenticated) {
          return const Scaffold(
              body: Center(child: CircularProgressIndicator()));
        }
        final user = state.user;
        return Scaffold(
          backgroundColor: AppTheme.backgroundColor,
          body: SafeArea(
            bottom: false,
            child: Column(
            children: [
              // 헤더 + 뱃지 (스크롤 안 됨 - 고정)
              MyProfileHeader(
                user: user,
                onPostsTapped: () => _tabController.animateTo(0),
                statsRefreshKey: _statsRefreshKey,
              ),
              UserBadgesSection(userId: user.uid),
              // 탭 바 (고정)
              Container(
                color: Colors.white,
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(icon: Icon(Icons.grid_on_rounded)),
                    Tab(icon: Icon(Icons.bookmark_outline_rounded)),
                  ],
                  indicatorColor: AppTheme.primaryColor,
                  indicatorWeight: 2,
                  labelColor: AppTheme.primaryColor,
                  unselectedLabelColor: const Color(0xFFBDBDBD),
                  dividerColor: const Color(0xFFEEEEEE),
                ),
              ),
              // 그리드 (스크롤 영역)
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildGrid(_myPosts, _postsLoading, isMyPosts: true),
                    _buildGrid(_savedPosts, false, isMyPosts: false),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      },
    );
  }

  Widget _buildGrid(List<Map<String, dynamic>> posts, bool loading,
      {required bool isMyPosts}) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (posts.isEmpty) {
      return _buildEmptyState(isMyPosts);
    }
    return GridView.builder(
      padding: EdgeInsets.zero,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 1.5.h,
        crossAxisSpacing: 1.5.w,
        childAspectRatio: 1.0,
      ),
      itemCount: posts.length,
      itemBuilder: (context, i) {
        final post = posts[i];
        final postId = post['id'] as String;
        final imageUrl = post['image_url'] as String?;
        final caption = post['caption'] as String? ?? '';
        return GestureDetector(
          onTap: () => context.push('/feed/post/$postId'),
          child: Stack(
            fit: StackFit.expand,
            children: [
              imageUrl != null && imageUrl.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: imageUrl,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) =>
                          _buildColorBlock(postId, caption),
                    )
                  : _buildColorBlock(postId, caption),
            ],
          ),
        );
      },
    );
  }

  Widget _buildColorBlock(String postId, String caption) {
    final colors = [
      AppTheme.primaryColor,
      AppTheme.accentColor,
      AppTheme.highlightColor,
      AppTheme.secondaryColor,
      AppTheme.successColor,
    ];
    final color = colors[postId.hashCode.abs() % colors.length];
    return Container(
      color: color.withValues(alpha: 0.15),
      child: Center(
        child: Text(
          caption.isNotEmpty ? caption[0] : '✍',
          style: TextStyle(fontSize: 24.sp, color: color),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isMyPosts) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(32.w),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isMyPosts
                  ? Icons.grid_on_outlined
                  : Icons.bookmark_outline_rounded,
              size: 48.w,
              color: AppTheme.lightTextColor,
            ),
            SizedBox(height: 16.h),
            Text(
              isMyPosts
                  ? '아직 게시글이 없어요\n첫 이야기를 공유해보세요 📸'
                  : '저장한 게시글이 없어요\n마음에 드는 게시글을 저장해보세요 🔖',
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 13.sp,
                  color: AppTheme.secondaryTextColor,
                  height: 1.6),
            ),
            if (isMyPosts) ...[
              SizedBox(height: 20.h),
              ElevatedButton(
                onPressed: () => context.push('/create-post'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primaryColor,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.r)),
                  padding:
                      EdgeInsets.symmetric(horizontal: 24.w, vertical: 10.h),
                ),
                child: Text('게시글 작성하기',
                    style: TextStyle(fontSize: 13.sp)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

