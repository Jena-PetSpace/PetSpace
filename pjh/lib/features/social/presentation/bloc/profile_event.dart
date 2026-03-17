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
  final String followerName;  // 알림 발송용

  const FollowUserRequested({
    required this.followerId,
    required this.followingId,
    this.followerName = '사용자',
  });

  @override
  List<Object?> get props => [followerId, followingId, followerName];
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