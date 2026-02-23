import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../emotion/domain/usecases/get_emotion_history.dart';
import '../../../emotion/domain/usecases/get_emotion_statistics.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../../pets/domain/usecases/get_user_pets.dart';
import '../../../social/domain/entities/post.dart';
import '../../../social/domain/usecases/get_feed.dart';
import 'home_event.dart';
import 'home_state.dart';

class HomeBloc extends Bloc<HomeEvent, HomeState> {
  final GetEmotionHistory getEmotionHistory;
  final GetEmotionStatistics getEmotionStatistics;
  final GetFeed getFeed;
  final GetUserPets getUserPets;
  final String userId;

  HomeBloc({
    required this.getEmotionHistory,
    required this.getEmotionStatistics,
    required this.getFeed,
    required this.getUserPets,
    required this.userId,
  }) : super(HomeInitial()) {
    on<LoadHomeData>(_onLoadHomeData);
    on<RefreshHomeData>(_onRefreshHomeData);
    on<LoadRecentAnalyses>(_onLoadRecentAnalyses);
    on<LoadRecentPosts>(_onLoadRecentPosts);
  }

  Future<void> _onLoadHomeData(
    LoadHomeData event,
    Emitter<HomeState> emit,
  ) async {
    emit(HomeLoading());

    try {
      // 병렬로 데이터 로드
      final results = await Future.wait([
        getEmotionHistory(GetEmotionHistoryParams(userId: userId, limit: 3)),
        getFeed(GetFeedParams(userId: userId, limit: 5)),
        getUserPets(userId),
        getEmotionStatistics(GetEmotionStatisticsParams(userId: userId)),
      ]);

      final analyses = results[0].fold(
        (failure) => <EmotionAnalysis>[],
        (data) => data as List<EmotionAnalysis>,
      );

      final posts = results[1].fold(
        (failure) => <Post>[],
        (data) => data as List<Post>,
      );

      final pets = results[2].fold(
        (failure) => <Pet>[],
        (data) => data as List<Pet>,
      );

      final statistics = results[3].fold(
        (failure) => null,
        (data) => data as Map<String, dynamic>?,
      );

      emit(HomeLoaded(
        recentAnalyses: analyses,
        recentPosts: posts,
        userPets: pets,
        statistics: statistics,
      ));
    } catch (e) {
      emit(HomeError('홈 데이터를 불러오는 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  Future<void> _onRefreshHomeData(
    RefreshHomeData event,
    Emitter<HomeState> emit,
  ) async {
    // 새로고침 시에도 동일하게 데이터 로드
    add(const LoadHomeData());
  }

  Future<void> _onLoadRecentAnalyses(
    LoadRecentAnalyses event,
    Emitter<HomeState> emit,
  ) async {
    if (state is! HomeLoaded) return;

    final currentState = state as HomeLoaded;

    final result = await getEmotionHistory(
      GetEmotionHistoryParams(userId: userId, limit: event.limit),
    );

    result.fold(
      (failure) {
        // 에러 발생해도 현재 상태 유지
      },
      (analyses) {
        emit(currentState.copyWith(recentAnalyses: analyses));
      },
    );
  }

  Future<void> _onLoadRecentPosts(
    LoadRecentPosts event,
    Emitter<HomeState> emit,
  ) async {
    if (state is! HomeLoaded) return;

    final currentState = state as HomeLoaded;

    final result = await getFeed(
      GetFeedParams(userId: userId, limit: event.limit),
    );

    result.fold(
      (failure) {
        // 에러 발생해도 현재 상태 유지
      },
      (posts) {
        emit(currentState.copyWith(recentPosts: posts));
      },
    );
  }
}
