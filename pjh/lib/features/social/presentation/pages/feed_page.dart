import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../shared/themes/app_theme.dart';
import '../../../../shared/widgets/haptic_refresh_indicator.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/post.dart';
import '../bloc/feed_bloc.dart';
import '../cubit/operational_cards_cubit.dart';
import '../utils/feed_grid_filter.dart';
import '../widgets/operational_card_tile.dart';
import '../widgets/post_card.dart';
import '../widgets/create_post_bottom_sheet.dart';
import '../widgets/edit_post_bottom_sheet.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/network_error_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../widgets/trending_hashtags_section.dart';

/// 피드 표시 방식 — 위젯 로컬 상태(BLoC 무관).
enum FeedViewMode { list, grid }

class FeedPage extends StatefulWidget {
  final String? userId;
  final bool followingOnly;
  final bool recommended;

  /// 발견 탭 운영(이슈) 카드 인터리브. true면 상위에서
  /// [OperationalCardsCubit] provider가 공급되어야 한다.
  final bool interleaveOperational;

  const FeedPage({
    super.key,
    this.userId,
    this.followingOnly = false,
    this.recommended = false,
    this.interleaveOperational = false,
  });

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();

  /// 리스트/그리드 토글 — 위젯 state. BLoC·페이지네이션과 무관. 기본 리스트.
  FeedViewMode _viewMode = FeedViewMode.list;

  String? get _effectiveUserId {
    if (widget.userId != null && widget.userId!.isNotEmpty) {
      return widget.userId;
    }
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticated) return authState.user.id;
    return null;
  }

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    if (widget.recommended) {
      final uid = _effectiveUserId;
      if (uid != null) {
        context.read<FeedBloc>().add(
            LoadRecommendedPostsRequested(userId: uid));
      }
    } else {
      context.read<FeedBloc>().add(LoadFeedRequested(
          userId: _effectiveUserId, followingOnly: widget.followingOnly));
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_scrollController.position.pixels <
        _scrollController.position.maxScrollExtent * 0.8) {
      return;
    }
    final state = context.read<FeedBloc>().state;
    if (state is FeedRecommendedLoaded) {
      // 추천 피드 offset 커서 페이지네이션 (재진입 가드는 bloc 측).
      final uid = _effectiveUserId;
      if (uid != null) {
        context.read<FeedBloc>().add(LoadRecommendedPostsRequested(
            userId: uid, offset: state.posts.length));
      }
    } else {
      context.read<FeedBloc>().add(LoadMorePostsRequested(
          userId: widget.userId, followingOnly: widget.followingOnly));
    }
    if (widget.interleaveOperational) {
      // 운영 카드 선로딩 — cubit 자체 가드(hasReachedMax/isLoadingMore)로 안전.
      context.read<OperationalCardsCubit>().loadMore();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedBloc, FeedState>(
      listener: (context, state) {
        if (state is FeedError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: Colors.red,
            ),
          );
        } else if (state is FeedLoaded && state.error != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.error!),
              backgroundColor: Colors.orange,
              action: SnackBarAction(
                label: '재시도',
                textColor: Colors.white,
                onPressed: () {
                  context
                      .read<FeedBloc>()
                      .add(LoadMorePostsRequested(userId: widget.userId));
                },
              ),
            ),
          );
        } else if (state is FeedPostCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시물이 성공적으로 작성되었습니다!'),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
      builder: (context, state) {
        if (state is FeedLoading) {
          return const FeedShimmerLoading();
        } else if (state is FeedRecommendedLoaded) {
          return HapticRefreshIndicator(
            onRefresh: () async {
              final uid = _effectiveUserId;
              if (uid != null) {
                context.read<FeedBloc>().add(
                    LoadRecommendedPostsRequested(userId: uid));
              }
            },
            child: _buildRecommendedList(state),
          );
        } else if (state is FeedLoaded) {
          return HapticRefreshIndicator(
            onRefresh: () async {
              context.read<FeedBloc>().add(RefreshFeedRequested(
                  userId: widget.userId, followingOnly: widget.followingOnly));
            },
            child: _buildFeedList(state),
          );
        } else if (state is FeedError) {
          if (state.isNetworkError) {
            return _buildNetworkErrorState();
          }
          return _buildErrorState(state.message);
        }

        return const SizedBox.shrink();
      },
    );
  }

  Widget _buildRecommendedList(FeedRecommendedLoaded state) {
    if (state.posts.isEmpty) {
      return _buildEmptyState();
    }
    if (!widget.interleaveOperational) {
      return _buildRecommendedContent(state, const []);
    }
    return BlocBuilder<OperationalCardsCubit, OperationalCardsState>(
      builder: (context, opState) =>
          _buildRecommendedContent(state, opState.cards),
    );
  }

  /// 유저 4 : 운영 1 인터리브 간격.
  static const int _kOperationalInterval = 5;

  /// 유저 포스트 사이에 운영 카드를 끼워 넣은 표시용 리스트를 만든다.
  ///
  /// 원본 posts 리스트는 변형하지 않는다 — FeedBloc의 좋아요 낙관적
  /// 업데이트가 post 리스트를 id로 매핑하므로 오염 금지. 운영 카드가
  /// 모자라면 있는 만큼만 끼워 넣는다(비율 자동 하향).
  List<Object> _interleaveOperationalCards(
      List<Post> posts, List<OperationalCard> cards) {
    if (cards.isEmpty) return List<Object>.from(posts);
    final items = <Object>[];
    var cardIndex = 0;
    for (var i = 0; i < posts.length; i++) {
      items.add(posts[i]);
      if ((i + 1) % (_kOperationalInterval - 1) == 0 &&
          cardIndex < cards.length) {
        items.add(cards[cardIndex++]);
      }
    }
    return items;
  }

  Widget _buildRecommendedContent(
      FeedRecommendedLoaded state, List<OperationalCard> cards) {
    final items = _interleaveOperationalCards(state.posts, cards);
    // 토글 바만 위에 얹고, 아래는 _viewMode로 분기. 리스트 경로는 기존과 동일.
    return Column(
      children: [
        _buildViewToggle(),
        Expanded(
          child: _viewMode == FeedViewMode.list
              ? ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: items.length + (state.isLoadingMore ? 1 : 0) + 1,
                  itemBuilder: (context, index) {
                    if (index == 0) return const TrendingHashtagsSection();
                    final itemIndex = index - 1;
                    if (itemIndex >= items.length) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }
                    final item = items[itemIndex];
                    if (item is OperationalCard) {
                      return OperationalCardTile(card: item);
                    }
                    return _buildPostCard(item as Post);
                  },
                )
              // 사진 그리드는 유저 포스트 전용 — 운영 카드 인터리브 없음.
              : _buildPhotoGrid(state.posts),
        ),
      ],
    );
  }

  Widget _buildFeedList(FeedLoaded state) {
    if (state.posts.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      children: [
        _buildViewToggle(),
        Expanded(
          child: _viewMode == FeedViewMode.list
              ? ListView.builder(
                  controller: _scrollController,
                  padding: EdgeInsets.symmetric(vertical: 8.h),
                  itemCount: state.posts.length + (state.isLoadingMore ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index >= state.posts.length) {
                      return Padding(
                        padding: EdgeInsets.symmetric(vertical: 16.h),
                        child: const Center(child: CircularProgressIndicator()),
                      );
                    }

                    final post = state.posts[index];
                    return _buildPostCard(post);
                  },
                )
              : _buildPhotoGrid(state.posts),
        ),
      ],
    );
  }

  /// 리스트/그리드 토글 바. 위젯 state(_viewMode)만 바꾼다 — BLoC 무관.
  Widget _buildViewToggle() {
    Widget btn(FeedViewMode mode, IconData icon, String tooltip) {
      final active = _viewMode == mode;
      return IconButton(
        tooltip: tooltip,
        visualDensity: VisualDensity.compact,
        icon: Icon(
          icon,
          size: 22.w,
          color: active
              ? AppTheme.primaryColor
              : AppTheme.secondaryTextColor,
        ),
        onPressed: active ? null : () => setState(() => _viewMode = mode),
      );
    }

    return Container(
      color: AppTheme.surfaceColor,
      padding: EdgeInsets.symmetric(horizontal: 8.w),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          btn(FeedViewMode.list, Icons.view_list_rounded, '리스트 보기'),
          btn(FeedViewMode.grid, Icons.grid_view_rounded, '그리드 보기'),
        ],
      ),
    );
  }

  /// 사진 그리드 — 이미지 있는 글만(렌더용 필터). 원본 posts·페이지네이션은
  /// 변형하지 않으며, 무한스크롤은 공유 _scrollController로 원본 기준 트리거된다.
  Widget _buildPhotoGrid(List<Post> posts) {
    final gridPosts = feedGridPosts(posts);
    if (gridPosts.isEmpty) {
      return _buildGridEmptyState();
    }
    return GridView.builder(
      controller: _scrollController,
      padding: EdgeInsets.all(2.w),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        childAspectRatio: 1,
        crossAxisSpacing: 2,
        mainAxisSpacing: 2,
      ),
      itemCount: gridPosts.length,
      itemBuilder: (context, index) => _buildGridCell(gridPosts[index]),
    );
  }

  Widget _buildGridCell(post) {
    final imageUrl = post.imageUrls.first as String;
    final hasMultiple = post.imageUrls.length > 1;
    return GestureDetector(
      onTap: () => context.push('/post/${post.id}'),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CachedNetworkImage(
            imageUrl: imageUrl,
            fit: BoxFit.cover,
            placeholder: (context, url) => Container(
              color: AppTheme.dividerColor,
            ),
            errorWidget: (context, url, error) => Container(
              color: AppTheme.dividerColor,
              child: Icon(Icons.broken_image_outlined,
                  color: AppTheme.secondaryTextColor, size: 20.w),
            ),
          ),
          if (hasMultiple)
            Positioned(
              top: 4.w,
              right: 4.w,
              child: Icon(Icons.collections_rounded,
                  size: 16.w, color: Colors.white),
            ),
        ],
      ),
    );
  }

  /// 그리드인데 사진글이 0개일 때 — 리스트로 전환 유도.
  Widget _buildGridEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_not_supported_outlined,
              size: 48.w, color: AppTheme.secondaryTextColor),
          SizedBox(height: 12.h),
          Text('표시할 사진이 없어요',
              style: TextStyle(
                  fontSize: 14.sp, color: AppTheme.secondaryTextColor)),
          SizedBox(height: 12.h),
          TextButton(
            onPressed: () => setState(() => _viewMode = FeedViewMode.list),
            child: Text('리스트로 보기',
                style: TextStyle(
                    fontSize: 13.sp,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.primaryColor)),
          ),
        ],
      ),
    );
  }

  Widget _buildPostCard(post) {
    final uid = _effectiveUserId ?? '';
    return PostCard(
      post: post,
      currentUserId: uid,
      onLike: () {
        if (uid.isEmpty) return;
        if (post.isLikedByCurrentUser) {
          context.read<FeedBloc>().add(UnlikePostRequested(
                postId: post.id,
                userId: uid,
              ));
        } else {
          context.read<FeedBloc>().add(LikePostRequested(
                postId: post.id,
                userId: uid,
              ));
        }
      },
      onComment: () => context.push('/post/${post.id}'),
      onShare: () => _sharePost(post),
      onEdit: () {
        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => EditPostBottomSheet(
            post: post,
            onSave: (updatedPost) {
              context.read<FeedBloc>().add(
                    UpdatePostRequested(post: updatedPost),
                  );
            },
          ),
        );
      },
      onDelete: () {
        context.read<FeedBloc>().add(DeletePostRequested(postId: post.id));
      },
      onHashtagTap: (hashtag) => context.push('/hashtag/$hashtag'),
    );
  }

  Widget _buildEmptyState() {
    final isFollowing = widget.followingOnly;
    return EmptyStateWidget(
      icon: Icons.feed_outlined,
      emoji: isFollowing ? '🐾' : '🐾',
      badgeEmoji: '✨',
      title: isFollowing ? '팔로잉 피드가 비어있어요' : '아직 게시물이 없어요',
      subtitle: isFollowing
          ? '친구를 팔로우하고\n반려동물 일상을 함께해보세요!'
          : '반려동물의 일상을 공유하고\n친구들과 소통해보세요!',
      secondaryLabel: isFollowing ? '탐색하기' : null,
      onSecondary: isFollowing ? () => context.go('/explore') : null,
      actionLabel: '첫 게시물 작성',
      onAction: _showCreatePostBottomSheet,
    );
  }

  Widget _buildNetworkErrorState() {
    return NetworkErrorScreen(
      onRetry: () => context.read<FeedBloc>().add(
            LoadFeedRequested(
                userId: widget.userId, followingOnly: widget.followingOnly),
          ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64.w,
            color: Colors.red,
          ),
          SizedBox(height: 16.h),
          Text(
            '오류가 발생했습니다',
            style: TextStyle(
              fontSize: 18.sp,
              color: Theme.of(context).textTheme.titleMedium?.color,
            ),
          ),
          SizedBox(height: 8.h),
          Text(
            message,
            style: TextStyle(
              fontSize: 14.sp,
              color: Colors.grey[600],
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              context.read<FeedBloc>().add(LoadFeedRequested(
                  userId: widget.userId, followingOnly: widget.followingOnly));
            },
            child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  void _showCreatePostBottomSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreatePostBottomSheet(
        currentUserId: _effectiveUserId ?? '',
        onPostCreated: (post) {
          context.read<FeedBloc>().add(CreatePostRequested(post: post));
        },
      ),
    );
  }

  void _sharePost(post) {
    final caption = post.caption ?? '';
    final preview =
        caption.length > 100 ? '${caption.substring(0, 100)}...' : caption;
    Share.share('$preview\n\nPetSpace에서 확인하세요!');
  }
}
