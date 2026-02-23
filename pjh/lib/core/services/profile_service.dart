import 'dart:developer';
import 'dart:io';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'image_upload_service.dart';

/// 프로필 관리 서비스
class ProfileService {
  final SupabaseClient _supabase;
  final ImageUploadService _imageUploadService;

  ProfileService({
    required SupabaseClient supabase,
    required ImageUploadService imageUploadService,
  })  : _supabase = supabase,
        _imageUploadService = imageUploadService;

  /// 현재 사용자 ID 가져오기
  String get _currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.id;
  }

  /// 프로필 정보 조회
  Future<Map<String, dynamic>?> getProfile() async {
    try {
      final userId = _currentUserId;

      final response = await _supabase
          .from('users')
          .select()
          .eq('id', userId)
          .maybeSingle();

      return response;
    } catch (e) {
      log('프로필 조회 오류: $e', name: 'ProfileService.getProfile');
      rethrow;
    }
  }

  /// 프로필 정보 업데이트
  Future<void> updateProfile({
    String? displayName,
    String? bio,
    String? photoUrl,
  }) async {
    try {
      final userId = _currentUserId;
      final updateData = <String, dynamic>{
        'updated_at': DateTime.now().toIso8601String(),
      };

      if (displayName != null) updateData['display_name'] = displayName;
      if (bio != null) updateData['bio'] = bio;
      if (photoUrl != null) updateData['photo_url'] = photoUrl;

      await _supabase.from('users').update(updateData).eq('id', userId);

      log('프로필 업데이트 성공', name: 'ProfileService.updateProfile');
    } catch (e) {
      log('프로필 업데이트 오류: $e', name: 'ProfileService.updateProfile');
      rethrow;
    }
  }

  /// 프로필 이미지 업로드 및 업데이트
  Future<String> updateProfileImage(File imageFile) async {
    try {
      // 이미지 업로드 시도
      try {
        final imageUrl = await _imageUploadService.uploadProfileImage(imageFile);

        // DB 업데이트
        await updateProfile(photoUrl: imageUrl);

        log('프로필 이미지 업데이트 성공: $imageUrl',
            name: 'ProfileService.updateProfileImage');

        return imageUrl;
      } catch (uploadError) {
        // Storage 업로드 실패 시 로컬 경로 사용
        log('Storage 업로드 실패, 로컬 경로 사용: $uploadError',
            name: 'ProfileService.updateProfileImage');

        final localPath = imageFile.path;

        // DB 업데이트 (로컬 경로 저장)
        await updateProfile(photoUrl: localPath);

        log('프로필 이미지 로컬 경로 저장 성공: $localPath',
            name: 'ProfileService.updateProfileImage');

        return localPath;
      }
    } catch (e) {
      log('프로필 이미지 업데이트 오류: $e',
          name: 'ProfileService.updateProfileImage');
      rethrow;
    }
  }

  /// 프로필 삭제 (탈퇴)
  Future<void> deleteProfile() async {
    try {
      final userId = _currentUserId;

      // 사용자 데이터 삭제 (cascading delete가 설정되어 있다면 관련 데이터도 삭제됨)
      await _supabase.from('users').delete().eq('id', userId);

      log('프로필 삭제 성공', name: 'ProfileService.deleteProfile');
    } catch (e) {
      log('프로필 삭제 오류: $e', name: 'ProfileService.deleteProfile');
      rethrow;
    }
  }

  /// 프로필 통계 조회
  Future<Map<String, int>> getProfileStats() async {
    try {
      final userId = _currentUserId;

      // 게시물 수
      final postsResponse = await _supabase
          .from('posts')
          .select('id')
          .eq('user_id', userId);
      final postsCount = (postsResponse as List).length;

      // 팔로워 수
      final followersResponse = await _supabase
          .from('follows')
          .select('id')
          .eq('following_id', userId);
      final followersCount = (followersResponse as List).length;

      // 팔로잉 수
      final followingResponse = await _supabase
          .from('follows')
          .select('id')
          .eq('follower_id', userId);
      final followingCount = (followingResponse as List).length;

      return {
        'posts': postsCount,
        'followers': followersCount,
        'following': followingCount,
      };
    } catch (e) {
      log('프로필 통계 조회 오류: $e', name: 'ProfileService.getProfileStats');
      return {
        'posts': 0,
        'followers': 0,
        'following': 0,
      };
    }
  }

  /// 프로필 완성도 체크
  bool isProfileComplete(Map<String, dynamic> profile) {
    final displayName = profile['display_name'] as String?;
    final photoUrl = profile['photo_url'] as String?;

    return displayName != null &&
        displayName.isNotEmpty &&
        photoUrl != null &&
        photoUrl.isNotEmpty;
  }

  /// 사용자 이름 중복 체크
  Future<bool> isUsernameAvailable(String username) async {
    try {
      final response = await _supabase
          .from('users')
          .select('id')
          .eq('username', username)
          .maybeSingle();

      return response == null;
    } catch (e) {
      log('사용자 이름 중복 체크 오류: $e',
          name: 'ProfileService.isUsernameAvailable');
      return false;
    }
  }
}
