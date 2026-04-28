import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/bookmark_collection.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/follow.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/social_user.dart';
import '../../domain/repositories/social_repository.dart';
import '../datasources/social_remote_data_source.dart';
import '../models/post_model.dart';

class SocialRepositoryImpl implements SocialRepository {
  final SocialRemoteDataSource remoteDataSource;
  final NetworkInfo networkInfo;

  SocialRepositoryImpl({
    required this.remoteDataSource,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, SocialUser>> getUserProfile(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final user = await remoteDataSource.getUser(userId);
      return Right(user);
    } catch (e) {
      return Left(
          ServerFailure(message: '사용자 정보 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, SocialUser>> updateUserProfile(SocialUser user) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final updatedUser = await remoteDataSource.updateUser(user);
      return Right(updatedUser);
    } catch (e) {
      return Left(
          ServerFailure(message: '프로필 업데이트 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SocialUser>>> searchUsers(String query,
      {int limit = 20}) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final users = await remoteDataSource.searchUsers(query, limit, null);
      return Right(users);
    } catch (e) {
      return Left(
          ServerFailure(message: '사용자 검색 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Post>> createPost(Post post, {List<File> images = const []}) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final createdPost = await remoteDataSource.createPost(post, images);
      return Right(createdPost);
    } catch (e) {
      return Left(
          ServerFailure(message: '게시물 작성 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Post>> getPost(String postId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final post = await remoteDataSource.getPost(postId);
      return Right(post);
    } catch (e) {
      return Left(
          ServerFailure(message: '게시물 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getPostDetail(
      String postId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final detail = await remoteDataSource.getPostDetail(postId);
      return Right(detail);
    } catch (e) {
      return Left(
          ServerFailure(message: '게시물 상세 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getUserPostsFiltered({
    required String authorId,
    String? petId,
    String? beforeCreatedAt,
    int limit = 30,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final rows = await remoteDataSource.getUserPostsFiltered(
        authorId: authorId,
        petId: petId,
        beforeCreatedAt: beforeCreatedAt,
        limit: limit,
      );
      return Right(rows);
    } catch (e) {
      return Left(ServerFailure(message: '게시물 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Set<String>>> getEarnedBadgeIds(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final ids = await remoteDataSource.getEarnedBadgeIds(userId);
      return Right(ids);
    } catch (e) {
      return Left(ServerFailure(message: '뱃지 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> checkAndAwardBadges(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      await remoteDataSource.checkAndAwardBadges(userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '뱃지 처리 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getPointTransactions(
      String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final rows = await remoteDataSource.getPointTransactions(userId);
      return Right(rows);
    } catch (e) {
      return Left(ServerFailure(message: '포인트 내역 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getBlockedUsersDetailed(
      String blockerId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final rows = await remoteDataSource.getBlockedUsersDetailed(blockerId);
      return Right(rows);
    } catch (e) {
      return Left(ServerFailure(message: '차단 목록 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> getUserPoints(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final points = await remoteDataSource.getUserPoints(userId);
      return Right(points);
    } catch (e) {
      return Left(ServerFailure(message: '포인트 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> hasQuestActivityToday({
    required String userId,
    required String questType,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final achieved = await remoteDataSource.hasQuestActivityToday(
          userId: userId, questType: questType);
      return Right(achieved);
    } catch (e) {
      return Left(ServerFailure(message: '퀘스트 확인 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> incrementUserPoints({
    required String userId,
    required int points,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      await remoteDataSource.incrementUserPoints(
          userId: userId, points: points);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '포인트 지급 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getSavedPostsRaw(
      String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final rows = await remoteDataSource.getSavedPostsRaw(userId);
      return Right(rows);
    } catch (e) {
      return Left(ServerFailure(message: '저장 게시물 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getCommunityPosts({
    String? category,
    int limit = 30,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final rows = await remoteDataSource.getCommunityPosts(
          category: category, limit: limit);
      return Right(rows);
    } catch (e) {
      return Left(ServerFailure(message: '커뮤니티 게시물 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> getUserStreak(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      // ignore: avoid_dynamic_calls
      final streak = await remoteDataSource.getUserStreak(userId);
      return Right(streak);
    } catch (e) {
      return const Right(0); // RPC 미구현 / 실패 시 0 fallback
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>?>> getNotificationPreferences(
      String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final row = await remoteDataSource.getNotificationPreferences(userId);
      return Right(row);
    } catch (e) {
      return Left(ServerFailure(
          message: '알림 설정 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> upsertNotificationPreference({
    required String userId,
    required String column,
    required bool value,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      await remoteDataSource.upsertNotificationPreference(
          userId: userId, column: column, value: value);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(
          message: '알림 설정 저장 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isPostLiked(
      String postId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final liked = await remoteDataSource.isPostLiked(postId, userId);
      return Right(liked);
    } catch (e) {
      return Left(
          ServerFailure(message: '좋아요 상태 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getFeedPosts({
    required String userId,
    int limit = 20,
    String? lastPostId,
    DateTime? lastCreatedAt,
    bool followingOnly = false,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final posts = await remoteDataSource.getFeedPosts(
        userId, limit, lastPostId,
        lastCreatedAt: lastCreatedAt,
        followingOnly: followingOnly,
      );
      return Right(posts);
    } catch (e) {
      return Left(
          ServerFailure(message: '피드 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getExplorePosts({
    int limit = 20,
    String? lastPostId,
    DateTime? lastCreatedAt,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final posts = await remoteDataSource.getExplorePosts(limit, lastPostId, lastCreatedAt: lastCreatedAt);
      return Right(posts);
    } catch (e) {
      return Left(
          ServerFailure(message: '탐색 게시물 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getUserPosts({
    required String userId,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final posts =
          await remoteDataSource.getUserPosts(userId, limit, lastPostId);
      return Right(posts);
    } catch (e) {
      return Left(
          ServerFailure(message: '사용자 게시물 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> likePost(String postId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.likePost(postId, userId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '좋아요 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unlikePost(String postId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.unlikePost(postId, userId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '좋아요 취소 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePost(String postId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.deletePost(postId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '게시물 삭제 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Comment>> createComment(Comment comment) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final createdComment = await remoteDataSource.createComment(comment);
      return Right(createdComment);
    } catch (e) {
      return Left(
          ServerFailure(message: '댓글 작성 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Comment>>> getPostComments({
    required String postId,
    int limit = 20,
    String? lastCommentId,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final comments =
          await remoteDataSource.getPostComments(postId, limit, lastCommentId);
      return Right(comments);
    } catch (e) {
      return Left(
          ServerFailure(message: '댓글 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Follow>> followUser(
      String followerId, String followingId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.followUser(followerId, followingId);
      return Right(Follow(
        id: '$followerId-$followingId',
        followerId: followerId,
        followingId: followingId,
        followerName: 'Unknown',
        followingName: 'Unknown',
        status: FollowStatus.accepted,
        createdAt: DateTime.now(),
        acceptedAt: DateTime.now(),
      ));
    } catch (e) {
      return Left(
          ServerFailure(message: '팔로우 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unfollowUser(
      String followerId, String followingId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.unfollowUser(followerId, followingId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '팔로우 취소 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> markNotificationAsRead(
      String notificationId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.markNotificationAsRead(notificationId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  // 누락된 메서드들 stub 구현
  @override
  Future<Either<Failure, void>> acceptFollowRequest(String followId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      // 팔로우 요청 승인은 현재 스키마에서 지원하지 않음 (자동 승인 구조)
      // 나중에 pending_follows 테이블 추가 시 구현
      return const Left(ServerFailure(message: '팔로우 요청 승인 기능은 아직 지원하지 않습니다'));
    } catch (e) {
      return Left(
          ServerFailure(message: '팔로우 요청 승인 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> createNotification(
      Notification notification) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.createNotification(notification);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '알림 생성 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.deleteComment(commentId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '댓글 삭제 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  @override
  Future<Either<Failure, List<Post>>> getFeed({
    String? userId,
    int limit = 20,
    String? lastPostId,
    DateTime? lastCreatedAt,
    bool followingOnly = false,
  }) async {
    // userId가 null이거나 빈 문자열이면 전체 피드 조회 (explore)
    final effectiveUserId =
        (userId != null && userId.isNotEmpty) ? userId : null;

    if (effectiveUserId == null) {
      return await getExplorePosts(limit: limit, lastPostId: lastPostId, lastCreatedAt: lastCreatedAt);
    }
    return await getFeedPosts(
      userId: effectiveUserId,
      limit: limit,
      lastPostId: lastPostId,
      lastCreatedAt: lastCreatedAt,
      followingOnly: followingOnly,
    );
  }

  @override
  Future<Either<Failure, List<Follow>>> getFollowers(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final users = await remoteDataSource.getFollowers(userId, 50, null);
      // SocialUser를 Follow로 변환
      final follows = users
          .map((user) => Follow(
                id: '${user.id}-$userId',
                followerId: user.id,
                followingId: userId,
                followerName: user.displayName,
                followingName: 'Me',
                status: FollowStatus.accepted,
                createdAt: DateTime.now(),
                acceptedAt: DateTime.now(),
              ))
          .toList();

      return Right(follows);
    } catch (e) {
      return Left(
          ServerFailure(message: '팔로워 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Follow>>> getFollowing(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final users = await remoteDataSource.getFollowing(userId, 50, null);
      // SocialUser를 Follow로 변환
      final follows = users
          .map((user) => Follow(
                id: '$userId-${user.id}',
                followerId: userId,
                followingId: user.id,
                followerName: 'Me',
                followingName: user.displayName,
                status: FollowStatus.accepted,
                createdAt: DateTime.now(),
                acceptedAt: DateTime.now(),
              ))
          .toList();

      return Right(follows);
    } catch (e) {
      return Left(
          ServerFailure(message: '팔로잉 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Notification>>> getNotifications(
      {required String userId,
      int limit = 20,
      String? lastNotificationId}) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final notifications = await remoteDataSource.getUserNotifications(
          userId, limit, lastNotificationId);
      return Right(notifications);
    } catch (e) {
      return Left(
          ServerFailure(message: '알림 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Notification>>> getUserNotifications(
      {required String userId,
      int limit = 20,
      String? lastNotificationId}) async {
    return await getNotifications(
        userId: userId, limit: limit, lastNotificationId: lastNotificationId);
  }

  @override
  Future<Either<Failure, List<Follow>>> getPendingFollowRequests(
      String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      // 팔로우 요청 대기 기능은 현재 스키마에서 지원하지 않음 (자동 승인 구조)
      // 나중에 pending_follows 테이블 추가 시 구현
      return const Right([]);
    } catch (e) {
      return Left(
          ServerFailure(message: '팔로우 요청 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SocialUser>>> getPostLikes(String postId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final userIds = await remoteDataSource.getPostLikes(postId, 100);

      // 각 사용자 ID를 SocialUser로 변환
      final users = <SocialUser>[];
      for (final userId in userIds) {
        try {
          final user = await remoteDataSource.getUser(userId);
          users.add(user);
        } catch (e) {
          // 개별 사용자 조회 실패 시 건너뛰기
          continue;
        }
      }

      return Right(users);
    } catch (e) {
      return Left(
          ServerFailure(message: '좋아요 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getSharedPosts(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      // 공유된 게시물은 현재 별도 테이블 없이 일반 게시물로 처리됨
      // 추후 shared_posts 테이블 추가하거나 posts 테이블에 shared_from_id 컬럼 추가 필요
      return const Right([]);
    } catch (e) {
      return Left(
          ServerFailure(message: '공유된 게시물 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadNotificationsCount(
      String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      // 안읽은 알림을 가져와서 개수 반환
      final notifications =
          await remoteDataSource.getUserNotifications(userId, 100, null);
      final unreadCount = notifications.where((n) => !n.isRead).length;
      return Right(unreadCount);
    } catch (e) {
      return Left(
          ServerFailure(message: '안읽은 알림 개수 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isFollowing(
      String followerId, String followingId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final isFollowing =
          await remoteDataSource.isFollowing(followerId, followingId);
      return Right(isFollowing);
    } catch (e) {
      return Left(
          ServerFailure(message: '팔로우 여부 확인 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> likeComment(
      String commentId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.likeComment(commentId, userId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '댓글 좋아요 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> markAllNotificationsAsRead(
      String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      // Bulk update로 성능 최적화
      await remoteDataSource.markAllNotificationsAsRead(userId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '모든 알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> rejectFollowRequest(String followId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      // 팔로우 요청 거절은 현재 스키마에서 지원하지 않음 (자동 승인 구조)
      // 나중에 pending_follows 테이블 추가 시 구현
      return const Left(ServerFailure(message: '팔로우 요청 거절 기능은 아직 지원하지 않습니다'));
    } catch (e) {
      return Left(
          ServerFailure(message: '팔로우 요청 거절 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> reportPost(
      String postId, String userId, String reason) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.reportPost(postId, userId, reason);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '게시물 신고 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> reportUser(
      String reportedUserId, String reporterId, String reason) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.reportUser(reportedUserId, reporterId, reason);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '사용자 신고 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> sharePost(String postId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      // 원본 포스트 가져오기
      final originalPost = await remoteDataSource.getPost(postId);

      // 현재 사용자 정보 가져오기
      final currentUser = await remoteDataSource.getUser(userId);

      // 공유 포스트 생성 (원본 포스트 정보 포함)
      final sharedPost = Post(
        id: '', // Supabase가 생성
        authorId: userId,
        authorName: currentUser.displayName,
        authorProfileImage: currentUser.profileImageUrl,
        type: originalPost.type,
        content:
            '${originalPost.authorName}님의 포스트를 공유했습니다.\n\n${originalPost.content ?? ''}',
        imageUrls: originalPost.imageUrls,
        videoUrl: originalPost.videoUrl,
        emotionAnalysis: originalPost.emotionAnalysis,
        tags: originalPost.tags,
        likesCount: 0,
        commentsCount: 0,
        sharesCount: 0,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await remoteDataSource.createPost(sharedPost, []);

      // 원본 포스트의 공유 수 증가는 별도 처리 필요

      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '포스트 공유 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unlikeComment(
      String commentId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      await remoteDataSource.unlikeComment(commentId, userId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '댓글 좋아요 취소 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Comment>> updateComment(Comment comment) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final updatedComment = await remoteDataSource.updateComment(comment);
      return Right(updatedComment);
    } catch (e) {
      return Left(
          ServerFailure(message: '댓글 수정 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Post>> updatePost(Post post) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final updatedPost = await remoteDataSource.updatePost(post);
      return Right(updatedPost);
    } catch (e) {
      return Left(
          ServerFailure(message: '게시물 수정 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> searchPosts({
    required String query,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final posts = await remoteDataSource.searchPosts(
        query: query,
        limit: limit,
        lastPostId: lastPostId,
      );
      return Right(posts);
    } catch (e) {
      return Left(
          ServerFailure(message: '게시물 검색 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> searchPostsByHashtag({
    required String hashtag,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final posts = await remoteDataSource.searchPostsByHashtag(
        hashtag: hashtag,
        limit: limit,
        lastPostId: lastPostId,
      );
      return Right(posts);
    } catch (e) {
      return Left(
          ServerFailure(message: '해시태그 검색 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getPopularHashtags({
    int limit = 20,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final hashtags = await remoteDataSource.getPopularHashtags(limit: limit);
      return Right(hashtags);
    } catch (e) {
      return Left(
          ServerFailure(message: '인기 해시태그 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getTrendingHashtags({
    int limit = 10,
    int days = 7,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }

      final hashtags = await remoteDataSource.getTrendingHashtags(
        limit: limit,
        days: days,
      );
      return Right(hashtags);
    } catch (e) {
      return Left(
          ServerFailure(message: '트렌딩 해시태그 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  // ─── Bookmark operations ────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> savePost(String postId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      await remoteDataSource.supabaseClient.from('saved_posts').upsert({
        'post_id': postId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String()
      });
      return const Right(null);
    } catch (e) {
      return const Left(ServerFailure(
          message: '${ErrorMessages.savePostFailed}: \${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unsavePost(String postId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      await remoteDataSource.supabaseClient
          .from('saved_posts')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);
      return const Right(null);
    } catch (e) {
      return const Left(ServerFailure(
          message: '${ErrorMessages.unsavePostFailed}: \${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getSavedPosts(
      {required String userId, int limit = 20}) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final response = await remoteDataSource.supabaseClient
          .from('saved_posts')
          .select('post_id, posts(*, users(display_name, photo_url))')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (response as List)
          .map((item) {
            final postData = item['posts'] as Map<String, dynamic>?;
            if (postData == null) return null;
            return PostModel.fromJson(postData).toEntity();
          })
          .whereType<Post>()
          .toList();
      return Right(posts);
    } catch (e) {
      return const Left(ServerFailure(
          message: '${ErrorMessages.savedPostsLoadFailed}: \${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isPostSaved(
      String postId, String userId) async {
    try {
      final response = await remoteDataSource.supabaseClient
          .from('saved_posts')
          .select('post_id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();
      return Right(response != null);
    } catch (e) {
      return const Right(false);
    }
  }

  // ─── Cover image ────────────────────────────────────────────────────────

  @override
  Future<Either<Failure, String>> uploadCoverImage(
      String userId, File file) async {
    try {
      final url = await remoteDataSource.uploadCoverImage(userId, file);
      return Right(url);
    } catch (e) {
      return Left(ServerFailure(message: e.toString()));
    }
  }

  // ─── Block operations ───────────────────────────────────────────────────

  @override
  Future<Either<Failure, void>> blockUser(
      String blockerId, String blockedId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      await remoteDataSource.supabaseClient.from('user_blocks').upsert({
        'blocker_id': blockerId,
        'blocked_id': blockedId,
        'created_at': DateTime.now().toIso8601String()
      });
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '차단 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unblockUser(
      String blockerId, String blockedId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      await remoteDataSource.supabaseClient
          .from('user_blocks')
          .delete()
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '차단 해제 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isBlocked(
      String blockerId, String blockedId) async {
    try {
      final response = await remoteDataSource.supabaseClient
          .from('user_blocks')
          .select('id')
          .eq('blocker_id', blockerId)
          .eq('blocked_id', blockedId)
          .maybeSingle();
      return Right(response != null);
    } catch (e) {
      return const Right(false);
    }
  }

  // ─── Discovery operations (M-F3) ────────────────────────────────────────

  @override
  Future<Either<Failure, List<Post>>> getRecommendedPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final posts = await remoteDataSource.getRecommendedPosts(userId, limit: limit, offset: offset);
      return Right(posts);
    } catch (e) {
      return Left(ServerFailure(message: '추천 게시물 조회 실패: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getPostsByHashtag({
    required String hashtag,
    String? userId,
    String sort = 'popular',
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final posts = await remoteDataSource.getPostsByHashtag(
        hashtag: hashtag,
        userId: userId,
        sort: sort,
        limit: limit,
        offset: offset,
      );
      return Right(posts);
    } catch (e) {
      return Left(ServerFailure(message: '해시태그 게시물 조회 실패: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getPostsByLocation({
    required double lat,
    required double lng,
    int radiusM = 50,
    String? userId,
    int limit = 20,
    int offset = 0,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final posts = await remoteDataSource.getPostsByLocation(
        lat: lat,
        lng: lng,
        radiusM: radiusM,
        userId: userId,
        limit: limit,
        offset: offset,
      );
      return Right(posts);
    } catch (e) {
      return Left(ServerFailure(message: '위치 게시물 조회 실패: ${e.toString()}'));
    }
  }

  // ─── Bookmark collection operations (M-F3) ──────────────────────────────

  @override
  Future<Either<Failure, List<BookmarkCollection>>> getBookmarkCollections(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final collections = await remoteDataSource.getBookmarkCollections(userId);
      return Right(collections);
    } catch (e) {
      return Left(ServerFailure(message: '북마크 컬렉션 조회 실패: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, BookmarkCollection>> createBookmarkCollection({
    required String userId,
    required String name,
    String emoji = '📁',
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      final collection = await remoteDataSource.createBookmarkCollection(
        userId: userId,
        name: name,
        emoji: emoji,
      );
      return Right(collection);
    } catch (e) {
      return Left(ServerFailure(message: '북마크 컬렉션 생성 실패: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteBookmarkCollection(String collectionId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      await remoteDataSource.deleteBookmarkCollection(collectionId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '북마크 컬렉션 삭제 실패: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> updateSavedPostCollection({
    required String postId,
    required String userId,
    String? collectionId,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: ErrorMessages.networkError));
      }
      await remoteDataSource.updateSavedPostCollection(
        postId: postId,
        userId: userId,
        collectionId: collectionId,
      );
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '북마크 컬렉션 이동 실패: ${e.toString()}'));
    }
  }
}
