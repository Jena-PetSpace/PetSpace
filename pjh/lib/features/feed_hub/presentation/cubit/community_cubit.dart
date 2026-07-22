import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../social/domain/repositories/social_repository.dart';
import '../../domain/entities/community_post.dart';

part 'community_state.dart';

/// 커뮤니티 탭 상태 관리.
///
/// 사진 피드의 [FeedBloc]를 흡수하지 않고 별도 Cubit으로 분리 — Q&A는
/// 좋아요/실시간/낙관적 업데이트가 없는 단순 목록이므로 결합도를 낮춘다.
/// 페이지(위젯) 위에 살아 카테고리 전환·재진입 시 상태를 보존한다.
class CommunityCubit extends Cubit<CommunityState> {
  final SocialRepository _repository;

  /// 한 페이지 글 수. 사진 피드와 동일하게 무한 스크롤 트리거 기준.
  static const int _pageSize = 30;

  CommunityCubit({required SocialRepository repository})
      : _repository = repository,
        super(const CommunityState.initial());

  /// 카테고리를 로드(또는 전환)한다. 첫 페이지부터 새로 조회하고 목록을 교체한다.
  Future<void> loadCategory(String? category) async {
    emit(state.copyWith(
      status: CommunityStatus.loading,
      category: category,
      clearCategory: category == null,
      hasReachedMax: false,
      isLoadingMore: false,
    ));

    final result = await _repository.getCommunityPosts(
      category: category,
      limit: _pageSize,
      beforeCreatedAt: null,
    );

    result.fold(
      (_) => emit(state.copyWith(
        status: CommunityStatus.error,
        errorMessage: '커뮤니티 글을 불러오지 못했어요.',
      )),
      (rows) {
        final posts = rows.map(CommunityPost.fromJson).toList();
        emit(state.copyWith(
          status: CommunityStatus.loaded,
          posts: posts,
          hasReachedMax: posts.length < _pageSize,
        ));
      },
    );
  }

  /// 현재 카테고리로 다음 페이지를 조회해 목록 뒤에 append한다.
  Future<void> loadMore() async {
    if (state.hasReachedMax || state.isLoadingMore) return;
    if (state.posts.isEmpty) return;

    emit(state.copyWith(isLoadingMore: true));

    final result = await _repository.getCommunityPosts(
      category: state.category,
      limit: _pageSize,
      beforeCreatedAt: state.posts.last.createdAt,
    );

    result.fold(
      (_) => emit(state.copyWith(
        isLoadingMore: false,
        errorMessage: '글을 더 불러오지 못했어요.',
      )),
      (rows) {
        final more = rows.map(CommunityPost.fromJson).toList();
        emit(state.copyWith(
          status: CommunityStatus.loaded,
          posts: [...state.posts, ...more],
          hasReachedMax: more.length < _pageSize,
          isLoadingMore: false,
        ));
      },
    );
  }

  /// 현재 카테고리를 처음부터 다시 로드 (당겨서 새로고침).
  Future<void> refresh() => loadCategory(state.category);
}
