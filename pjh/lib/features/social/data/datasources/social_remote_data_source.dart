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
class SocialRemoteDataSourceImpl implements SocialRemoteDataSource {
  final SupabaseClient supabaseClient;
  final AppLogger _logger = AppLogger();

  SocialRemoteDataSourceImpl({
    required this.supabaseClient,
  });

  @override
  Future<SocialUser> createUser(SocialUser user) async {
    try {
      _logger.debug('Creating user: ${user.id}', tag: 'SocialDataSource');

      final userModel = SocialUserModel.fromEntity(user);

      final response = await supabaseClient
          .from('users')
          .insert({
            'id': userModel.id,
            'display_name': userModel.displayName,
            'email': userModel.email,
            'username': userModel.username,
            'photo_url': userModel.profileImageUrl,
            'bio': userModel.bio,
            'created_at': userModel.createdAt.toIso8601String(),
            'updated_at': userModel.updatedAt.toIso8601String(),
          })
          .select()
          .single();

      final createdUser = SocialUserModel(
        id: response['id'] ?? '',
        displayName: response['display_name'] ?? '',
        email: response['email'] ?? '',
        username: response['username'],
        profileImageUrl: response['photo_url'],
        bio: response['bio'],
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'])
            : DateTime.now(),
        updatedAt: response['updated_at'] != null
            ? DateTime.parse(response['updated_at'])
            : DateTime.now(),
      ).toEntity();

      _logger.debug('Successfully created user: ${createdUser.displayName}', tag: 'SocialDataSource');
      return createdUser;
    } catch (e, stackTrace) {
      _logger.error('Failed to create user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 생성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<SocialUser> getUser(String userId) async {
    try {
      _logger.debug('Getting user: $userId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('users')
          .select('*')
          .eq('id', userId)
          .single();

      final user = SocialUserModel(
        id: response['id'] ?? '',
        displayName: response['display_name'] ?? '',
        email: response['email'] ?? '',
        username: response['username'],
        profileImageUrl: response['photo_url'],
        bio: response['bio'],
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'])
            : DateTime.now(),
        updatedAt: response['updated_at'] != null
            ? DateTime.parse(response['updated_at'])
            : DateTime.now(),
      ).toEntity();

      _logger.debug('Successfully fetched user: ${user.displayName}', tag: 'SocialDataSource');
      return user;
    } catch (e, stackTrace) {
      _logger.error('Failed to get user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 정보를 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<SocialUser> updateUser(SocialUser user) async {
    try {
      _logger.debug('Updating user: ${user.id}', tag: 'SocialDataSource');

      final userModel = SocialUserModel.fromEntity(user);

      final response = await supabaseClient
          .from('users')
          .update({
            'display_name': userModel.displayName,
            'username': userModel.username,
            'photo_url': userModel.profileImageUrl,
            'bio': userModel.bio,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', user.id)
          .select()
          .single();

      final updatedUser = SocialUserModel(
        id: response['id'] ?? '',
        displayName: response['display_name'] ?? '',
        email: response['email'] ?? '',
        username: response['username'],
        profileImageUrl: response['photo_url'],
        bio: response['bio'],
        createdAt: response['created_at'] != null
            ? DateTime.parse(response['created_at'])
            : DateTime.now(),
        updatedAt: response['updated_at'] != null
            ? DateTime.parse(response['updated_at'])
            : DateTime.now(),
      ).toEntity();

      _logger.debug('Successfully updated user: ${updatedUser.displayName}', tag: 'SocialDataSource');
      return updatedUser;
    } catch (e, stackTrace) {
      _logger.error('Failed to update user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 정보 업데이트 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteUser(String userId) async {
    try {
      _logger.debug('Deleting user: $userId', tag: 'SocialDataSource');

      await supabaseClient
          .from('users')
          .delete()
          .eq('id', userId);

      _logger.debug('Successfully deleted user: $userId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<SocialUser>> searchUsers(String query, int limit, String? lastUserId) async {
    try {
      _logger.debug('Searching users: $query', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('users')
          .select('*')
          .or('display_name.ilike.%$query%,username.ilike.%$query%')
          .order('created_at', ascending: false)
          .limit(limit);

      final users = (response as List).map((json) {
        return SocialUserModel(
          id: json['id'] ?? '',
          displayName: json['display_name'] ?? '',
          email: json['email'] ?? '',
          username: json['username'],
          profileImageUrl: json['photo_url'],
          bio: json['bio'],
          createdAt: json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
          updatedAt: json['updated_at'] != null
              ? DateTime.parse(json['updated_at'])
              : DateTime.now(),
        ).toEntity();
      }).toList();

      _logger.debug('Found ${users.length} users matching "$query"', tag: 'SocialDataSource');
      return users;
    } catch (e, stackTrace) {
      _logger.error('Failed to search users', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 검색 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<Post> createPost(Post post, List<File> images) async {
    try {
      _logger.debug('Creating post: ${post.id}', tag: 'SocialDataSource');

      // Post 엔티티를 PostModel로 변환
      final postModel = PostModel.fromEntity(post);

      // Supabase에 게시글 생성
      final response = await supabaseClient
          .from('posts')
          .insert(postModel.toJson())
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .single();

      _logger.debug('Post created successfully: ${response['id']}', tag: 'SocialDataSource');

      // 응답을 PostModel로 변환 후 Entity로 변환
      final createdPostModel = PostModel.fromJson(response);
      return createdPostModel.toEntity();
    } catch (e, stackTrace) {
      _logger.error('Failed to create post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 작성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<Post> getPost(String postId) async {
    try {
      _logger.debug('Getting post: $postId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .eq('id', postId)
          .single();

      final post = PostModel.fromJson(response).toEntity();

      _logger.debug('Successfully fetched post: $postId', tag: 'SocialDataSource');
      return post;
    } catch (e, stackTrace) {
      _logger.error('Failed to get post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Post>> getUserPosts(String userId, int limit, String? lastPostId) async {
    try {
      _logger.debug('Getting user posts: $userId', tag: 'SocialDataSource');

      var query = supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .eq('author_id', userId);

      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();

        query = query.lt('created_at', lastPost['created_at']);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      _logger.debug('Found ${posts.length} posts for user', tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to get user posts', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 게시물을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Post>> getFeedPosts(String userId, int limit, String? lastPostId) async {
    try {
      _logger.debug('Getting feed posts for user: $userId', tag: 'SocialDataSource');

      // Supabase에서 게시글 목록 가져오기 (users 테이블 JOIN)
      final response = await supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .order('created_at', ascending: false)
          .limit(limit);

      _logger.debug('Fetched ${response.length} feed posts', tag: 'SocialDataSource');

      // 응답을 PostModel 리스트로 변환 후 Entity 리스트로 변환
      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch feed posts', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('피드를 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Post>> getExplorePosts(int limit, String? lastPostId) async {
    try {
      _logger.debug('Getting explore posts', tag: 'SocialDataSource');

      var query = supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''');

      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();

        query = query.lt('created_at', lastPost['created_at']);
      }

      final response = await query
          .order('likes_count', ascending: false)
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      _logger.debug('Found ${posts.length} explore posts', tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to get explore posts', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('탐색 게시물을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<Post> updatePost(Post post) async {
    try {
      _logger.debug('Updating post: ${post.id}', tag: 'SocialDataSource');

      final postModel = PostModel.fromEntity(post);

      final response = await supabaseClient
          .from('posts')
          .update({
            'caption': postModel.caption,
            'hashtags': postModel.hashtags,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', post.id)
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .single();

      final updatedPost = PostModel.fromJson(response).toEntity();

      _logger.debug('Successfully updated post: ${post.id}', tag: 'SocialDataSource');
      return updatedPost;
    } catch (e, stackTrace) {
      _logger.error('Failed to update post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 수정 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> deletePost(String postId) async {
    try {
      _logger.debug('Deleting post: $postId', tag: 'SocialDataSource');

      // Supabase에서 게시글 삭제
      await supabaseClient
          .from('posts')
          .delete()
          .eq('id', postId);

      _logger.debug('Post deleted successfully: $postId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> likePost(String postId, String userId) async {
    try {
      _logger.debug('Liking post: $postId by $userId', tag: 'SocialDataSource');

      // likes 테이블에 좋아요 추가
      await supabaseClient.from('likes').insert({
        'post_id': postId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      // posts 테이블의 likes_count 증가
      await supabaseClient.rpc('increment_post_likes', params: {'post_id': postId});

      _logger.debug('Successfully liked post: $postId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to like post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('좋아요 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> unlikePost(String postId, String userId) async {
    try {
      _logger.debug('Unliking post: $postId by $userId', tag: 'SocialDataSource');

      // likes 테이블에서 좋아요 제거
      await supabaseClient
          .from('likes')
          .delete()
          .eq('post_id', postId)
          .eq('user_id', userId);

      // posts 테이블의 likes_count 감소
      await supabaseClient.rpc('decrement_post_likes', params: {'post_id': postId});

      _logger.debug('Successfully unliked post: $postId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to unlike post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('좋아요 취소 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<bool> isPostLiked(String postId, String userId) async {
    try {
      _logger.debug('Checking if post liked: $postId by $userId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('likes')
          .select('id')
          .eq('post_id', postId)
          .eq('user_id', userId)
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      _logger.error('Failed to check like status', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      return false;
    }
  }

  @override
  Future<List<String>> getPostLikes(String postId, int limit) async {
    try {
      _logger.debug('Getting post likes: $postId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('likes')
          .select('user_id')
          .eq('post_id', postId)
          .order('created_at', ascending: false)
          .limit(limit);

      final userIds = (response as List)
          .map((json) => json['user_id'] as String)
          .toList();

      _logger.debug('Found ${userIds.length} likes', tag: 'SocialDataSource');
      return userIds;
    } catch (e, stackTrace) {
      _logger.error('Failed to get post likes', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('좋아요 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<Comment> createComment(Comment comment) async {
    try {
      _logger.debug('Creating comment: ${comment.id}', tag: 'SocialDataSource');

      // CommentModel로 변환
      final commentModel = CommentModel.fromEntity(comment);

      // Supabase에 댓글 생성
      final response = await supabaseClient
          .from('comments')
          .insert({
            'id': commentModel.id,
            'post_id': commentModel.postId,
            'author_id': commentModel.authorId,
            'content': commentModel.content,
            'created_at': commentModel.createdAt.toIso8601String(),
          })
          .select('''
            *,
            users!comments_author_id_fkey(id, display_name, photo_url)
          ''')
          .single();

      _logger.debug('Comment created successfully: ${response['id']}', tag: 'SocialDataSource');

      // 응답을 CommentModel로 변환
      final createdComment = CommentModel.fromJson({
        ...response,
        'author_name': response['users']['display_name'],
        'author_profile_image': response['users']['photo_url'],
      });

      return createdComment.toEntity();
    } catch (e, stackTrace) {
      _logger.error('Failed to create comment', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 작성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<Comment> getComment(String commentId) async {
    try {
      _logger.debug('Getting comment: $commentId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('comments')
          .select('''
            *,
            users!comments_author_id_fkey(id, display_name, photo_url)
          ''')
          .eq('id', commentId)
          .single();

      final comment = CommentModel.fromJson({
        ...response,
        'author_name': response['users']['display_name'],
        'author_profile_image': response['users']['photo_url'],
      });

      return comment.toEntity();
    } catch (e, stackTrace) {
      _logger.error('Failed to get comment', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Comment>> getPostComments(String postId, int limit, String? lastCommentId) async {
    try {
      _logger.debug('Getting post comments: $postId', tag: 'SocialDataSource');

      var queryBuilder = supabaseClient
          .from('comments')
          .select('''
            *,
            users!comments_author_id_fkey(id, display_name, photo_url)
          ''')
          .eq('post_id', postId);

      if (lastCommentId != null) {
        // 페이지네이션 구현
        final lastComment = await supabaseClient
            .from('comments')
            .select('created_at')
            .eq('id', lastCommentId)
            .single();

        queryBuilder = queryBuilder.lt('created_at', lastComment['created_at']);
      }

      final response = await queryBuilder
          .order('created_at', ascending: false)
          .limit(limit);

      _logger.debug('Fetched ${response.length} comments', tag: 'SocialDataSource');

      final comments = (response as List)
          .map((json) => CommentModel.fromJson({
                ...json,
                'author_name': json['users']['display_name'],
                'author_profile_image': json['users']['photo_url'],
              }).toEntity())
          .toList();

      return comments;
    } catch (e, stackTrace) {
      _logger.error('Failed to fetch comments', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<Comment> updateComment(Comment comment) async {
    try {
      _logger.debug('Updating comment: ${comment.id}', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('comments')
          .update({
            'content': comment.content,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', comment.id)
          .select('''
            *,
            users!comments_author_id_fkey(id, display_name, photo_url)
          ''')
          .single();

      final updatedComment = CommentModel.fromJson({
        ...response,
        'author_name': response['users']['display_name'],
        'author_profile_image': response['users']['photo_url'],
      });

      return updatedComment.toEntity();
    } catch (e, stackTrace) {
      _logger.error('Failed to update comment', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 수정 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteComment(String commentId) async {
    try {
      _logger.debug('Deleting comment: $commentId', tag: 'SocialDataSource');

      await supabaseClient
          .from('comments')
          .delete()
          .eq('id', commentId);

      _logger.debug('Comment deleted successfully: $commentId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete comment', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> likeComment(String commentId, String userId) async {
    try {
      _logger.debug('Liking comment: $commentId by $userId', tag: 'SocialDataSource');

      // comment_likes 테이블에 좋아요 추가
      await supabaseClient.from('comment_likes').insert({
        'comment_id': commentId,
        'user_id': userId,
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Successfully liked comment: $commentId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to like comment', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      // 이미 좋아요한 경우 에러를 무시
      if (!e.toString().contains('duplicate')) {
        throw Exception('댓글 좋아요 중 오류가 발생했습니다: ${e.toString()}');
      }
    }
  }

  @override
  Future<void> unlikeComment(String commentId, String userId) async {
    try {
      _logger.debug('Unliking comment: $commentId by $userId', tag: 'SocialDataSource');

      // comment_likes 테이블에서 좋아요 제거
      await supabaseClient
          .from('comment_likes')
          .delete()
          .eq('comment_id', commentId)
          .eq('user_id', userId);

      _logger.debug('Successfully unliked comment: $commentId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to unlike comment', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 좋아요 취소 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> followUser(String followerId, String followingId) async {
    try {
      _logger.debug('Following user: $followerId following $followingId', tag: 'SocialDataSource');

      // follows 테이블에 관계 추가
      await supabaseClient.from('follows').insert({
        'follower_id': followerId,
        'following_id': followingId,
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Successfully followed user: $followingId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to follow user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('팔로우 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> unfollowUser(String followerId, String followingId) async {
    try {
      _logger.debug('Unfollowing user: $followerId unfollowing $followingId', tag: 'SocialDataSource');

      // follows 테이블에서 관계 제거
      await supabaseClient
          .from('follows')
          .delete()
          .eq('follower_id', followerId)
          .eq('following_id', followingId);

      _logger.debug('Successfully unfollowed user: $followingId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to unfollow user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('언팔로우 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<bool> isFollowing(String followerId, String followingId) async {
    try {
      _logger.debug('Checking if following: $followerId following $followingId', tag: 'SocialDataSource');

      final response = await supabaseClient
          .from('follows')
          .select('id')
          .eq('follower_id', followerId)
          .eq('following_id', followingId)
          .maybeSingle();

      return response != null;
    } catch (e, stackTrace) {
      _logger.error('Failed to check following status', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      return false;
    }
  }

  @override
  Future<List<SocialUser>> getFollowers(String userId, int limit, String? lastUserId) async {
    try {
      _logger.debug('Getting followers for user: $userId', tag: 'SocialDataSource');

      var queryBuilder = supabaseClient
          .from('follows')
          .select('''
            follower_id,
            users!follows_follower_id_fkey(
              id,
              display_name,
              email,
              username,
              photo_url,
              bio,
              created_at,
              updated_at
            )
          ''')
          .eq('following_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final response = await queryBuilder;

      final followers = (response as List).map((json) {
        final userData = json['users'];
        return SocialUserModel(
          id: userData['id'] ?? '',
          displayName: userData['display_name'] ?? '',
          email: userData['email'] ?? '',
          username: userData['username'],
          profileImageUrl: userData['photo_url'],
          bio: userData['bio'],
          createdAt: userData['created_at'] != null
              ? DateTime.parse(userData['created_at'])
              : DateTime.now(),
          updatedAt: userData['updated_at'] != null
              ? DateTime.parse(userData['updated_at'])
              : DateTime.now(),
        ).toEntity();
      }).toList();

      _logger.debug('Found ${followers.length} followers', tag: 'SocialDataSource');
      return followers;
    } catch (e, stackTrace) {
      _logger.error('Failed to get followers', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('팔로워 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<SocialUser>> getFollowing(String userId, int limit, String? lastUserId) async {
    try {
      _logger.debug('Getting following for user: $userId', tag: 'SocialDataSource');

      var queryBuilder = supabaseClient
          .from('follows')
          .select('''
            following_id,
            users!follows_following_id_fkey(
              id,
              display_name,
              email,
              username,
              photo_url,
              bio,
              created_at,
              updated_at
            )
          ''')
          .eq('follower_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);

      final response = await queryBuilder;

      final following = (response as List).map((json) {
        final userData = json['users'];
        return SocialUserModel(
          id: userData['id'] ?? '',
          displayName: userData['display_name'] ?? '',
          email: userData['email'] ?? '',
          username: userData['username'],
          profileImageUrl: userData['photo_url'],
          bio: userData['bio'],
          createdAt: userData['created_at'] != null
              ? DateTime.parse(userData['created_at'])
              : DateTime.now(),
          updatedAt: userData['updated_at'] != null
              ? DateTime.parse(userData['updated_at'])
              : DateTime.now(),
        ).toEntity();
      }).toList();

      _logger.debug('Found ${following.length} following', tag: 'SocialDataSource');
      return following;
    } catch (e, stackTrace) {
      _logger.error('Failed to get following', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('팔로잉 목록을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Notification>> getUserNotifications(String userId, int limit, String? lastNotificationId) async {
    try {
      _logger.debug('Getting user notifications: $userId', tag: 'SocialDataSource');

      var query = supabaseClient
          .from('notifications')
          .select('*')
          .eq('user_id', userId);

      if (lastNotificationId != null) {
        // 페이지네이션 구현
        final lastNotification = await supabaseClient
            .from('notifications')
            .select('created_at')
            .eq('id', lastNotificationId)
            .single();

        query = query.lt('created_at', lastNotification['created_at']);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(limit);

      final notifications = (response as List).map((json) {
        return NotificationModel(
          id: json['id'] ?? '',
          userId: json['user_id'] ?? '',
          senderId: json['sender_id'] ?? '',
          senderName: json['sender_name'] ?? '',
          senderProfileImage: json['sender_profile_image'],
          type: NotificationType.values.firstWhere(
            (e) => e.toString() == 'NotificationType.${json['type']}',
            orElse: () => NotificationType.like,
          ),
          title: json['title'] ?? '',
          body: json['body'] ?? '',
          isRead: json['is_read'] ?? false,
          createdAt: json['created_at'] != null
              ? DateTime.parse(json['created_at'])
              : DateTime.now(),
          postId: json['post_id'],
          commentId: json['comment_id'],
          data: Map<String, dynamic>.from(json['data'] ?? {}),
        ).toEntity();
      }).toList();

      _logger.debug('Found ${notifications.length} notifications', tag: 'SocialDataSource');
      return notifications;
    } catch (e, stackTrace) {
      _logger.error('Failed to get notifications', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림을 불러오는 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> markNotificationAsRead(String notificationId) async {
    try {
      _logger.debug('Marking notification as read: $notificationId', tag: 'SocialDataSource');

      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('id', notificationId);

      _logger.debug('Successfully marked notification as read: $notificationId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to mark notification as read', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> markAllNotificationsAsRead(String userId) async {
    try {
      _logger.debug('Marking all notifications as read for user: $userId', tag: 'SocialDataSource');

      // Bulk update - 모든 안 읽은 알림을 한 번의 쿼리로 업데이트
      await supabaseClient
          .from('notifications')
          .update({'is_read': true})
          .eq('user_id', userId)
          .eq('is_read', false);

      _logger.debug('Successfully marked all notifications as read for user: $userId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to mark all notifications as read', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('모든 알림 읽음 처리 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> createNotification(Notification notification) async {
    try {
      _logger.debug('Creating notification: ${notification.id}', tag: 'SocialDataSource');

      final notificationModel = NotificationModel.fromEntity(notification);

      await supabaseClient.from('notifications').insert({
        'id': notificationModel.id,
        'user_id': notificationModel.userId,
        'sender_id': notificationModel.senderId,
        'sender_name': notificationModel.senderName,
        'sender_profile_image': notificationModel.senderProfileImage,
        'type': notificationModel.type.toString().split('.').last,
        'title': notificationModel.title,
        'body': notificationModel.body,
        'is_read': notificationModel.isRead,
        'created_at': notificationModel.createdAt.toIso8601String(),
        'post_id': notificationModel.postId,
        'comment_id': notificationModel.commentId,
        'data': notificationModel.data,
      });

      _logger.debug('Successfully created notification: ${notification.id}', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to create notification', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림 생성 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> deleteNotification(String notificationId) async {
    try {
      _logger.debug('Deleting notification: $notificationId', tag: 'SocialDataSource');

      await supabaseClient
          .from('notifications')
          .delete()
          .eq('id', notificationId);

      _logger.debug('Successfully deleted notification: $notificationId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to delete notification', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('알림 삭제 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> reportPost(String postId, String reporterId, String reason) async {
    try {
      _logger.debug('Reporting post: $postId by $reporterId', tag: 'SocialDataSource');

      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_post_id': postId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Successfully reported post: $postId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to report post', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> reportComment(String commentId, String reporterId, String reason) async {
    try {
      _logger.debug('Reporting comment: $commentId by $reporterId', tag: 'SocialDataSource');

      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_comment_id': commentId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Successfully reported comment: $commentId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to report comment', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('댓글 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<void> reportUser(String reportedUserId, String reporterId, String reason) async {
    try {
      _logger.debug('Reporting user: $reportedUserId by $reporterId', tag: 'SocialDataSource');

      await supabaseClient.from('reports').insert({
        'reporter_id': reporterId,
        'reported_user_id': reportedUserId,
        'reason': reason,
        'status': 'pending',
        'created_at': DateTime.now().toIso8601String(),
      });

      _logger.debug('Successfully reported user: $reportedUserId', tag: 'SocialDataSource');
    } catch (e, stackTrace) {
      _logger.error('Failed to report user', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('사용자 신고 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  // Search operations
  @override
  Future<List<Post>> searchPosts({
    required String query,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      _logger.debug('Searching posts with query: $query, limit: $limit', tag: 'SocialDataSource');

      var baseQuery = supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .or('caption.ilike.%$query%,hashtags.cs.{$query}');

      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();
        baseQuery = baseQuery.filter('created_at', 'lt', lastPost['created_at']);
      }

      final response = await baseQuery
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      _logger.debug('Found ${posts.length} posts', tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to search posts', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('게시물 검색 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<Post>> searchPostsByHashtag({
    required String hashtag,
    int limit = 20,
    String? lastPostId,
  }) async {
    try {
      _logger.debug('Searching posts by hashtag: $hashtag, limit: $limit', tag: 'SocialDataSource');

      var baseQuery = supabaseClient
          .from('posts')
          .select('''
            *,
            users!posts_author_id_fkey(id, display_name, photo_url)
          ''')
          .contains('hashtags', [hashtag]);

      if (lastPostId != null) {
        final lastPost = await supabaseClient
            .from('posts')
            .select('created_at')
            .eq('id', lastPostId)
            .single();
        baseQuery = baseQuery.filter('created_at', 'lt', lastPost['created_at']);
      }

      final response = await baseQuery
          .order('created_at', ascending: false)
          .limit(limit);

      final posts = (response as List)
          .map((json) => PostModel.fromJson(json).toEntity())
          .toList();

      _logger.debug('Found ${posts.length} posts with hashtag: $hashtag', tag: 'SocialDataSource');
      return posts;
    } catch (e, stackTrace) {
      _logger.error('Failed to search posts by hashtag', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');
      throw Exception('해시태그 검색 중 오류가 발생했습니다: ${e.toString()}');
    }
  }

  @override
  Future<List<String>> getPopularHashtags({
    int limit = 20,
  }) async {
    try {
      _logger.debug('Fetching popular hashtags, limit: $limit', tag: 'SocialDataSource');

      // PostgreSQL: unnest로 배열을 행으로 펼치고, 빈도수 계산
      final response = await supabaseClient.rpc('get_popular_hashtags', params: {
        'limit_count': limit,
      });

      if (response == null) {
        // RPC가 없으면 클라이언트 측에서 계산
        final posts = await supabaseClient
            .from('posts')
            .select('hashtags')
            .order('created_at', ascending: false)
            .limit(1000);

        final Map<String, int> hashtagCounts = {};
        for (final post in posts as List) {
          final hashtags = post['hashtags'] as List?;
          if (hashtags != null) {
            for (final tag in hashtags) {
              final tagStr = tag.toString();
              hashtagCounts[tagStr] = (hashtagCounts[tagStr] ?? 0) + 1;
            }
          }
        }

        final sortedTags = hashtagCounts.entries.toList()
          ..sort((a, b) => b.value.compareTo(a.value));

        return sortedTags.take(limit).map((e) => e.key).toList();
      }

      final hashtags = (response as List)
          .map((item) => item['hashtag'].toString())
          .toList();

      _logger.debug('Found ${hashtags.length} popular hashtags', tag: 'SocialDataSource');
      return hashtags;
    } catch (e, stackTrace) {
      _logger.error('Failed to get popular hashtags', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');

      // 실패 시 빈 배열 반환
      return [];
    }
  }

  @override
  Future<List<String>> getTrendingHashtags({
    int limit = 10,
    int days = 7,
  }) async {
    try {
      _logger.debug('Fetching trending hashtags, limit: $limit, days: $days', tag: 'SocialDataSource');

      final cutoffDate = DateTime.now().subtract(Duration(days: days));

      // PostgreSQL RPC 사용 (없으면 클라이언트 측 계산)
      try {
        final response = await supabaseClient.rpc('get_trending_hashtags', params: {
          'limit_count': limit,
          'days_ago': days,
        });

        if (response != null) {
          final hashtags = (response as List)
              .map((item) => item['hashtag'].toString())
              .toList();

          _logger.debug('Found ${hashtags.length} trending hashtags', tag: 'SocialDataSource');
          return hashtags;
        }
      } catch (rpcError) {
        _logger.debug('RPC not available, using client-side calculation', tag: 'SocialDataSource');
      }

      // 폴백: 클라이언트 측 계산
      final posts = await supabaseClient
          .from('posts')
          .select('hashtags')
          .gte('created_at', cutoffDate.toIso8601String())
          .order('created_at', ascending: false)
          .limit(1000);

      final Map<String, int> hashtagCounts = {};
      for (final post in posts as List) {
        final hashtags = post['hashtags'] as List?;
        if (hashtags != null) {
          for (final tag in hashtags) {
            final tagStr = tag.toString();
            hashtagCounts[tagStr] = (hashtagCounts[tagStr] ?? 0) + 1;
          }
        }
      }

      final sortedTags = hashtagCounts.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      return sortedTags.take(limit).map((e) => e.key).toList();
    } catch (e, stackTrace) {
      _logger.error('Failed to get trending hashtags', error: e, stackTrace: stackTrace, tag: 'SocialDataSource');

      // 실패 시 빈 배열 반환
      return [];
    }
  }
}