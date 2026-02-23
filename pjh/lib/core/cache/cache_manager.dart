import 'dart:convert';
import 'dart:io';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:crypto/crypto.dart';

class CacheManager {
  static final CacheManager _instance = CacheManager._internal();
  factory CacheManager() => _instance;
  CacheManager._internal();

  SharedPreferences? _prefs;
  String? _cacheDir;

  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    final appDir = await getApplicationDocumentsDirectory();
    _cacheDir = '${appDir.path}/cache';
    await Directory(_cacheDir!).create(recursive: true);
  }

  // Data caching
  Future<void> cacheData(String key, Map<String, dynamic> data, {Duration? ttl}) async {
    final cacheItem = CacheItem(
      data: data,
      timestamp: DateTime.now(),
      ttl: ttl ?? const Duration(hours: 1),
    );

    await _prefs?.setString(key, jsonEncode(cacheItem.toJson()));
  }

  Future<Map<String, dynamic>?> getCachedData(String key) async {
    final cachedString = _prefs?.getString(key);
    if (cachedString == null) return null;

    try {
      final cacheItem = CacheItem.fromJson(jsonDecode(cachedString));

      if (cacheItem.isExpired()) {
        await _prefs?.remove(key);
        return null;
      }

      return cacheItem.data;
    } catch (e) {
      await _prefs?.remove(key);
      return null;
    }
  }

  // Image caching
  Future<void> cacheImage(String url, List<int> bytes) async {
    final fileName = _generateImageFileName(url);
    final file = File('$_cacheDir/images/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes);

    // Store metadata
    await _prefs?.setString('img_$fileName', jsonEncode({
      'url': url,
      'timestamp': DateTime.now().toIso8601String(),
      'size': bytes.length,
    }));
  }

  Future<File?> getCachedImage(String url) async {
    final fileName = _generateImageFileName(url);
    final file = File('$_cacheDir/images/$fileName');

    if (await file.exists()) {
      // Check if cache is still valid (7 days)
      final metadataString = _prefs?.getString('img_$fileName');
      if (metadataString != null) {
        final metadata = jsonDecode(metadataString);
        final timestamp = DateTime.parse(metadata['timestamp']);
        final age = DateTime.now().difference(timestamp);

        if (age.inDays < 7) {
          return file;
        }
      }

      // Cache expired, delete file
      await file.delete();
      await _prefs?.remove('img_$fileName');
    }

    return null;
  }

  String _generateImageFileName(String url) {
    final bytes = utf8.encode(url);
    final digest = md5.convert(bytes);
    return '$digest.jpg';
  }

  // User data caching
  Future<void> cacheUserProfile(String userId, Map<String, dynamic> profile) async {
    await cacheData('user_$userId', profile, ttl: const Duration(minutes: 30));
  }

  Future<Map<String, dynamic>?> getCachedUserProfile(String userId) async {
    return await getCachedData('user_$userId');
  }

  // Post data caching
  Future<void> cachePosts(String feedType, List<Map<String, dynamic>> posts) async {
    await cacheData('posts_$feedType', {'posts': posts}, ttl: const Duration(minutes: 15));
  }

  Future<List<Map<String, dynamic>>?> getCachedPosts(String feedType) async {
    final data = await getCachedData('posts_$feedType');
    if (data != null && data['posts'] is List) {
      return List<Map<String, dynamic>>.from(data['posts']);
    }
    return null;
  }

  // Comments caching
  Future<void> cacheComments(String postId, List<Map<String, dynamic>> comments) async {
    await cacheData('comments_$postId', {'comments': comments}, ttl: const Duration(minutes: 10));
  }

  Future<List<Map<String, dynamic>>?> getCachedComments(String postId) async {
    final data = await getCachedData('comments_$postId');
    if (data != null && data['comments'] is List) {
      return List<Map<String, dynamic>>.from(data['comments']);
    }
    return null;
  }

  // Notification caching
  Future<void> cacheNotifications(List<Map<String, dynamic>> notifications) async {
    await cacheData('notifications', {'notifications': notifications}, ttl: const Duration(minutes: 5));
  }

  Future<List<Map<String, dynamic>>?> getCachedNotifications() async {
    final data = await getCachedData('notifications');
    if (data != null && data['notifications'] is List) {
      return List<Map<String, dynamic>>.from(data['notifications']);
    }
    return null;
  }

  // Cache management
  Future<void> clearExpiredCache() async {
    final keys = _prefs?.getKeys() ?? <String>{};

    for (final key in keys) {
      if (key.startsWith('img_')) continue; // Handle image cache separately

      final cachedString = _prefs?.getString(key);
      if (cachedString != null) {
        try {
          final cacheItem = CacheItem.fromJson(jsonDecode(cachedString));
          if (cacheItem.isExpired()) {
            await _prefs?.remove(key);
          }
        } catch (e) {
          await _prefs?.remove(key);
        }
      }
    }
  }

  Future<void> clearAllCache() async {
    await _prefs?.clear();
    final cacheDirectory = Directory(_cacheDir!);
    if (await cacheDirectory.exists()) {
      await cacheDirectory.delete(recursive: true);
    }
  }

  Future<int> getCacheSize() async {
    int totalSize = 0;

    // Calculate data cache size
    final keys = _prefs?.getKeys() ?? <String>{};
    for (final key in keys) {
      final value = _prefs?.getString(key);
      if (value != null) {
        totalSize += value.length * 2; // Rough estimate (UTF-16)
      }
    }

    // Calculate image cache size
    final imageDir = Directory('$_cacheDir/images');
    if (await imageDir.exists()) {
      await for (final entity in imageDir.list()) {
        if (entity is File) {
          final stat = await entity.stat();
          totalSize += stat.size;
        }
      }
    }

    return totalSize;
  }

  Future<void> trimCache({int maxSizeBytes = 50 * 1024 * 1024}) async {
    final currentSize = await getCacheSize();

    if (currentSize <= maxSizeBytes) return;

    // Remove oldest image files first
    final imageDir = Directory('$_cacheDir/images');
    if (await imageDir.exists()) {
      final files = <FileSystemEntity>[];
      await for (final entity in imageDir.list()) {
        if (entity is File) {
          files.add(entity);
        }
      }

      // Sort by modification time
      files.sort((a, b) {
        final aStat = (a as File).statSync();
        final bStat = (b as File).statSync();
        return aStat.modified.compareTo(bStat.modified);
      });

      // Remove oldest files until under limit
      int removedSize = 0;
      for (final file in files) {
        final stat = (file as File).statSync();
        await file.delete();
        removedSize += stat.size;

        if (currentSize - removedSize <= maxSizeBytes) break;
      }
    }
  }

  // Offline queue management
  Future<void> queueOfflineAction(Map<String, dynamic> action) async {
    final queue = await getOfflineQueue();
    queue.add({
      ...action,
      'timestamp': DateTime.now().toIso8601String(),
      'id': DateTime.now().millisecondsSinceEpoch.toString(),
    });

    await _prefs?.setString('offline_queue', jsonEncode(queue));
  }

  Future<List<Map<String, dynamic>>> getOfflineQueue() async {
    final queueString = _prefs?.getString('offline_queue');
    if (queueString != null) {
      final queueList = jsonDecode(queueString) as List;
      return List<Map<String, dynamic>>.from(queueList);
    }
    return [];
  }

  Future<void> removeFromOfflineQueue(String actionId) async {
    final queue = await getOfflineQueue();
    queue.removeWhere((action) => action['id'] == actionId);
    await _prefs?.setString('offline_queue', jsonEncode(queue));
  }

  Future<void> clearOfflineQueue() async {
    await _prefs?.remove('offline_queue');
  }
}

class CacheItem {
  final Map<String, dynamic> data;
  final DateTime timestamp;
  final Duration ttl;

  CacheItem({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool isExpired() {
    return DateTime.now().difference(timestamp) > ttl;
  }

  Map<String, dynamic> toJson() {
    return {
      'data': data,
      'timestamp': timestamp.toIso8601String(),
      'ttl': ttl.inMilliseconds,
    };
  }

  factory CacheItem.fromJson(Map<String, dynamic> json) {
    return CacheItem(
      data: Map<String, dynamic>.from(json['data']),
      timestamp: DateTime.parse(json['timestamp']),
      ttl: Duration(milliseconds: json['ttl']),
    );
  }
}