import 'dart:developer' as dev;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../shared/constants/community_categories.dart';
import '../../domain/repositories/social_repository.dart';

/// 발견 탭에 인터리브되는 운영(이슈) 콘텐츠 카드 읽기 모델.
class OperationalCard extends Equatable {
  /// posts.id — 중복 제거 키이자 상세(/post/:id) 라우팅 키.
  final String id;

  /// 본문 첫 줄 (카드 타이틀).
  final String title;

  /// 노출 카테고리 라벨 (매거진/케어가이드/교육/정책).
  final String categoryLabel;

  final DateTime createdAt;

  const OperationalCard({
    required this.id,
    required this.title,
    required this.categoryLabel,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [id, title, categoryLabel, createdAt];
}

enum OperationalCardsStatus { initial, loading, loaded }

class OperationalCardsState extends Equatable {
  final OperationalCardsStatus status;
  final List<OperationalCard> cards;
  final bool isLoadingMore;
  final bool hasReachedMax;

  const OperationalCardsState({
    required this.status,
    required this.cards,
    required this.isLoadingMore,
    required this.hasReachedMax,
  });

  const OperationalCardsState.initial()
      : status = OperationalCardsStatus.initial,
        cards = const [],
        isLoadingMore = false,
        hasReachedMax = false;

  OperationalCardsState copyWith({
    OperationalCardsStatus? status,
    List<OperationalCard>? cards,
    bool? isLoadingMore,
    bool? hasReachedMax,
  }) {
    return OperationalCardsState(
      status: status ?? this.status,
      cards: cards ?? this.cards,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasReachedMax: hasReachedMax ?? this.hasReachedMax,
    );
  }

  @override
  List<Object?> get props => [status, cards, isLoadingMore, hasReachedMax];
}

/// 발견 탭 운영 카드 공급 Cubit.
///
/// 소스 2축: ① hashtag 'magazine' 글(keyset: lastPostId)
/// ② 구 이슈 카테고리 글(careguide/education/policy, keyset: beforeCreatedAt).
/// FeedBloc(유저 피드 커서)와 완전히 독립 — 병합은 프레젠테이션 build에서만.
/// 소스 간 post.id 중복은 제거한다.
class OperationalCardsCubit extends Cubit<OperationalCardsState> {
  final SocialRepository _repository;

  /// 소스별 1회 조회량. 유저 피드 1페이지(20건)당 필요 카드 5장 대비 여유.
  static const int _pageSize = 10;

  String? _magazineLastPostId;
  bool _magazineExhausted = false;
  final Map<String, DateTime?> _categoryCursors = {
    for (final c in CommunityCategories.operationalCardCategories) c: null,
  };
  final Set<String> _exhaustedCategories = {};
  final Set<String> _seenIds = {};

  OperationalCardsCubit({required SocialRepository repository})
      : _repository = repository,
        super(const OperationalCardsState.initial());

  bool get _allExhausted =>
      _magazineExhausted &&
      _exhaustedCategories.length ==
          CommunityCategories.operationalCardCategories.length;

  /// 최초 로드. 이미 로드됐으면 무시.
  Future<void> load() async {
    if (state.status != OperationalCardsStatus.initial) return;
    emit(state.copyWith(status: OperationalCardsStatus.loading));
    final fresh = await _fetchRound();
    emit(state.copyWith(
      status: OperationalCardsStatus.loaded,
      cards: fresh,
      hasReachedMax: _allExhausted,
    ));
  }

  /// 잔여 카드가 부족할 때 다음 페이지 조회. 자체 가드로 재진입 안전.
  Future<void> loadMore() async {
    if (state.status != OperationalCardsStatus.loaded) return;
    if (state.hasReachedMax || state.isLoadingMore) return;
    emit(state.copyWith(isLoadingMore: true));
    final fresh = await _fetchRound();
    emit(state.copyWith(
      cards: [...state.cards, ...fresh],
      isLoadingMore: false,
      hasReachedMax: _allExhausted,
    ));
  }

  /// 소진되지 않은 모든 소스에서 한 페이지씩 수집 → id 중복 제거 → 최신순.
  Future<List<OperationalCard>> _fetchRound() async {
    final collected = <OperationalCard>[];

    if (!_magazineExhausted) {
      final result = await _repository.searchPostsByHashtag(
        hashtag: 'magazine',
        limit: _pageSize,
        lastPostId: _magazineLastPostId,
      );
      result.fold(
        (failure) {
          // 실패 소스는 소진 처리 — 스크롤마다 재시도 루프 방지.
          dev.log('운영 카드 매거진 로드 실패: ${failure.message}',
              name: 'OperationalCardsCubit');
          _magazineExhausted = true;
        },
        (posts) {
          if (posts.length < _pageSize) _magazineExhausted = true;
          if (posts.isNotEmpty) _magazineLastPostId = posts.last.id;
          collected.addAll(posts.map((p) => OperationalCard(
                id: p.id,
                title: _firstLine(p.content),
                categoryLabel: CommunityCategories.magazine.label,
                createdAt: p.createdAt,
              )));
        },
      );
    }

    for (final category in CommunityCategories.operationalCardCategories) {
      if (_exhaustedCategories.contains(category)) continue;
      final result = await _repository.getCommunityPosts(
        category: category,
        limit: _pageSize,
        beforeCreatedAt: _categoryCursors[category],
      );
      result.fold(
        (failure) {
          dev.log('운영 카드 $category 로드 실패: ${failure.message}',
              name: 'OperationalCardsCubit');
          _exhaustedCategories.add(category);
        },
        (rows) {
          if (rows.length < _pageSize) _exhaustedCategories.add(category);
          for (final row in rows) {
            final createdAtStr = row['created_at'] as String?;
            final createdAt = createdAtStr != null
                ? DateTime.parse(createdAtStr)
                : DateTime.fromMillisecondsSinceEpoch(0);
            _categoryCursors[category] = createdAt;
            collected.add(OperationalCard(
              id: row['id'] as String,
              title: _firstLine(row['caption'] as String?),
              categoryLabel: CommunityCategories.label(category),
              createdAt: createdAt,
            ));
          }
        },
      );
    }

    // 소스 간(예: magazine 해시태그 + careguide 카테고리 동시 보유) 중복 제거.
    final fresh =
        collected.where((card) => _seenIds.add(card.id)).toList()
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return fresh;
  }

  static String _firstLine(String? content) {
    final line = (content ?? '').split('\n').first.trim();
    return line.isEmpty ? '펫페이스 소식' : line;
  }
}
