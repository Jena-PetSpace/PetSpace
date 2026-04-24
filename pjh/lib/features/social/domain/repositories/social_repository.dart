import 'dart:io';

import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/social_user.dart';
import '../entities/post.dart';
import '../entities/comment.dart';
import '../entities/follow.dart';
import '../entities/notification.dart';
import '../entities/bookmark_collection.dart';

abstract class SocialRepository {
  // User operations
  Future<Either<Failure, SocialUser>> getUserProfile(String userId);
  Future<Either<Failure, SocialUser>> updateUserProfile(SocialUser user);
  Future<Either<Failure, List<SocialUser>>> searchUsers(String query);

  // Post operations
  Future<Either<Failure, Post>> createPost(Post post, {List<File> images = const []});
  Future<Either<Failure, Post>> updatePost(Post post);
  Future<Either<Failure, void>> deletePost(String postId);
  Future<Either<Failure, List<Post>>> getFeed({
    String? userId,
    int limit = 20,
    String? lastPostId,
    DateTime? lastCreatedAt,
    bool followingOnly = false,
  });
  Future<Either<Failure, List<Post>>> getFeedPosts({
    required String userId,
    int limit = 20,
    String? lastPostId,
    DateTime? lastCreatedAt,
    bool followingOnly = false,
  });
  Future<Either<Failure, List<Post>>> getExplorePosts({
    int limit = 20,
    String? lastPostId,
    DateTime? lastCreatedAt,
  });
  Future<Either<Failure, List<Post>>> getUserPosts({
    required String userId,
    int limit = 20,
    String? lastPostId,
  });
  Future<Either<Failure, Post>> getPost(String postId);

  /// 상세 페이지용 원본 JSON (users JOIN 포함). Post entity가 petId/petName 등을
  /// 아직 포함하지 않아 상세 렌더링 호환성을 위해 노출. Post 엔티티 확장 후 제거 예정.
  Future<Either<Failure, Map<String, dynamic>?>> getPostDetail(String postId);

  /// 프로필 게시물 그리드용 raw query (petId 필터 + 무한 스크롤).
  /// Post entity 확장 전까지 map 기반 렌더링 호환용.
  Future<Either<Failure, List<Map<String, dynamic>>>> getUserPostsFiltered({
    required String authorId,
    String? petId,
    String? beforeCreatedAt,
    int limit = 30,
  });

  // Like operations
  Future<Either<Failure, void>> likePost(String postId, String userId);
  Future<Either<Failure, void>> unlikePost(String postId, String userId);
  Future<Either<Failure, bool>> isPostLiked(String postId, String userId);
  Future<Either<Failure, List<SocialUser>>> getPostLikes(String postId);

  // Comment operations
  Future<Either<Failure, Comment>> createComment(Comment comment);
  Future<Either<Failure, Comment>> updateComment(Comment comment);
  Future<Either<Failure, void>> deleteComment(String commentId);
  Future<Either<Failure, List<Comment>>> getPostComments({
    required String postId,
    int limit = 20,
    String? lastCommentId,
  });
  Future<Either<Failure, void>> likeComment(String commentId, String userId);
  Future<Either<Failure, void>> unlikeComment(String commentId, String userId);

  // Follow operations
  Future<Either<Failure, Follow>> followUser(
      String followerId, String followingId);
  Future<Either<Failure, void>> unfollowUser(
      String followerId, String followingId);
  Future<Either<Failure, void>> acceptFollowRequest(String followId);
  Future<Either<Failure, void>> rejectFollowRequest(String followId);
  Future<Either<Failure, List<Follow>>> getFollowers(String userId);
  Future<Either<Failure, List<Follow>>> getFollowing(String userId);
  Future<Either<Failure, List<Follow>>> getPendingFollowRequests(String userId);
  Future<Either<Failure, bool>> isFollowing(
      String followerId, String followingId);

  // Notification operations
  Future<Either<Failure, List<Notification>>> getNotifications({
    required String userId,
    int limit = 20,
    String? lastNotificationId,
  });
  Future<Either<Failure, List<Notification>>> getUserNotifications({
    required String userId,
    int limit = 20,
    String? lastNotificationId,
  });
  Future<Either<Failure, void>> markNotificationAsRead(String notificationId);
  Future<Either<Failure, void>> markAllNotificationsAsRead(String userId);
  Future<Either<Failure, int>> getUnreadNotificationsCount(String userId);
  Future<Either<Failure, void>> createNotification(Notification notification);

  // Share operations
  Future<Either<Failure, void>> sharePost(String postId, String userId);
  Future<Either<Failure, List<Post>>> getSharedPosts(String userId);

  // Bookmark operations
  Future<Either<Failure, void>> savePost(String postId, String userId);
  Future<Either<Failure, void>> unsavePost(String postId, String userId);
  Future<Either<Failure, List<Post>>> getSavedPosts(
      {required String userId, int limit = 20});
  Future<Either<Failure, bool>> isPostSaved(String postId, String userId);

  /// 유저 연속 활동 일수 조회 (RPC get_user_streak).
  /// RPC 미구현 상태면 0 반환 — 퀘스트 시스템 연동 후 활성화 예정.
  Future<Either<Failure, int>> getUserStreak(String userId);

  /// 알림 설정 전체 조회 (notification_preferences 테이블)
  Future<Either<Failure, Map<String, dynamic>?>> getNotificationPreferences(
      String userId);

  /// 알림 설정 단일 컬럼 upsert.
  /// 예: serverColumn='enabled_like', value=false
  Future<Either<Failure, void>> upsertNotificationPreference({
    required String userId,
    required String column,
    required bool value,
  });

  // Bookmark collection operations
  Future<Either<Failure, List<BookmarkCollection>>> getBookmarkCollections(String userId);
  Future<Either<Failure, BookmarkCollection>> createBookmarkCollection({
    required String userId,
    required String name,
    String emoji = '📁',
  });
  Future<Either<Failure, void>> deleteBookmarkCollection(String collectionId);
  Future<Either<Failure, void>> updateSavedPostCollection({
    required String postId,
    required String userId,
    String? collectionId,
  });

  // Discovery operations
  Future<Either<Failure, List<Post>>> getRecommendedPosts({
    required String userId,
    int limit = 20,
    int offset = 0,
  });
  Future<Either<Failure, List<Post>>> getPostsByHashtag({
    required String hashtag,
    String? userId,
    String sort = 'popular',
    int limit = 20,
    int offset = 0,
  });
  Future<Either<Failure, List<Post>>> getPostsByLocation({
    required double lat,
    required double lng,
    int radiusM = 50,
    String? userId,
    int limit = 20,
    int offset = 0,
  });

  // Cover image
  Future<Either<Failure, String>> uploadCoverImage(
      String userId, File file);

  // Block operations
  Future<Either<Failure, void>> blockUser(String blockerId, String blockedId);
  Future<Either<Failure, void>> unblockUser(String blockerId, String blockedId);
  Future<Either<Failure, bool>> isBlocked(String blockerId, String blockedId);

  // Report operations
  Future<Either<Failure, void>> reportPost(
      String postId, String userId, String reason);
  Future<Either<Failure, void>> reportUser(
      String reportedUserId, String reporterId, String reason);

  // Search operations
  Future<Either<Failure, List<Post>>> searchPosts({
    required String query,
    int limit = 20,
    String? lastPostId,
  });
  Future<Either<Failure, List<Post>>> searchPostsByHashtag({
    required String hashtag,
    int limit = 20,
    String? lastPostId,
  });
  Future<Either<Failure, List<String>>> getPopularHashtags({
    int limit = 20,
  });
  Future<Either<Failure, List<String>>> getTrendingHashtags({
    int limit = 10,
    int days = 7,
  });
}
