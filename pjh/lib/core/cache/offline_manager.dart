import 'dart:async';
import 'dart:developer';

import 'package:connectivity_plus/connectivity_plus.dart';

import 'cache_manager.dart';
import '../network/network_info.dart';

class OfflineManager {
  static final OfflineManager _instance = OfflineManager._internal();
  factory OfflineManager() => _instance;
  OfflineManager._internal();

  final CacheManager _cacheManager = CacheManager();
  final Connectivity _connectivity = Connectivity();
  final NetworkInfo _networkInfo = NetworkInfoImpl();

  StreamController<bool>? _connectionStateController;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;

  bool _isOnline = true;
  Timer? _syncTimer;

  Stream<bool> get connectionState {
    _connectionStateController ??= StreamController<bool>.broadcast();
    return _connectionStateController!.stream;
  }

  bool get isOnline => _isOnline;

  Future<void> initialize() async {
    await _cacheManager.initialize();
    _isOnline = await _networkInfo.isConnected;

    _connectivitySubscription = _connectivity.onConnectivityChanged.listen((results) {
      _handleConnectivityChange(results);
    });

    // Start periodic sync when online
    if (_isOnline) {
      _startPeriodicSync();
    }
  }

  void _handleConnectivityChange(List<ConnectivityResult> results) async {
    final wasOnline = _isOnline;
    _isOnline = results.isNotEmpty && !results.contains(ConnectivityResult.none);

    if (_isOnline && !wasOnline) {
      // Just came online
      await _syncOfflineActions();
      _startPeriodicSync();
    } else if (!_isOnline && wasOnline) {
      // Just went offline
      _stopPeriodicSync();
    }

    _connectionStateController?.add(_isOnline);
  }

  void _startPeriodicSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(const Duration(minutes: 5), (_) {
      _syncOfflineActions();
    });
  }

  void _stopPeriodicSync() {
    _syncTimer?.cancel();
  }

  Future<void> _syncOfflineActions() async {
    if (!_isOnline) return;

    final offlineQueue = await _cacheManager.getOfflineQueue();

    for (final action in List.from(offlineQueue)) {
      try {
        await _executeOfflineAction(action);
        await _cacheManager.removeFromOfflineQueue(action['id']);
      } catch (e) {
        log('Failed to sync offline action: $e', name: 'OfflineManager.sync');
        // Keep action in queue for retry
      }
    }
  }

  Future<void> _executeOfflineAction(Map<String, dynamic> action) async {
    final type = action['type'] as String;

    switch (type) {
      case 'create_post':
        await _syncCreatePost(action);
        break;
      case 'like_post':
        await _syncLikePost(action);
        break;
      case 'create_comment':
        await _syncCreateComment(action);
        break;
      case 'follow_user':
        await _syncFollowUser(action);
        break;
      case 'update_profile':
        await _syncUpdateProfile(action);
        break;
      default:
        log('Unknown offline action type: $type', name: 'OfflineManager.execute');
    }
  }

  Future<void> _syncCreatePost(Map<String, dynamic> action) async {
    // Implementation would call actual repository methods
    // This is a placeholder for the sync logic
    log('Syncing create post: ${action['data']}', name: 'OfflineManager.syncPost');
  }

  Future<void> _syncLikePost(Map<String, dynamic> action) async {
    log('Syncing like post: ${action['data']}', name: 'OfflineManager.syncLike');
  }

  Future<void> _syncCreateComment(Map<String, dynamic> action) async {
    log('Syncing create comment: ${action['data']}', name: 'OfflineManager.syncComment');
  }

  Future<void> _syncFollowUser(Map<String, dynamic> action) async {
    log('Syncing follow user: ${action['data']}', name: 'OfflineManager.syncFollow');
  }

  Future<void> _syncUpdateProfile(Map<String, dynamic> action) async {
    log('Syncing update profile: ${action['data']}', name: 'OfflineManager.syncProfile');
  }

  // Public methods for queueing offline actions
  Future<void> queueCreatePost(Map<String, dynamic> postData) async {
    await _cacheManager.queueOfflineAction({
      'type': 'create_post',
      'data': postData,
    });
  }

  Future<void> queueLikePost(String postId, String userId, bool isLike) async {
    await _cacheManager.queueOfflineAction({
      'type': 'like_post',
      'data': {
        'postId': postId,
        'userId': userId,
        'isLike': isLike,
      },
    });
  }

  Future<void> queueCreateComment(Map<String, dynamic> commentData) async {
    await _cacheManager.queueOfflineAction({
      'type': 'create_comment',
      'data': commentData,
    });
  }

  Future<void> queueFollowUser(String followerId, String followingId, bool isFollow) async {
    await _cacheManager.queueOfflineAction({
      'type': 'follow_user',
      'data': {
        'followerId': followerId,
        'followingId': followingId,
        'isFollow': isFollow,
      },
    });
  }

  Future<void> queueUpdateProfile(Map<String, dynamic> profileData) async {
    await _cacheManager.queueOfflineAction({
      'type': 'update_profile',
      'data': profileData,
    });
  }

  // Cache-first data access methods
  Future<List<Map<String, dynamic>>?> getPostsOfflineFirst(String feedType) async {
    if (_isOnline) {
      // Try to fetch fresh data, but return cached if network fails
      try {
        // This would call the actual repository method
        // final freshPosts = await _socialRepository.getPosts(feedType);
        // await _cacheManager.cachePosts(feedType, freshPosts);
        // return freshPosts;
      } catch (e) {
        // Fall back to cache
      }
    }

    return await _cacheManager.getCachedPosts(feedType);
  }

  Future<Map<String, dynamic>?> getUserProfileOfflineFirst(String userId) async {
    if (_isOnline) {
      try {
        // This would call the actual repository method
        // final freshProfile = await _socialRepository.getUserProfile(userId);
        // await _cacheManager.cacheUserProfile(userId, freshProfile);
        // return freshProfile;
      } catch (e) {
        // Fall back to cache
      }
    }

    return await _cacheManager.getCachedUserProfile(userId);
  }

  Future<List<Map<String, dynamic>>?> getCommentsOfflineFirst(String postId) async {
    if (_isOnline) {
      try {
        // This would call the actual repository method
        // final freshComments = await _socialRepository.getComments(postId);
        // await _cacheManager.cacheComments(postId, freshComments);
        // return freshComments;
      } catch (e) {
        // Fall back to cache
      }
    }

    return await _cacheManager.getCachedComments(postId);
  }

  Future<List<Map<String, dynamic>>?> getNotificationsOfflineFirst() async {
    if (_isOnline) {
      try {
        // This would call the actual repository method
        // final freshNotifications = await _socialRepository.getNotifications();
        // await _cacheManager.cacheNotifications(freshNotifications);
        // return freshNotifications;
      } catch (e) {
        // Fall back to cache
      }
    }

    return await _cacheManager.getCachedNotifications();
  }

  // Optimistic updates
  Future<void> optimisticLikePost(String postId, String userId, bool isLike) async {
    // Update local cache immediately
    final cachedPosts = await _cacheManager.getCachedPosts('home') ?? [];
    for (final post in cachedPosts) {
      if (post['id'] == postId) {
        final currentLikes = post['likesCount'] as int? ?? 0;
        post['likesCount'] = isLike ? currentLikes + 1 : currentLikes - 1;
        post['isLiked'] = isLike;
        break;
      }
    }
    await _cacheManager.cachePosts('home', cachedPosts);

    // Queue for sync
    if (!_isOnline) {
      await queueLikePost(postId, userId, isLike);
    }
  }

  Future<void> optimisticFollowUser(String followerId, String followingId, bool isFollow) async {
    // Update local cache immediately
    final cachedProfile = await _cacheManager.getCachedUserProfile(followingId);
    if (cachedProfile != null) {
      final currentFollowers = cachedProfile['followersCount'] as int? ?? 0;
      cachedProfile['followersCount'] = isFollow ? currentFollowers + 1 : currentFollowers - 1;
      cachedProfile['isFollowing'] = isFollow;
      await _cacheManager.cacheUserProfile(followingId, cachedProfile);
    }

    // Queue for sync
    if (!_isOnline) {
      await queueFollowUser(followerId, followingId, isFollow);
    }
  }

  // Cache management
  Future<void> preloadData() async {
    if (_isOnline) {
      // Preload essential data when app starts
      try {
        // This would preload user's feed, profile, and recent notifications
        log('Preloading data for offline use', name: 'OfflineManager.preload');
      } catch (e) {
        log('Failed to preload data: $e', name: 'OfflineManager.preload');
      }
    }
  }

  Future<void> clearCache() async {
    await _cacheManager.clearAllCache();
  }

  Future<int> getCacheSize() async {
    return await _cacheManager.getCacheSize();
  }

  void dispose() {
    _connectivitySubscription?.cancel();
    _syncTimer?.cancel();
    _connectionStateController?.close();
  }
}