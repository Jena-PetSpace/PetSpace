
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/comment.dart';
import '../../domain/entities/follow.dart';
import '../../domain/entities/notification.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/social_user.dart';
import '../../domain/repositories/social_repository.dart';
import '../datasources/social_remote_data_source.dart';

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
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final user = await remoteDataSource.getUser(userId);
      return Right(user);
    } catch (e) {
      return Left(ServerFailure(message: '사용자 정보 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, SocialUser>> updateUserProfile(SocialUser user) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final updatedUser = await remoteDataSource.updateUser(user);
      return Right(updatedUser);
    } catch (e) {
      return Left(ServerFailure(message: '프로필 업데이트 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SocialUser>>> searchUsers(String query, {int limit = 20}) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final users = await remoteDataSource.searchUsers(query, limit, null);
      return Right(users);
    } catch (e) {
      return Left(ServerFailure(message: '사용자 검색 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Post>> createPost(Post post) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final createdPost = await remoteDataSource.createPost(post, []);
      return Right(createdPost);
    } catch (e) {
      return Left(ServerFailure(message: '게시물 작성 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Post>> getPost(String postId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final post = await remoteDataSource.getPost(postId);
      return Right(post);
    } catch (e) {
      return Left(ServerFailure(message: '게시물 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getFeedPosts({
    required String userId,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final posts = await remoteDataSource.getFeedPosts(userId, limit, lastPostId);
      return Right(posts);
    } catch (e) {
      return Left(ServerFailure(message: '피드 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getExplorePosts({
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final posts = await remoteDataSource.getExplorePosts(limit, lastPostId);
      return Right(posts);
    } catch (e) {
      return Left(ServerFailure(message: '탐색 게시물 조회 중 오류가 발생했습니다: ${e.toString()}'));
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
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final posts = await remoteDataSource.getUserPosts(userId, limit, lastPostId);
      return Right(posts);
    } catch (e) {
      return Left(ServerFailure(message: '사용자 게시물 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> likePost(String postId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.likePost(postId, userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '좋아요 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unlikePost(String postId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.unlikePost(postId, userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '좋아요 취소 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePost(String postId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.deletePost(postId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '게시물 삭제 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Comment>> createComment(Comment comment) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final createdComment = await remoteDataSource.createComment(comment);
      return Right(createdComment);
    } catch (e) {
      return Left(ServerFailure(message: '댓글 작성 중 오류가 발생했습니다: ${e.toString()}'));
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
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final comments = await remoteDataSource.getPostComments(postId, limit, lastCommentId);
      return Right(comments);
    } catch (e) {
      return Left(ServerFailure(message: '댓글 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Follow>> followUser(String followerId, String followingId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
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
      return Left(ServerFailure(message: '팔로우 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unfollowUser(String followerId, String followingId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.unfollowUser(followerId, followingId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '팔로우 취소 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }


  @override
  Future<Either<Failure, void>> markNotificationAsRead(String notificationId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.markNotificationAsRead(notificationId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  // 누락된 메서드들 stub 구현
  @override
  Future<Either<Failure, void>> acceptFollowRequest(String followId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      // 팔로우 요청 승인은 현재 스키마에서 지원하지 않음 (자동 승인 구조)
      // 나중에 pending_follows 테이블 추가 시 구현
      return const Left(ServerFailure(message: '팔로우 요청 승인 기능은 아직 지원하지 않습니다'));
    } catch (e) {
      return Left(ServerFailure(message: '팔로우 요청 승인 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> createNotification(Notification notification) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.createNotification(notification);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '알림 생성 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteComment(String commentId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.deleteComment(commentId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '댓글 삭제 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getFeed({String? userId, int limit = 20, String? lastPostId}) async {
    return await getFeedPosts(userId: userId ?? '', limit: limit, lastPostId: lastPostId);
  }

  @override
  Future<Either<Failure, List<Follow>>> getFollowers(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final users = await remoteDataSource.getFollowers(userId, 50, null);
      // SocialUser를 Follow로 변환
      final follows = users.map((user) => Follow(
        id: '${user.id}-$userId',
        followerId: user.id,
        followingId: userId,
        followerName: user.displayName,
        followingName: 'Me',
        status: FollowStatus.accepted,
        createdAt: DateTime.now(),
        acceptedAt: DateTime.now(),
      )).toList();

      return Right(follows);
    } catch (e) {
      return Left(ServerFailure(message: '팔로워 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Follow>>> getFollowing(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final users = await remoteDataSource.getFollowing(userId, 50, null);
      // SocialUser를 Follow로 변환
      final follows = users.map((user) => Follow(
        id: '$userId-${user.id}',
        followerId: userId,
        followingId: user.id,
        followerName: 'Me',
        followingName: user.displayName,
        status: FollowStatus.accepted,
        createdAt: DateTime.now(),
        acceptedAt: DateTime.now(),
      )).toList();

      return Right(follows);
    } catch (e) {
      return Left(ServerFailure(message: '팔로잉 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Notification>>> getNotifications({required String userId, int limit = 20, String? lastNotificationId}) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final notifications = await remoteDataSource.getUserNotifications(userId, limit, lastNotificationId);
      return Right(notifications);
    } catch (e) {
      return Left(ServerFailure(message: '알림 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Notification>>> getUserNotifications({required String userId, int limit = 20, String? lastNotificationId}) async {
    return await getNotifications(userId: userId, limit: limit, lastNotificationId: lastNotificationId);
  }

  @override
  Future<Either<Failure, List<Follow>>> getPendingFollowRequests(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      // 팔로우 요청 대기 기능은 현재 스키마에서 지원하지 않음 (자동 승인 구조)
      // 나중에 pending_follows 테이블 추가 시 구현
      return const Right([]);
    } catch (e) {
      return Left(ServerFailure(message: '팔로우 요청 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<SocialUser>>> getPostLikes(String postId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
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
      return Left(ServerFailure(message: '좋아요 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Post>>> getSharedPosts(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      // 공유된 게시물은 현재 별도 테이블 없이 일반 게시물로 처리됨
      // 추후 shared_posts 테이블 추가하거나 posts 테이블에 shared_from_id 컬럼 추가 필요
      return const Right([]);
    } catch (e) {
      return Left(ServerFailure(message: '공유된 게시물 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, int>> getUnreadNotificationsCount(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      // 안읽은 알림을 가져와서 개수 반환
      final notifications = await remoteDataSource.getUserNotifications(userId, 100, null);
      final unreadCount = notifications.where((n) => !n.isRead).length;
      return Right(unreadCount);
    } catch (e) {
      return Left(ServerFailure(message: '안읽은 알림 개수 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isFollowing(String followerId, String followingId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final isFollowing = await remoteDataSource.isFollowing(followerId, followingId);
      return Right(isFollowing);
    } catch (e) {
      return Left(ServerFailure(message: '팔로우 여부 확인 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> likeComment(String commentId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.likeComment(commentId, userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '댓글 좋아요 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> markAllNotificationsAsRead(String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      // Bulk update로 성능 최적화
      await remoteDataSource.markAllNotificationsAsRead(userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '모든 알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> rejectFollowRequest(String followId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      // 팔로우 요청 거절은 현재 스키마에서 지원하지 않음 (자동 승인 구조)
      // 나중에 pending_follows 테이블 추가 시 구현
      return const Left(ServerFailure(message: '팔로우 요청 거절 기능은 아직 지원하지 않습니다'));
    } catch (e) {
      return Left(ServerFailure(message: '팔로우 요청 거절 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> reportPost(String postId, String userId, String reason) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.reportPost(postId, userId, reason);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '게시물 신고 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> reportUser(String reportedUserId, String reporterId, String reason) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.reportUser(reportedUserId, reporterId, reason);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '사용자 신고 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> sharePost(String postId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
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
        content: '${originalPost.authorName}님의 포스트를 공유했습니다.\n\n${originalPost.content ?? ''}',
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
      return Left(ServerFailure(message: '포스트 공유 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> unlikeComment(String commentId, String userId) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      await remoteDataSource.unlikeComment(commentId, userId);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '댓글 좋아요 취소 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Comment>> updateComment(Comment comment) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final updatedComment = await remoteDataSource.updateComment(comment);
      return Right(updatedComment);
    } catch (e) {
      return Left(ServerFailure(message: '댓글 수정 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Post>> updatePost(Post post) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final updatedPost = await remoteDataSource.updatePost(post);
      return Right(updatedPost);
    } catch (e) {
      return Left(ServerFailure(message: '게시물 수정 중 오류가 발생했습니다: ${e.toString()}'));
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
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final posts = await remoteDataSource.searchPosts(
        query: query,
        limit: limit,
        lastPostId: lastPostId,
      );
      return Right(posts);
    } catch (e) {
      return Left(ServerFailure(message: '게시물 검색 중 오류가 발생했습니다: ${e.toString()}'));
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
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final posts = await remoteDataSource.searchPostsByHashtag(
        hashtag: hashtag,
        limit: limit,
        lastPostId: lastPostId,
      );
      return Right(posts);
    } catch (e) {
      return Left(ServerFailure(message: '해시태그 검색 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getPopularHashtags({
    int limit = 20,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final hashtags = await remoteDataSource.getPopularHashtags(limit: limit);
      return Right(hashtags);
    } catch (e) {
      return Left(ServerFailure(message: '인기 해시태그 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<String>>> getTrendingHashtags({
    int limit = 10,
    int days = 7,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }

      final hashtags = await remoteDataSource.getTrendingHashtags(
        limit: limit,
        days: days,
      );
      return Right(hashtags);
    } catch (e) {
      return Left(ServerFailure(message: '트렌딩 해시태그 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }
}