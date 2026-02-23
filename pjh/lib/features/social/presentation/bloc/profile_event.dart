part of 'profile_bloc.dart';

abstract class ProfileEvent extends Equatable {
  const ProfileEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserProfileRequested extends ProfileEvent {
  final String userId;
  final String? currentUserId;

  const LoadUserProfileRequested({
    required this.userId,
    this.currentUserId,
  });

  @override
  List<Object?> get props => [userId, currentUserId];
}

class FollowUserRequested extends ProfileEvent {
  final String followerId;
  final String followingId;

  const FollowUserRequested({
    required this.followerId,
    required this.followingId,
  });

  @override
  List<Object?> get props => [followerId, followingId];
}

class UnfollowUserRequested extends ProfileEvent {
  final String followerId;
  final String followingId;

  const UnfollowUserRequested({
    required this.followerId,
    required this.followingId,
  });

  @override
  List<Object?> get props => [followerId, followingId];
}

class RefreshProfileRequested extends ProfileEvent {
  final String userId;
  final String? currentUserId;

  const RefreshProfileRequested({
    required this.userId,
    this.currentUserId,
  });

  @override
  List<Object?> get props => [userId, currentUserId];
}