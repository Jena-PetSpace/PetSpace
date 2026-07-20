import 'dart:developer' as dev;

import 'package:supabase_flutter/supabase_flutter.dart';

class BlockService {
  final SupabaseClient _supabase;

  BlockService({required SupabaseClient supabase}) : _supabase = supabase;

  List<String>? _cachedBlockedIds;
  DateTime? _cachedAt;
  String? _cachedForUserId;
  static const _cacheTtl = Duration(minutes: 5);

  Future<List<String>> getBlockedUserIds({bool forceRefresh = false}) async {
    final currentUserId = _supabase.auth.currentUser?.id;
    if (currentUserId == null) {
      _invalidateCache();
      return const [];
    }
    if (!forceRefresh &&
        _cachedForUserId == currentUserId &&
        _cachedBlockedIds != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedBlockedIds!;
    }

    try {
      final response = await _supabase.rpc('get_my_blocked_user_ids');
      final ids = (response as List)
          .map((row) => (row as Map<String, dynamic>)['blocked_id'] as String)
          .toList(growable: false);
      _cachedBlockedIds = ids;
      _cachedAt = DateTime.now();
      _cachedForUserId = currentUserId;
      return ids;
    } catch (error, stackTrace) {
      dev.log(
        '차단 목록 조회 실패',
        name: 'BlockService',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<bool> blockUser(String targetUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId == targetUserId) return false;
    await _supabase.rpc('block_user', params: {'p_blocked_id': targetUserId});
    _invalidateCache();
    return true;
  }

  Future<bool> unblockUser(String targetUserId) async {
    if (_supabase.auth.currentUser == null) return false;
    await _supabase.rpc('unblock_user', params: {'p_blocked_id': targetUserId});
    _invalidateCache();
    return true;
  }

  Future<bool> isBlocked(String targetUserId) async {
    final ids = await getBlockedUserIds();
    return ids.contains(targetUserId);
  }

  Future<bool> isMutuallyBlocked(String otherUserId) async {
    if (_supabase.auth.currentUser == null) return false;
    final response = await _supabase.rpc(
      'is_mutually_blocked_with',
      params: {'p_other_user_id': otherUserId},
    );
    return response == true;
  }

  void _invalidateCache() {
    _cachedBlockedIds = null;
    _cachedAt = null;
    _cachedForUserId = null;
  }
}
