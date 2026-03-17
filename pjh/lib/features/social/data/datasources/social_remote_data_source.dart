import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/social_user_model.dart';
import '../models/notification_model.dart';
import '../../domain/entities/comment.dart';
// import '../../domain/entities/follow.dart'; // 현재 사용하지 않음
import '../../domain/entities/notification.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/social_user.dart';

abstract class SocialRemoteDataSource {
  Future<SocialUser> createUser(SocialUser user);
  Future<SocialUser> getUser(String userId);
  Future<SocialUser> updateUser(SocialUser user);
  Future<void> deleteUser(String userId);
  Future<List<SocialUser>> searchUsers(String query, int limit, String? lastUserId);

  Future<Post> createPost(Post post, List<File> images);
  Future<Post> getPost(String postId);
  Future<List<Post>> getUserPosts(String userId, int limit, String? lastPostId);
  Future<List<Post>> getFeedPosts(String userId, int limit, String? lastPostId);
  Future<List<Post>> getExplorePosts(int limit, String? lastPostId);
  Future<Post> updatePost(Post post);
  Future<void> deletePost(String postId);

  Future<void> likePost(String postId, String userId);
  Future<void> unlikePost(String postId, String userId);
  Future<bool> isPostLiked(String postId, String userId);
  Future<List<String>> getPostLikes(String postId, int limit);

  Future<Comment> createComment(Comment comment);
  Future<Comment> getComment(String commentId);
  Future<List<Comment>> getPostComments(String postId, int limit, String? lastCommentId);
  Future<Comment> updateComment(Comment comment);
  Future<void> deleteComment(String commentId);
  Future<void> likeComment(String commentId, String userId);
  Future<void> unlikeComment(String commentId, String userId);

  Future<void> followUser(String followerId, String followingId);
  Future<void> unfollowUser(String followerId, String followingId);
  Future<bool> isFollowing(String followerId, String followingId);
  Future<List<SocialUser>> getFollowers(String userId, int limit, String? lastUserId);
  Future<List<SocialUser>> getFollowing(String userId, int limit, String? lastUserId);

  Future<List<Notification>> getUserNotifications(String userId, int limit, String? lastNotificationId);
  Future<void> markNotificationAsRead(String notificationId);
  Future<void> markAllNotificationsAsRead(String userId);
  Future<void> createNotification(Notification notification);
  Future<void> deleteNotification(String notificationId);

  Future<void> reportPost(String postId, String reporterId, String reason);
  Future<void> reportComment(String commentId, String reporterId, String reason);
  Future<void> reportUser(String reportedUserId, String reporterId, String reason);

  // Search operations
  Future<List<Post>> searchPosts({
    required String query,
    int limit = 20,
    String? lastPostId,
  });
  Future<List<Post>> searchPostsByHashtag({
    required String hashtag,
    int limit = 20,
    String? lastPostId,
  });
  Future<List<String>> getPopularHashtags({int limit = 20});
  Future<List<String>> getTrendingHashtags({int limit = 10, int days = 7});
}

// Supabase 기반 Social 기능 구현 (현재 stub)

part 'social_remote_data_source_user.dart';
part 'social_remote_data_source_post.dart';
part 'social_remote_data_source_comment.dart';
part 'social_remote_data_source_follow.dart';
part 'social_remote_data_source_notification.dart';


class SocialRemoteDataSourceImpl implements SocialRemoteDataSource {
  final SupabaseClient supabaseClient;
  final AppLogger _logger = AppLogger();

  SocialRemoteDataSourceImpl({
    required this.supabaseClient,
  });

  @override
