import 'dart:io';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/utils/app_logger.dart';
import '../models/post_model.dart';
import '../models/comment_model.dart';
import '../models/social_user_model.dart';
import '../models/notification_model.dart';
import '../../domain/entities/bookmark_collection.dart';
import '../../domain/entities/comment.dart';
// import '../../domain/entities/follow.dart'; // 현재 사용하지 않음
import '../../domain/entities/notification.dart';
import '../../domain/entities/post.dart';
import '../../domain/entities/social_user.dart';

part 'social_remote_data_source_impl_user.dart';
part 'social_remote_data_source_impl_post.dart';
part 'social_remote_data_source_impl_like.dart';
part 'social_remote_data_source_impl_comment.dart';
part 'social_remote_data_source_impl_follow.dart';
part 'social_remote_data_source_impl_notification.dart';
part 'social_remote_data_source_impl_search.dart';

abstract class SocialRemoteDataSource {
  SupabaseClient get supabaseClient;
  Future<SocialUser> createUser(SocialUser user);
  Future<SocialUser> getUser(String userId);
  Future<SocialUser> updateUser(SocialUser user);
  Future<void> deleteUser(String userId);
  Future<List<SocialUser>> searchUsers(
      String query, int limit, String? lastUserId);

  Future<Post> createPost(Post post, List<File> images);
  Future<List<String>> uploadPostImages(String userId, String postId, List<File> files);
  Future<void> deletePostImages(String userId, String postId);
  Future<String> uploadCoverImage(String userId, File file);
  Future<Post> getPost(String postId);
  Future<Map<String, dynamic>?> getPostDetail(String postId);
  Future<List<Map<String, dynamic>>> getUserPostsFiltered({
    required String authorId,
    String? petId,
    String? beforeCreatedAt,
    int limit = 30,
  });
  Future<List<Map<String, dynamic>>> getCommunityPosts({
    String? category,
    int limit = 30,
    DateTime? beforeCreatedAt,
  });
  Future<List<Map<String, dynamic>>> getSavedPostsRaw(String userId);
  Future<Set<String>> getEarnedBadgeIds(String userId);
  Future<void> checkAndAwardBadges(String userId);
  Future<List<Map<String, dynamic>>> getPointTransactions(String userId);
  Future<List<Map<String, dynamic>>> getBlockedUsersDetailed(String blockerId);
  Future<int> getUserPoints(String userId);
  Future<bool> hasQuestActivityToday({
    required String userId,
    required String questType,
  });
  Future<void> incrementUserPoints({
    required String userId,
    required int points,
  });
  Future<bool> awardBadgeIfAbsent({
    required String userId,
    required String badgeId,
  });
  Future<int> getUserStreak(String userId);
  Future<Map<String, dynamic>?> getNotificationPreferences(String userId);
  Future<void> upsertNotificationPreference({
    required String userId,
    required String column,
    required bool value,
  });
  Future<List<Post>> getUserPosts(String userId, int limit, String? lastPostId);
  Future<List<Post>> getFeedPosts(String userId, int limit, String? lastPostId, {DateTime? lastCreatedAt, bool followingOnly = false});
  Future<List<Post>> getExplorePosts(int limit, String? lastPostId, {DateTime? lastCreatedAt});
  Future<Post> updatePost(Post post);
  Future<void> deletePost(String postId);

  Future<void> likePost(String postId, String userId);
  Future<void> unlikePost(String postId, String userId);
  Future<bool> isPostLiked(String postId, String userId);
  Future<List<String>> getPostLikes(String postId, int limit);

  Future<Comment> createComment(Comment comment);
  Future<Comment> getComment(String commentId);
  Future<List<Comment>> getPostComments(
      String postId, int limit, String? lastCommentId);
  Future<Comment> updateComment(Comment comment);
  Future<void> deleteComment(String commentId);
  Future<void> likeComment(String commentId, String userId);
  Future<void> unlikeComment(String commentId, String userId);

  Future<void> followUser(String followerId, String followingId);
  Future<void> unfollowUser(String followerId, String followingId);
  Future<bool> isFollowing(String followerId, String followingId);
  Future<List<SocialUser>> getFollowers(
      String userId, int limit, String? lastUserId);
  Future<List<SocialUser>> getFollowing(
      String userId, int limit, String? lastUserId);

  Future<List<Notification>> getUserNotifications(
      String userId, int limit, String? lastNotificationId);
  Future<void> markNotificationAsRead(String notificationId);
  Future<void> markAllNotificationsAsRead(String userId);
  Future<void> createNotification(Notification notification);
  Future<void> deleteNotification(String notificationId);

  Future<void> reportPost(String postId, String reporterId, String reason);
  Future<void> reportComment(
      String commentId, String reporterId, String reason);
  Future<void> reportUser(
      String reportedUserId, String reporterId, String reason);

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

  // Discovery operations (M-F3)
  Future<List<Post>> getRecommendedPosts(String userId, {int limit = 20, int offset = 0});
  Future<List<Post>> getPostsByHashtag({
    required String hashtag,
    String? userId,
    String sort = 'popular',
    int limit = 20,
    int offset = 0,
  });
  Future<List<Post>> getPostsByLocation({
    required double lat,
    required double lng,
    int radiusM = 50,
    String? userId,
    int limit = 20,
    int offset = 0,
  });

  // Bookmark collection operations (M-F3)
  Future<List<BookmarkCollection>> getBookmarkCollections(String userId);
  Future<BookmarkCollection> createBookmarkCollection({
    required String userId,
    required String name,
    String emoji = '📁',
  });
  Future<void> deleteBookmarkCollection(String collectionId);
  Future<void> updateSavedPostCollection({
    required String postId,
    required String userId,
    String? collectionId,
  });
}

class SocialRemoteDataSourceImpl implements SocialRemoteDataSource {
  @override
  final SupabaseClient supabaseClient;
  final AppLogger _logger = AppLogger();

  SocialRemoteDataSourceImpl({required this.supabaseClient});

  // ── User ──────────────────────────────────────────────────────────────────
  @override Future<SocialUser> createUser(SocialUser user) => _createUser(user);
  @override Future<SocialUser> getUser(String userId) => _getUser(userId);
  @override Future<SocialUser> updateUser(SocialUser user) => _updateUser(user);
  @override Future<void> deleteUser(String userId) => _deleteUser(userId);
  @override Future<List<SocialUser>> searchUsers(String query, int limit, String? lastUserId) =>
      _searchUsers(query, limit, lastUserId);

  // ── Post ──────────────────────────────────────────────────────────────────
  @override Future<Post> createPost(Post post, List<File> images) => _createPost(post, images);
  @override Future<List<String>> uploadPostImages(String userId, String postId, List<File> files) =>
      _uploadPostImages(userId, postId, files);
  @override Future<void> deletePostImages(String userId, String postId) =>
      _deletePostImages(userId, postId);
  @override Future<String> uploadCoverImage(String userId, File file) =>
      _uploadCoverImage(userId, file);
  @override Future<Post> getPost(String postId) => _getPost(postId);
  @override Future<Map<String, dynamic>?> getPostDetail(String postId) => _getPostDetail(postId);
  @override Future<List<Map<String, dynamic>>> getUserPostsFiltered({
    required String authorId, String? petId, String? beforeCreatedAt, int limit = 30,
  }) => _getUserPostsFiltered(authorId: authorId, petId: petId, beforeCreatedAt: beforeCreatedAt, limit: limit);
  @override Future<List<Map<String, dynamic>>> getCommunityPosts({String? category, int limit = 30, DateTime? beforeCreatedAt}) =>
      _getCommunityPosts(category: category, limit: limit, beforeCreatedAt: beforeCreatedAt);
  @override Future<List<Map<String, dynamic>>> getSavedPostsRaw(String userId) => _getSavedPostsRaw(userId);
  @override Future<Set<String>> getEarnedBadgeIds(String userId) => _getEarnedBadgeIds(userId);
  @override Future<void> checkAndAwardBadges(String userId) => _checkAndAwardBadges(userId);
  @override Future<List<Map<String, dynamic>>> getPointTransactions(String userId) => _getPointTransactions(userId);
  @override Future<List<Map<String, dynamic>>> getBlockedUsersDetailed(String blockerId) =>
      _getBlockedUsersDetailed(blockerId);
  @override Future<int> getUserPoints(String userId) => _getUserPoints(userId);
  @override Future<bool> hasQuestActivityToday({required String userId, required String questType}) =>
      _hasQuestActivityToday(userId: userId, questType: questType);
  @override Future<void> incrementUserPoints({required String userId, required int points}) =>
      _incrementUserPoints(userId: userId, points: points);
  @override Future<bool> awardBadgeIfAbsent({required String userId, required String badgeId}) =>
      _awardBadgeIfAbsent(userId: userId, badgeId: badgeId);
  @override Future<int> getUserStreak(String userId) => _getUserStreak(userId);
  @override Future<Map<String, dynamic>?> getNotificationPreferences(String userId) =>
      _getNotificationPreferences(userId);
  @override Future<void> upsertNotificationPreference({
    required String userId, required String column, required bool value,
  }) => _upsertNotificationPreference(userId: userId, column: column, value: value);
  @override Future<List<Post>> getUserPosts(String userId, int limit, String? lastPostId) =>
      _getUserPosts(userId, limit, lastPostId);
  @override Future<List<Post>> getFeedPosts(String userId, int limit, String? lastPostId,
      {DateTime? lastCreatedAt, bool followingOnly = false}) =>
      _getFeedPosts(userId, limit, lastPostId, lastCreatedAt: lastCreatedAt, followingOnly: followingOnly);
  @override Future<List<Post>> getExplorePosts(int limit, String? lastPostId, {DateTime? lastCreatedAt}) =>
      _getExplorePosts(limit, lastPostId, lastCreatedAt: lastCreatedAt);
  @override Future<Post> updatePost(Post post) => _updatePost(post);
  @override Future<void> deletePost(String postId) => _deletePost(postId);

  // ── Like ──────────────────────────────────────────────────────────────────
  @override Future<void> likePost(String postId, String userId) => _likePost(postId, userId);
  @override Future<void> unlikePost(String postId, String userId) => _unlikePost(postId, userId);
  @override Future<bool> isPostLiked(String postId, String userId) => _isPostLiked(postId, userId);
  @override Future<List<String>> getPostLikes(String postId, int limit) => _getPostLikes(postId, limit);

  // ── Comment ───────────────────────────────────────────────────────────────
  @override Future<Comment> createComment(Comment comment) => _createComment(comment);
  @override Future<Comment> getComment(String commentId) => _getComment(commentId);
  @override Future<List<Comment>> getPostComments(String postId, int limit, String? lastCommentId) =>
      _getPostComments(postId, limit, lastCommentId);
  @override Future<Comment> updateComment(Comment comment) => _updateComment(comment);
  @override Future<void> deleteComment(String commentId) => _deleteComment(commentId);
  @override Future<void> likeComment(String commentId, String userId) => _likeComment(commentId, userId);
  @override Future<void> unlikeComment(String commentId, String userId) => _unlikeComment(commentId, userId);

  // ── Follow ────────────────────────────────────────────────────────────────
  @override Future<void> followUser(String followerId, String followingId) =>
      _followUser(followerId, followingId);
  @override Future<void> unfollowUser(String followerId, String followingId) =>
      _unfollowUser(followerId, followingId);
  @override Future<bool> isFollowing(String followerId, String followingId) =>
      _isFollowing(followerId, followingId);
  @override Future<List<SocialUser>> getFollowers(String userId, int limit, String? lastUserId) =>
      _getFollowers(userId, limit, lastUserId);
  @override Future<List<SocialUser>> getFollowing(String userId, int limit, String? lastUserId) =>
      _getFollowing(userId, limit, lastUserId);

  // ── Notification / Report ─────────────────────────────────────────────────
  @override Future<List<Notification>> getUserNotifications(String userId, int limit, String? lastNotificationId) =>
      _getUserNotifications(userId, limit, lastNotificationId);
  @override Future<void> markNotificationAsRead(String notificationId) =>
      _markNotificationAsRead(notificationId);
  @override Future<void> markAllNotificationsAsRead(String userId) =>
      _markAllNotificationsAsRead(userId);
  @override Future<void> createNotification(Notification notification) =>
      _createNotification(notification);
  @override Future<void> deleteNotification(String notificationId) =>
      _deleteNotification(notificationId);
  @override Future<void> reportPost(String postId, String reporterId, String reason) =>
      _reportPost(postId, reporterId, reason);
  @override Future<void> reportComment(String commentId, String reporterId, String reason) =>
      _reportComment(commentId, reporterId, reason);
  @override Future<void> reportUser(String reportedUserId, String reporterId, String reason) =>
      _reportUser(reportedUserId, reporterId, reason);

  // ── Search / Discovery / Bookmark ─────────────────────────────────────────
  @override Future<List<Post>> searchPosts({required String query, int limit = 20, String? lastPostId}) =>
      _searchPosts(query: query, limit: limit, lastPostId: lastPostId);
  @override Future<List<Post>> searchPostsByHashtag({required String hashtag, int limit = 20, String? lastPostId}) =>
      _searchPostsByHashtag(hashtag: hashtag, limit: limit, lastPostId: lastPostId);
  @override Future<List<String>> getPopularHashtags({int limit = 20}) => _getPopularHashtags(limit: limit);
  @override Future<List<String>> getTrendingHashtags({int limit = 10, int days = 7}) =>
      _getTrendingHashtags(limit: limit, days: days);
  @override Future<List<Post>> getRecommendedPosts(String userId, {int limit = 20, int offset = 0}) =>
      _getRecommendedPosts(userId, limit: limit, offset: offset);
  @override Future<List<Post>> getPostsByHashtag({
    required String hashtag, String? userId, String sort = 'popular', int limit = 20, int offset = 0,
  }) => _getPostsByHashtag(hashtag: hashtag, userId: userId, sort: sort, limit: limit, offset: offset);
  @override Future<List<Post>> getPostsByLocation({
    required double lat, required double lng, int radiusM = 50,
    String? userId, int limit = 20, int offset = 0,
  }) => _getPostsByLocation(lat: lat, lng: lng, radiusM: radiusM, userId: userId, limit: limit, offset: offset);
  @override Future<List<BookmarkCollection>> getBookmarkCollections(String userId) =>
      _getBookmarkCollections(userId);
  @override Future<BookmarkCollection> createBookmarkCollection({
    required String userId, required String name, String emoji = '📁',
  }) => _createBookmarkCollection(userId: userId, name: name, emoji: emoji);
  @override Future<void> deleteBookmarkCollection(String collectionId) =>
      _deleteBookmarkCollection(collectionId);
  @override Future<void> updateSavedPostCollection({
    required String postId, required String userId, String? collectionId,
  }) => _updateSavedPostCollection(postId: postId, userId: userId, collectionId: collectionId);
}
