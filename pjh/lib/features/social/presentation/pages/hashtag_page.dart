import 'dart:developer' as dev;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../domain/entities/post.dart';
import '../../data/models/post_model.dart';
import '../bloc/feed_bloc.dart';
import '../widgets/post_card.dart';
import '../widgets/edit_post_bottom_sheet.dart';

class HashtagPage extends StatefulWidget {
  final String hashtag;

  const HashtagPage({super.key, required this.hashtag});

  @override
  State<HashtagPage> createState() => _HashtagPageState();
}

class _HashtagPageState extends State<HashtagPage> {
  final ScrollController _scrollController = ScrollController();
  final _supabase = Supabase.instance.client;

  List<Post> _posts = [];
  bool _loading = true;
  bool _hasMore = true;
  bool _loadingMore = false;
  String? _error;

  String get _currentUserId => _supabase.auth.currentUser?.id ?? '';

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    _load(reset: true);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      _load();
    }
  }

  Future<void> _load({bool reset = false}) async {
    if (!reset && (_loadingMore || !_hasMore)) return;

    if (reset) {
      setState(() {
        _loading = true;
        _error = null;
        _posts = [];
        _hasMore = true;
      });
    } else {
      setState(() => _loadingMore = true);
    }

    try {
      final response = await _supabase.rpc('get_posts_by_hashtag', params: {
        'p_hashtag': widget.hashtag,
        'p_user_id': _currentUserId.isEmpty ? null : _currentUserId,
        'p_sort': 'recent',
        'p_limit': 20,
        'p_offset': reset ? 0 : _posts.length,
      });

      final List<Post> fetched = (response as List)
          .map((e) => PostModel.fromJson(e as Map<String, dynamic>).toEntity())
          .toList();

      setState(() {
        _loading = false;
        _loadingMore = false;
        _hasMore = fetched.length == 20;
        if (reset) {
          _posts = fetched;
        } else {
          _posts = [..._posts, ...fetched];
        }
      });
    } catch (e) {
      dev.log('HashtagPage load error: $e', name: 'HashtagPage');
      setState(() {
        _loading = false;
        _loadingMore = false;
        _error = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.subtleBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '#${widget.hashtag}',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) return const FeedShimmerLoading();

    if (_error != null && _posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 48.w, color: Colors.red),
            SizedBox(height: 12.h),
            Text('불러오기 실패', style: TextStyle(fontSize: 15.sp)),
            SizedBox(height: 8.h),
            ElevatedButton(
              onPressed: () => _load(reset: true),
              child: const Text('다시 시도'),
            ),
          ],
        ),
      );
    }

    if (_posts.isEmpty) {
      return EmptyStateWidget(
        icon: Icons.tag,
        emoji: '🏷️',
        title: '#${widget.hashtag} 게시물이 없어요',
        subtitle: '이 해시태그로 첫 게시물을 작성해보세요!',
      );
    }

    return RefreshIndicator(
      onRefresh: () => _load(reset: true),
      child: ListView.builder(
        controller: _scrollController,
        padding: EdgeInsets.symmetric(vertical: 8.h),
        itemCount: _posts.length + (_loadingMore ? 1 : 0),
        itemBuilder: (context, index) {
          if (index >= _posts.length) {
            return Padding(
              padding: EdgeInsets.symmetric(vertical: 16.h),
              child: const Center(child: CircularProgressIndicator()),
            );
          }
          final post = _posts[index];
          return BlocProvider(
            create: (_) => context.read<FeedBloc>(),
            child: PostCard(
              post: post,
              currentUserId: _currentUserId,
              onLike: () {
                if (post.isLikedByCurrentUser) {
                  context.read<FeedBloc>().add(UnlikePostRequested(
                      postId: post.id, userId: _currentUserId));
                } else {
                  context.read<FeedBloc>().add(LikePostRequested(
                      postId: post.id, userId: _currentUserId));
                }
                setState(() {
                  _posts = _posts.map((p) {
                    if (p.id == post.id) {
                      return p.copyWith(
                        isLikedByCurrentUser: !p.isLikedByCurrentUser,
                        likesCount: p.isLikedByCurrentUser
                            ? p.likesCount - 1
                            : p.likesCount + 1,
                      );
                    }
                    return p;
                  }).toList();
                });
              },
              onComment: () => context.push('/post/${post.id}'),
              onShare: () => Share.share('PetSpace에서 확인하세요!\n#${widget.hashtag}'),
              onEdit: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => EditPostBottomSheet(
                    post: post,
                    onSave: (updated) {
                      setState(() {
                        _posts = _posts
                            .map((p) => p.id == updated.id ? updated : p)
                            .toList();
                      });
                    },
                  ),
                );
              },
              onDelete: () {
                context.read<FeedBloc>().add(DeletePostRequested(postId: post.id));
                setState(() => _posts.removeWhere((p) => p.id == post.id));
              },
              onHashtagTap: (tag) => context.push('/hashtag/$tag'),
            ),
          );
        },
      ),
    );
  }
}
