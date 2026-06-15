part of 'community_cubit.dart';

enum CommunityStatus { initial, loading, loaded, error }

class CommunityState extends Equatable {
  final CommunityStatus status;
  final List<CommunityPost> posts;

  /// 현재 선택된 카테고리. null = 전체.
  final String? category;
  final bool hasReachedMax;
  final bool isLoadingMore;
  final String? errorMessage;

  const CommunityState({
    required this.status,
    required this.posts,
    required this.category,
    required this.hasReachedMax,
    required this.isLoadingMore,
    required this.errorMessage,
  });

  const CommunityState.initial()
      : status = CommunityStatus.initial,
        posts = const [],
        category = null,
        hasReachedMax = false,
        isLoadingMore = false,
        errorMessage = null;

  CommunityState copyWith({
    CommunityStatus? status,
    List<CommunityPost>? posts,
    String? category,
    bool clearCategory = false,
    bool? hasReachedMax,
    bool? isLoadingMore,
    String? errorMessage,
  }) {
    return CommunityState(
      status: status ?? this.status,
      posts: posts ?? this.posts,
      category: clearCategory ? null : (category ?? this.category),
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      // errorMessage는 명시적으로 넘길 때만 갱신 (성공 emit 시 자동 클리어)
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        posts,
        category,
        hasReachedMax,
        isLoadingMore,
        errorMessage,
      ];
}
