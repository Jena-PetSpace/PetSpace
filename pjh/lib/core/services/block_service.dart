import 'dart:developer' as dev;

import 'package:supabase_flutter/supabase_flutter.dart';

/// 사용자 차단 관련 로직 통합 서비스
/// - 차단/해제
/// - 내가 차단한 사용자 ID 목록 캐시
/// - 상호 차단 확인
///
/// 본격적인 Clean Architecture 분리는 Track B에서 진행. 현재는
/// feed/search/profile에서 사용할 얇은 래퍼로 둠.
class BlockService {
  final SupabaseClient _supabase;

  BlockService({required SupabaseClient supabase}) : _supabase = supabase;

  List<String>? _cachedBlockedIds;
  DateTime? _cachedAt;

  static const _cacheTtl = Duration(minutes: 5);

  /// 내가 차단한 사용자 ID 목록 (캐시)
  Future<List<String>> getBlockedUserIds({bool forceRefresh = false}) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return const [];

    // 캐시 히트
    if (!forceRefresh &&
        _cachedBlockedIds != null &&
        _cachedAt != null &&
        DateTime.now().difference(_cachedAt!) < _cacheTtl) {
      return _cachedBlockedIds!;
    }

    try {
      final response = await _supabase
          .from('user_blocks')
          .select('blocked_id')
          .eq('blocker_id', userId);

      final ids = (response as List)
          .map((row) => row['blocked_id'] as String)
          .toList();

      _cachedBlockedIds = ids;
      _cachedAt = DateTime.now();
      return ids;
    } catch (e) {
      dev.log('차단 목록 조회 실패: $e', name: 'BlockService');
      return _cachedBlockedIds ?? const [];
    }
  }

  /// 사용자 차단 (본인이 차단하는 경우만)
  Future<bool> blockUser(String targetUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null || userId == targetUserId) return false;

    try {
      await _supabase.from('user_blocks').insert({
        'blocker_id': userId,
        'blocked_id': targetUserId,
      });
      _invalidateCache();
      return true;
    } catch (e) {
      dev.log('차단 실패: $e', name: 'BlockService');
      return false;
    }
  }

  /// 차단 해제
  Future<bool> unblockUser(String targetUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      await _supabase
          .from('user_blocks')
          .delete()
          .eq('blocker_id', userId)
          .eq('blocked_id', targetUserId);
      _invalidateCache();
      return true;
    } catch (e) {
      dev.log('차단 해제 실패: $e', name: 'BlockService');
      return false;
    }
  }

  /// 특정 사용자 차단 여부
  Future<bool> isBlocked(String targetUserId) async {
    final ids = await getBlockedUserIds();
    return ids.contains(targetUserId);
  }

  /// 상호 차단 확인 (A→B 또는 B→A 중 하나라도 차단)
  Future<bool> isMutuallyBlocked(String otherUserId) async {
    final userId = _supabase.auth.currentUser?.id;
    if (userId == null) return false;

    try {
      final response = await _supabase.rpc(
        'is_mutually_blocked',
        params: {'p_user_a': userId, 'p_user_b': otherUserId},
      );
      return response == true;
    } catch (e) {
      // RPC 없으면 단방향 체크만
      return await isBlocked(otherUserId);
    }
  }

  void _invalidateCache() {
    _cachedBlockedIds = null;
    _cachedAt = null;
  }
}
