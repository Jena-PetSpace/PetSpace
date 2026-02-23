import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/social_user.dart';
import '../entities/post.dart';
import '../entities/comment.dart';
import '../entities/follow.dart';
import '../entities/notification.dart';

abstract class SocialRepository {
  // User operations
  Future<Either<Failure, SocialUser>> getUserProfile(String userId);
  Future<Either<Failure, SocialUser>> updateUserProfile(SocialUser user);
  Future<Either<Failure, List<SocialUser>>> searchUsers(String query);

  // Post operations
  Future<Either<Failure, Post>> createPost(Post post);
  Future<Either<Failure, Post>> updatePost(Post post);
  Future<Either<Failure, void>> deletePost(String postId);
  Future<Either<Failure, List<Post>>> getFeed({
    String? userId,
    int limit = 20,
    String? lastPostId,
  });
  Future<Either<Failure, List<Post>>> getFeedPosts({
    required String userId,
    int limit = 20,
    String? lastPostId,
  });
  Future<Either<Failure, List<Post>>> getExplorePosts({
    int limit = 20,
    String? lastPostId,
  });
  Future<Either<Failure, List<Post>>> getUserPosts({
    required String userId,
    int limit = 20,
    String? lastPostId,
  });
  Future<Either<Failure, Post>> getPost(String postId);

  // Like operations
  Future<Either<Failure, void>> likePost(String postId, String userId);
  Future<Either<Failure, void>> unlikePost(String postId, String userId);
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
  Future<Either<Failure, Follow>> followUser(String followerId, String followingId);
  Future<Either<Failure, void>> unfollowUser(String followerId, String followingId);
  Future<Either<Failure, void>> acceptFollowRequest(String followId);
  Future<Either<Failure, void>> rejectFollowRequest(String followId);
  Future<Either<Failure, List<Follow>>> getFollowers(String userId);
  Future<Either<Failure, List<Follow>>> getFollowing(String userId);
  Future<Either<Failure, List<Follow>>> getPendingFollowRequests(String userId);
  Future<Either<Failure, bool>> isFollowing(String followerId, String followingId);

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

  // Report operations
  Future<Either<Failure, void>> reportPost(String postId, String userId, String reason);
  Future<Either<Failure, void>> reportUser(String reportedUserId, String reporterId, String reason);

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