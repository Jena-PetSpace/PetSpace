import 'package:equatable/equatable.dart';

abstract class HomeEvent extends Equatable {
  const HomeEvent();

  @override
  List<Object?> get props => [];
}

class LoadHomeData extends HomeEvent {
  const LoadHomeData();
}

class RefreshHomeData extends HomeEvent {
  const RefreshHomeData();
}

class LoadRecentAnalyses extends HomeEvent {
  final int limit;

  const LoadRecentAnalyses({this.limit = 3});

  @override
  List<Object?> get props => [limit];
}

class LoadRecentPosts extends HomeEvent {
  final int limit;

  const LoadRecentPosts({this.limit = 5});

  @override
  List<Object?> get props => [limit];
}
