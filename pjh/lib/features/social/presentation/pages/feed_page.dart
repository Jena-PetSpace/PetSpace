import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/utils/share_origin.dart';
import '../../../../core/utils/public_ai_text.dart';
import '../../../../shared/widgets/haptic_refresh_indicator.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../domain/entities/post.dart';
import '../../../../config/injection_container.dart' as di;
import '../../domain/repositories/social_repository.dart';
import '../bloc/feed_bloc.dart';
import '../cubit/operational_cards_cubit.dart';
import '../widgets/comments_bottom_sheet.dart';
import '../widgets/operational_card_tile.dart';
import '../widgets/post_card_connector.dart';
import '../widgets/edit_post_bottom_sheet.dart';
import '../../../../shared/widgets/shimmer_loading.dart';
import '../../../../shared/widgets/network_error_widget.dart';
import '../../../../shared/widgets/empty_state_widget.dart';
import '../../../../shared/themes/app_theme.dart';

class FeedPage extends StatefulWidget {
  final String? userId;
  final bool followingOnly;
  final bool recommended;
  final SocialRepository? repository;
  final CommentBlocFactory? commentsBlocFactory;

  /// 발견 탭 운영(이슈) 카드 인터리브. true면 상위에서
  /// [OperationalCardsCubit] provider가 공급되어야 한다.
  final bool interleaveOperational;

  const FeedPage({
    super.key,
    this.userId,
    this.followingOnly = false,
    this.recommended = false,
    this.interleaveOperational = false,
    this.repository,
    this.commentsBlocFactory,
  });

  @override
  State<FeedPage> createState() => _FeedPageState();
}

class _FeedPageState extends State<FeedPage> {
  final ScrollController _scrollController = ScrollController();
  final Map<String, Post> _authoritativeOverrides = <String, Post>{};
  final Map<String, int> _overrideSourceCommentCounts = <String, int>{};
  final Set<String> _hiddenPostIds = <String>{};

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
              LoadRecommendedPostsRequested(userId: uid),
            );
      }
    } else {
      context.read<FeedBloc>().add(
            LoadFeedRequested(
              userId: _effectiveUserId,
              followingOnly: widget.followingOnly,
            ),
          );
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
        context.read<FeedBloc>().add(
              LoadRecommendedPostsRequested(
                userId: uid,
                offset: state.posts.length,
              ),
            );
      }
    } else {
      context.read<FeedBloc>().add(
            LoadMorePostsRequested(
              userId: widget.userId,
              followingOnly: widget.followingOnly,
            ),
          );
    }
    if (widget.interleaveOperational) {
      // 운영 카드 선로딩 — cubit 자체 가드(hasReachedMax/isLoadingMore)로 안전.
      context.read<OperationalCardsCubit>().loadMore();
    }
  }

  void _dropSupersededCommentOverrides(FeedLoaded state) {
    for (final post in state.posts) {
      final sourceCount = _overrideSourceCommentCounts[post.id];
      if (sourceCount != null && sourceCount != post.commentsCount) {
        _authoritativeOverrides.remove(post.id);
        _overrideSourceCommentCounts.remove(post.id);
      }
    }
  }

  void _clearCommentOverrides() {
    _authoritativeOverrides.clear();
    _overrideSourceCommentCounts.clear();
  }

  void _clearLocalSurfaceOverrides() {
    _clearCommentOverrides();
    _hiddenPostIds.clear();
  }

  String _safeFeedError({bool isNetworkError = false}) {
    return isNetworkError
        ? '네트워크 연결을 확인하고 다시 시도해주세요.'
        : '피드를 불러오지 못했어요. 잠시 후 다시 시도해주세요.';
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<FeedBloc, FeedState>(
      listener: (context, state) {
        if (state is FeedError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                _safeFeedError(isNetworkError: state.isNetworkError),
              ),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        } else if (state is FeedLoaded && state.error != null) {
          _dropSupersededCommentOverrides(state);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(_safeFeedError()),
              backgroundColor: AppTheme.warningColor,
              action: SnackBarAction(
                label: '재시도',
                textColor: Colors.white,
                onPressed: () {
                  context.read<FeedBloc>().add(
                        LoadMorePostsRequested(
                          userId: widget.userId,
                          followingOnly: widget.followingOnly,
                        ),
                      );
                },
              ),
            ),
          );
        } else if (state is FeedLoaded) {
          _dropSupersededCommentOverrides(state);
        } else if (state is FeedPostCreated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('게시물이 성공적으로 작성되었습니다!'),
              backgroundColor: AppTheme.successColor,
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
              _clearLocalSurfaceOverrides();
              final uid = _effectiveUserId;
              if (uid != null) {
                context.read<FeedBloc>().add(
                      LoadRecommendedPostsRequested(userId: uid),
                    );
              }
            },
            child: _buildRecommendedList(state),
          );
        } else if (state is FeedLoaded) {
          return HapticRefreshIndicator(
            onRefresh: () async {
              _clearLocalSurfaceOverrides();
              context.read<FeedBloc>().add(
                    RefreshFeedRequested(
                      userId: widget.userId,
                      followingOnly: widget.followingOnly,
                    ),
                  );
            },
            child: _buildFeedList(state),
          );
        } else if (state is FeedError) {
          if (state.isNetworkError) {
            return _buildNetworkErrorState();
          }
          return _buildErrorState(
            _safeFeedError(isNetworkError: state.isNetworkError),
          );
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
    List<Post> posts,
    List<OperationalCard> cards,
  ) {
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
    FeedRecommendedLoaded state,
    List<OperationalCard> cards,
  ) {
    final items = _interleaveOperationalCards(state.posts, cards);
    return ListView.builder(
      controller: _scrollController,
      padding: EdgeInsets.symmetric(vertical: 8.h),
      itemCount: items.length + (state.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index >= items.length) {
          return Padding(
            padding: EdgeInsets.symmetric(vertical: 16.h),
            child: const Center(child: CircularProgressIndicator()),
          );
        }
        final item = items[index];
        if (item is OperationalCard) {
          return OperationalCardTile(card: item);
        }
        return _buildPostCard(item as Post);
      },
    );
  }

  Widget _buildFeedList(FeedLoaded state) {
    if (state.posts.isEmpty) {
      return _buildEmptyState();
    }

    return ListView.builder(
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
    );
  }

  Widget _buildPostCard(Post post) {
    if (_hiddenPostIds.contains(post.id)) return const SizedBox.shrink();
    final override = _authoritativeOverrides[post.id];
    final visiblePost = override == null
        ? post
        : post.copyWith(commentsCount: override.commentsCount);
    final uid = _effectiveUserId ?? '';
    return PostCardConnector(
      post: visiblePost,
      currentUserId: uid,
      repository: widget.repository ?? di.sl<SocialRepository>(),
      commentBlocFactory: widget.commentsBlocFactory,
      onPostChanged: (updated) {
        setState(() {
          if (updated.commentsCount == post.commentsCount) {
            _authoritativeOverrides.remove(updated.id);
            _overrideSourceCommentCounts.remove(updated.id);
          } else {
            _authoritativeOverrides[updated.id] = updated;
            _overrideSourceCommentCounts[updated.id] = post.commentsCount;
          }
        });
      },
      onPostRemoved: (postId) {
        setState(() => _hiddenPostIds.add(postId));
      },
      onLikeRequested: () {
        if (uid.isEmpty) return;
        if (visiblePost.isLikedByCurrentUser) {
          context.read<FeedBloc>().add(
                UnlikePostRequested(postId: post.id, userId: uid),
              );
        } else {
          context.read<FeedBloc>().add(
                LikePostRequested(postId: post.id, userId: uid),
              );
        }
      },
      shareText: _shareText(visiblePost),
      shareHandler: (text) =>
          Share.share(text, sharePositionOrigin: shareOrigin(context)),
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
      onDeleteRequested: () {
        context.read<FeedBloc>().add(DeletePostRequested(postId: post.id));
      },
      onHashtagTap: (hashtag) => context.push('/hashtag/$hashtag'),
    );
  }

  Widget _buildEmptyState() {
    final isFollowing = widget.followingOnly;
    return EmptyStateWidget(
      icon: Icons.feed_outlined,
      title: isFollowing ? '팔로잉 피드가 비어있어요' : '아직 게시물이 없어요',
      subtitle: isFollowing
          ? '친구를 팔로우하고\n반려동물 일상을 함께해보세요!'
          : '반려동물의 일상을 공유하고\n친구들과 소통해보세요!',
      secondaryLabel: isFollowing ? '탐색하기' : null,
      onSecondary: isFollowing ? () => context.go('/search') : null,
      actionLabel: '첫 게시물 작성',
      onAction: _openCanonicalComposer,
    );
  }

  Widget _buildNetworkErrorState() {
    return NetworkErrorScreen(
      onRetry: () => context.read<FeedBloc>().add(
            LoadFeedRequested(
              userId: widget.userId,
              followingOnly: widget.followingOnly,
            ),
          ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64.w, color: AppTheme.errorColor),
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
            style: TextStyle(fontSize: 14.sp, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16.h),
          ElevatedButton(
            onPressed: () {
              context.read<FeedBloc>().add(
                    LoadFeedRequested(
                      userId: widget.userId,
                      followingOnly: widget.followingOnly,
                    ),
                  );
            },
            child: Text('다시 시도', style: TextStyle(fontSize: 14.sp)),
          ),
        ],
      ),
    );
  }

  Future<void> _openCanonicalComposer() async {
    await context.push<void>('/create-post');
    if (!mounted) return;

    _clearLocalSurfaceOverrides();
    if (widget.recommended) {
      final userId = _effectiveUserId;
      if (userId != null) {
        context.read<FeedBloc>().add(
              LoadRecommendedPostsRequested(userId: userId),
            );
      }
      return;
    }

    context.read<FeedBloc>().add(
          RefreshFeedRequested(
            userId: _effectiveUserId,
            followingOnly: widget.followingOnly,
          ),
        );
  }

  String _shareText(Post post) {
    final content = publicAiText(post.content ?? '');
    final preview =
        content.length > 100 ? '${content.substring(0, 100)}...' : content;
    return preview.isEmpty
        ? 'PetSpace에서 게시물을 확인해보세요.'
        : '$preview\n\nPetSpace에서 게시물을 확인해보세요.';
  }
}
