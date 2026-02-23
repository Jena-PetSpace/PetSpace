part of 'profile_bloc.dart';

abstract class ProfileState extends Equatable {
  const ProfileState();

  @override
  List<Object?> get props => [];
}

class ProfileInitial extends ProfileState {}

class ProfileLoading extends ProfileState {}

class ProfileLoaded extends ProfileState {
  final SocialUser user;
  final bool isFollowing;
  final String? error;

  const ProfileLoaded({
    required this.user,
    required this.isFollowing,
    this.error,
  });

  ProfileLoaded copyWith({
    SocialUser? user,
    bool? isFollowing,
    String? error,
  }) {
    return ProfileLoaded(
      user: user ?? this.user,
      isFollowing: isFollowing ?? this.isFollowing,
      error: error,
    );
  }

  @override
  List<Object?> get props => [user, isFollowing, error];
}

class ProfileError extends ProfileState {
  final String message;

  const ProfileError(this.message);

  @override
  List<Object?> get props => [message];
}