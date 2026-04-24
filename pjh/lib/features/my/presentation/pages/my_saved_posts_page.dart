import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';

import '../../../../config/injection_container.dart';
import '../../../../shared/themes/app_theme.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../social/domain/entities/bookmark_collection.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/presentation/bloc/bookmark_bloc.dart';
import '../../../social/presentation/bloc/feed_bloc.dart';
import '../../../social/presentation/widgets/post_card.dart';
import '../../../social/presentation/widgets/edit_post_bottom_sheet.dart';

class MySavedPostsPage extends StatelessWidget {
  const MySavedPostsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    final userId =
        authState is AuthAuthenticated ? authState.user.uid : '';

    return BlocProvider(
      create: (_) => sl<BookmarkBloc>()
        ..add(LoadBookmarkCollections(userId: userId)),
      child: _MySavedPostsView(userId: userId),
    );
  }
}

class _MySavedPostsView extends StatefulWidget {
  final String userId;
  const _MySavedPostsView({required this.userId});

  @override
  State<_MySavedPostsView> createState() => _MySavedPostsViewState();
}

class _MySavedPostsViewState extends State<_MySavedPostsView> {
  String? _selectedCollectionId;
  bool _showingPosts = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.subtleBackground,
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        leading: _showingPosts
            ? IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                onPressed: () => setState(() {
                  _showingPosts = false;
                  _selectedCollectionId = null;
                }),
              )
            : null,
        title: Text(
          _showingPosts ? _collectionName(context) : '저장한 글',
          style: TextStyle(
            fontSize: 18.sp,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryTextColor,
          ),
        ),
        centerTitle: true,
      ),
      body: BlocConsumer<BookmarkBloc, BookmarkState>(
        listener: (context, state) {
          if (state is BookmarkPostMoved) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('컬렉션이 변경되었습니다'),
                backgroundColor: Colors.white,
              ),
            );
            context.read<BookmarkBloc>().add(LoadSavedPostsByCollection(
                userId: widget.userId,
                collectionId: _selectedCollectionId));
          }
        },
        builder: (context, state) {
          if (!_showingPosts) {
            return _buildCollectionGrid(context, state);
          }
          return _buildPostsList(context, state);
        },
      ),
    );
  }

  String _collectionName(BuildContext context) {
    final state = context.read<BookmarkBloc>().state;
    if (_selectedCollectionId == null) return '기본 저장';
    if (state is BookmarkCollectionsLoaded) {
      final col = state.collections
          .where((c) => c.id == _selectedCollectionId)
          .firstOrNull;
      return col?.name ?? '저장한 글';
    }
    return '저장한 글';
  }

  Widget _buildCollectionGrid(BuildContext context, BookmarkState state) {
    if (state is BookmarkLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final collections = state is BookmarkCollectionsLoaded
        ? state.collections
        : <BookmarkCollection>[];

    return RefreshIndicator(
      onRefresh: () async {
        context.read<BookmarkBloc>().add(
            LoadBookmarkCollections(userId: widget.userId));
      },
      child: GridView.builder(
        padding: EdgeInsets.all(16.w),
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12.w,
          mainAxisSpacing: 12.h,
          childAspectRatio: 1.0,
        ),
        itemCount: collections.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _CollectionGridItem(
              emoji: '🔖',
              name: '기본 저장',
              postCount: null,
              onTap: () {
                setState(() {
                  _selectedCollectionId = null;
                  _showingPosts = true;
                });
                context.read<BookmarkBloc>().add(LoadSavedPostsByCollection(
                    userId: widget.userId, collectionId: null));
              },
            );
          }
          final col = collections[index - 1];
          return _CollectionGridItem(
            emoji: col.emoji,
            name: col.name,
            postCount: col.postCount,
            onTap: () {
              setState(() {
                _selectedCollectionId = col.id;
                _showingPosts = true;
              });
              context.read<BookmarkBloc>().add(LoadSavedPostsByCollection(
                  userId: widget.userId, collectionId: col.id));
            },
            onDelete: () => _confirmDelete(context, col),
          );
        },
      ),
    );
  }

  Widget _buildPostsList(BuildContext context, BookmarkState state) {
    if (state is BookmarkPostsLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final posts =
        state is BookmarkPostsLoaded ? state.posts : <Post>[];

    if (posts.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.bookmark_border, size: 64.w, color: Colors.grey[300]),
            SizedBox(height: 16.h),
            Text('저장한 글이 없습니다',
                style:
                    TextStyle(fontSize: 16.sp, color: Colors.grey[500])),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: () async {
        context.read<BookmarkBloc>().add(LoadSavedPostsByCollection(
            userId: widget.userId, collectionId: _selectedCollectionId));
      },
      child: BlocProvider.value(
        value: sl<FeedBloc>(),
        child: ListView.builder(
          padding: EdgeInsets.symmetric(vertical: 8.h),
          itemCount: posts.length,
          itemBuilder: (context, index) {
            final post = posts[index];
            return PostCard(
              post: post,
              currentUserId: widget.userId,
              onLike: () {
                if (post.isLikedByCurrentUser) {
                  context.read<FeedBloc>().add(UnlikePostRequested(
                      postId: post.id, userId: widget.userId));
                } else {
                  context.read<FeedBloc>().add(LikePostRequested(
                      postId: post.id, userId: widget.userId));
                }
              },
              onComment: () => context.push('/post/${post.id}'),
              onShare: () {},
              onEdit: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => EditPostBottomSheet(
                    post: post,
                    onSave: (updated) {
                      context.read<FeedBloc>().add(
                          UpdatePostRequested(post: updated));
                    },
                  ),
                );
              },
              onDelete: () {
                context.read<FeedBloc>().add(
                    DeletePostRequested(postId: post.id));
              },
              onHashtagTap: (tag) => context.push('/hashtag/$tag'),
            );
          },
        ),
      ),
    );
  }

  Future<void> _confirmDelete(
      BuildContext context, BookmarkCollection col) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('컬렉션 삭제'),
        content: Text('"${col.name}" 컬렉션을 삭제할까요?\n저장된 게시물은 삭제되지 않습니다.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('삭제'),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      context.read<BookmarkBloc>().add(
          DeleteBookmarkCollection(collectionId: col.id));
    }
  }
}

class _CollectionGridItem extends StatelessWidget {
  final String emoji;
  final String name;
  final int? postCount;
  final VoidCallback onTap;
  final VoidCallback? onDelete;

  const _CollectionGridItem({
    required this.emoji,
    required this.name,
    required this.postCount,
    required this.onTap,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onDelete != null
          ? () => onDelete!()
          : null,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 36)),
            SizedBox(height: 8.h),
            Text(
              name,
              style: TextStyle(
                fontSize: 14.sp,
                fontWeight: FontWeight.w600,
                color: AppTheme.primaryTextColor,
              ),
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (postCount != null) ...[
              SizedBox(height: 4.h),
              Text(
                '$postCount개',
                style: TextStyle(
                  fontSize: 12.sp,
                  color: AppTheme.secondaryTextColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
