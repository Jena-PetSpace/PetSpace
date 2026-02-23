import 'package:equatable/equatable.dart';

import '../../../emotion/domain/entities/emotion_analysis.dart';
import '../../../social/domain/entities/post.dart';
import '../../../pets/domain/entities/pet.dart';

abstract class HomeState extends Equatable {
  const HomeState();

  @override
  List<Object?> get props => [];
}

class HomeInitial extends HomeState {}

class HomeLoading extends HomeState {}

class HomeLoaded extends HomeState {
  final List<EmotionAnalysis> recentAnalyses;
  final List<Post> recentPosts;
  final List<Pet> userPets;
  final Map<String, dynamic>? statistics;

  const HomeLoaded({
    required this.recentAnalyses,
    required this.recentPosts,
    required this.userPets,
    this.statistics,
  });

  @override
  List<Object?> get props => [recentAnalyses, recentPosts, userPets, statistics];

  HomeLoaded copyWith({
    List<EmotionAnalysis>? recentAnalyses,
    List<Post>? recentPosts,
    List<Pet>? userPets,
    Map<String, dynamic>? statistics,
  }) {
    return HomeLoaded(
      recentAnalyses: recentAnalyses ?? this.recentAnalyses,
      recentPosts: recentPosts ?? this.recentPosts,
      userPets: userPets ?? this.userPets,
      statistics: statistics ?? this.statistics,
    );
  }
}

class HomeError extends HomeState {
  final String message;

  const HomeError(this.message);

  @override
  List<Object?> get props => [message];
}
