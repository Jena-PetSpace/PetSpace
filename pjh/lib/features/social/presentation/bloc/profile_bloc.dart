import 'dart:async';
import 'dart:io';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../domain/entities/social_user.dart';
import '../../domain/usecases/get_user_profile.dart';
import '../../domain/usecases/follow_user.dart';
import '../../domain/usecases/unfollow_user.dart';
import '../../domain/repositories/social_repository.dart';
import '../../../../core/services/push_notification_service.dart';

part 'profile_event.dart';
part 'profile_state.dart';

class ProfileBloc extends Bloc<ProfileEvent, ProfileState> {
  final _pushService = PushNotificationService();
  final GetUserProfile _getUserProfile;
  final FollowUser _followUser;
  final UnfollowUser _unfollowUser;
  final SocialRepository _socialRepository;

  ProfileBloc({
    required GetUserProfile getUserProfile,
    required FollowUser followUser,
    required UnfollowUser unfollowUser,
    required SocialRepository socialRepository,
  })  : _getUserProfile = getUserProfile,
        _followUser = followUser,
        _unfollowUser = unfollowUser,
        _socialRepository = socialRepository,
        super(ProfileInitial()) {
    on<LoadUserProfileRequested>(_onLoadUserProfileRequested);
    on<FollowUserRequested>(_onFollowUserRequested);
    on<UnfollowUserRequested>(_onUnfollowUserRequested);
    on<RefreshProfileRequested>(_onRefreshProfileRequested);
    on<UpdateCoverImageRequested>(_onUpdateCoverImageRequested);
  }

  Future<void> _onLoadUserProfileRequested(
    LoadUserProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    emit(ProfileLoading());

    final result =
        await _getUserProfile(GetUserProfileParams(userId: event.userId));

    await result.fold(
      (failure) async => emit(ProfileError(failure.message)),
      (user) async {
        // 현재 사용자 ID와 프로필 사용자 ID가 다를 경우에만 팔로우 여부 확인
        bool isFollowing = false;
        if (event.currentUserId != null &&
            event.currentUserId != event.userId) {
          final followResult = await _socialRepository.isFollowing(
            event.currentUserId!,
            event.userId,
          );
          followResult.fold(
            (failure) {
              // 팔로우 여부 확인 실패 시 false로 처리
              isFollowing = false;
            },
            (following) {
              isFollowing = following;
            },
          );
        }

        emit(ProfileLoaded(
          user: user,
          isFollowing: isFollowing,
        ));
      },
    );
  }

  Future<void> _onFollowUserRequested(
    FollowUserRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is ProfileLoaded) {
      final currentState = state as ProfileLoaded;
      emit(currentState.copyWith(
        isFollowing: true,
        user: currentState.user.copyWith(
          followersCount: currentState.user.followersCount + 1,
        ),
      ));

      final result = await _followUser(FollowUserParams(
        followerId: event.followerId,
        followingId: event.followingId,
      ));

      result.fold(
        (failure) {
          // Revert optimistic update
          emit(currentState.copyWith(
            isFollowing: false,
            user: currentState.user.copyWith(
              followersCount: currentState.user.followersCount - 1,
            ),
          ));
          emit(currentState.copyWith(error: failure.message));
        },
        (follow) {
          // 팔로우 성공 → 대상 사용자에게 알림 발송
          _pushService.sendFollowNotification(
            toUserId: event.followingId,
            fromUserId: event.followerId,
            fromUserName: event.followerName,
          );
        },
      );
    }
  }

  Future<void> _onUnfollowUserRequested(
    UnfollowUserRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is ProfileLoaded) {
      final currentState = state as ProfileLoaded;
      emit(currentState.copyWith(
        isFollowing: false,
        user: currentState.user.copyWith(
          followersCount: currentState.user.followersCount - 1,
        ),
      ));

      final result = await _unfollowUser(UnfollowUserParams(
        followerId: event.followerId,
        followingId: event.followingId,
      ));

      result.fold(
        (failure) {
          // Revert optimistic update
          emit(currentState.copyWith(
            isFollowing: true,
            user: currentState.user.copyWith(
              followersCount: currentState.user.followersCount + 1,
            ),
          ));
          emit(currentState.copyWith(error: failure.message));
        },
        (_) {
          // Update was successful, keep the optimistic state
        },
      );
    }
  }

  Future<void> _onUpdateCoverImageRequested(
    UpdateCoverImageRequested event,
    Emitter<ProfileState> emit,
  ) async {
    if (state is! ProfileLoaded) return;
    final current = state as ProfileLoaded;

    final result =
        await _socialRepository.uploadCoverImage(event.userId, event.file);

    result.fold(
      (failure) => emit(current.copyWith(error: failure.message)),
      (url) {
        emit(current.copyWith(
          user: current.user.copyWith(coverImageUrl: url),
        ));
      },
    );
  }

  Future<void> _onRefreshProfileRequested(
    RefreshProfileRequested event,
    Emitter<ProfileState> emit,
  ) async {
    final result =
        await _getUserProfile(GetUserProfileParams(userId: event.userId));

    await result.fold(
      (failure) async => emit(ProfileError(failure.message)),
      (user) async {
        // 현재 사용자 ID와 프로필 사용자 ID가 다를 경우에만 팔로우 여부 확인
        bool isFollowing = false;
        if (event.currentUserId != null &&
            event.currentUserId != event.userId) {
          final followResult = await _socialRepository.isFollowing(
            event.currentUserId!,
            event.userId,
          );
          followResult.fold(
            (failure) {
              isFollowing = false;
            },
            (following) {
              isFollowing = following;
            },
          );
        }

        emit(ProfileLoaded(
          user: user,
          isFollowing: isFollowing,
        ));
      },
    );
  }
}
