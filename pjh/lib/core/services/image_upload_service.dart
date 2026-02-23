import 'dart:developer';
import 'dart:io';
import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:path/path.dart' as path;

class ImageUploadService {
  final SupabaseClient _supabase;

  ImageUploadService({
    required SupabaseClient storage,
    required auth,
  }) : _supabase = storage;

  String get _currentUserId {
    final user = _supabase.auth.currentUser;
    if (user == null) throw Exception('User not authenticated');
    return user.id;
  }

  Future<Map<String, String>> uploadPostImage(File imageFile, {String? postId}) async {
    try {
      final userId = _currentUserId;
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final fileName = '${timestamp}_${path.basename(imageFile.path)}';
      final destinationPath = 'posts/$userId/${postId ?? 'temp'}/$fileName';
      final thumbnailPath = 'posts/$userId/${postId ?? 'temp'}/thumb_$fileName';

      log('Uploading post image to: $destinationPath', name: 'ImageUploadService');

      // Compress image before upload
      final compressedImage = await _compressImage(imageFile);

      // Generate thumbnail
      final thumbnail = await _generateThumbnail(imageFile);

      // Upload main image
      await _supabase.storage
          .from('images')
          .uploadBinary(destinationPath, compressedImage,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: false,
              ));

      // Upload thumbnail
      await _supabase.storage
          .from('images')
          .uploadBinary(thumbnailPath, thumbnail,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: false,
              ));

      final imageUrl = _supabase.storage.from('images').getPublicUrl(destinationPath);
      final thumbnailUrl = _supabase.storage.from('images').getPublicUrl(thumbnailPath);

      log('Image uploaded successfully: $imageUrl', name: 'ImageUploadService');

      return {
        'imageUrl': imageUrl,
        'thumbnailUrl': thumbnailUrl,
      };
    } catch (e) {
      log('Failed to upload post image: $e', name: 'ImageUploadService', error: e);
      throw Exception('Failed to upload post image: $e');
    }
  }

  Future<String> uploadProfileImage(File imageFile) async {
    try {
      final userId = _currentUserId;
      final fileName = 'profile_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destinationPath = 'profiles/$userId/$fileName';

      // Compress and resize for profile image
      final processedImage = await _processProfileImage(imageFile);

      await _supabase.storage
          .from('images')
          .uploadBinary(destinationPath, processedImage,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: true, // 같은 파일명이면 덮어쓰기
              ));

      // Delete old profile images
      await _deleteOldProfileImages(userId, fileName);

      return _supabase.storage.from('images').getPublicUrl(destinationPath);
    } catch (e) {
      log('Failed to upload profile image: $e', name: 'ImageUploadService.uploadProfileImage');
      throw Exception('Failed to upload profile image: $e');
    }
  }

  Future<String> uploadEmotionAnalysisImage(
      File imageFile, String analysisId) async {
    try {
      final userId = _currentUserId;
      final fileName = 'analysis_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destinationPath = 'emotion_analysis/$userId/$analysisId/$fileName';

      final compressedImage = await _compressImage(imageFile);

      await _supabase.storage
          .from('images')
          .uploadBinary(destinationPath, compressedImage,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: false,
              ));

      return _supabase.storage.from('images').getPublicUrl(destinationPath);
    } catch (e) {
      throw Exception('Failed to upload emotion analysis image: $e');
    }
  }

  /// 반려동물 아바타 이미지 업로드
  Future<String> uploadPetAvatar(File imageFile, String petId) async {
    try {
      final userId = _currentUserId;
      final fileName = 'pet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final destinationPath = 'pets/$userId/$petId/$fileName';

      log('Uploading pet avatar to: $destinationPath', name: 'ImageUploadService');

      // 반려동물 아바타는 프로필 이미지와 비슷한 크기로 처리 (정사각형)
      final processedImage = await _processPetAvatar(imageFile);

      await _supabase.storage
          .from('images')
          .uploadBinary(destinationPath, processedImage,
              fileOptions: const FileOptions(
                contentType: 'image/jpeg',
                cacheControl: '3600',
                upsert: true, // 같은 petId면 덮어쓰기
              ));

      // 이전 아바타 이미지 삭제
      await _deleteOldPetAvatars(userId, petId, fileName);

      final avatarUrl = _supabase.storage.from('images').getPublicUrl(destinationPath);
      log('Pet avatar uploaded successfully: $avatarUrl', name: 'ImageUploadService');

      return avatarUrl;
    } catch (e) {
      log('Failed to upload pet avatar: $e', name: 'ImageUploadService', error: e);
      throw Exception('Failed to upload pet avatar: $e');
    }
  }

  Future<void> _deleteOldPetAvatars(
      String userId, String petId, String currentFileName) async {
    try {
      final folderPath = 'pets/$userId/$petId';
      final files =
          await _supabase.storage.from('images').list(path: folderPath);

      final oldFiles = files
          .where((file) => file.name != currentFileName)
          .map((file) => '$folderPath/${file.name}')
          .toList();

      if (oldFiles.isNotEmpty) {
        await _supabase.storage.from('images').remove(oldFiles);
        log('Deleted ${oldFiles.length} old pet avatar(s)', name: 'ImageUploadService');
      }
    } catch (e) {
      // Don't throw error for cleanup failures
      log('Warning: Failed to delete old pet avatars: $e',
          name: 'ImageUploadService.cleanup');
    }
  }

  Future<Uint8List> _processPetAvatar(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize to pet avatar dimensions (square, 400x400)
      const size = 400; // 프로필보다 조금 더 크게 (더 디테일한 표현)
      final processedImage = img.copyResizeCropSquare(image, size: size);

      // High quality for pet avatars
      final compressedBytes = img.encodeJpg(processedImage, quality: 90);
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      throw Exception('Failed to process pet avatar: $e');
    }
  }

  Future<List<Map<String, String>>> uploadMultiplePostImages(List<File> imageFiles,
      {String? postId}) async {
    try {
      final List<Map<String, String>> results = [];

      log('Uploading ${imageFiles.length} images', name: 'ImageUploadService');

      for (int i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];
        final userId = _currentUserId;
        final timestamp = DateTime.now().millisecondsSinceEpoch;
        final fileName = '${i}_${timestamp}_${path.basename(imageFile.path)}';
        final destinationPath = 'posts/$userId/${postId ?? 'temp'}/$fileName';
        final thumbnailPath = 'posts/$userId/${postId ?? 'temp'}/thumb_$fileName';

        log('Uploading image ${i + 1}/${imageFiles.length}', name: 'ImageUploadService');

        final compressedImage = await _compressImage(imageFile);
        final thumbnail = await _generateThumbnail(imageFile);

        // Upload main image
        await _supabase.storage
            .from('images')
            .uploadBinary(destinationPath, compressedImage,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  cacheControl: '3600',
                  upsert: false,
                ));

        // Upload thumbnail
        await _supabase.storage
            .from('images')
            .uploadBinary(thumbnailPath, thumbnail,
                fileOptions: const FileOptions(
                  contentType: 'image/jpeg',
                  cacheControl: '3600',
                  upsert: false,
                ));

        final imageUrl = _supabase.storage.from('images').getPublicUrl(destinationPath);
        final thumbnailUrl = _supabase.storage.from('images').getPublicUrl(thumbnailPath);

        results.add({
          'imageUrl': imageUrl,
          'thumbnailUrl': thumbnailUrl,
        });
      }

      log('Successfully uploaded ${results.length} images', name: 'ImageUploadService');
      return results;
    } catch (e) {
      log('Failed to upload multiple post images: $e', name: 'ImageUploadService', error: e);
      throw Exception('Failed to upload multiple post images: $e');
    }
  }

  Future<void> deleteImage(String imageUrl) async {
    try {
      // Extract bucket and path from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Assuming URL format: https://bucket.supabase.co/storage/v1/object/public/bucket-name/path
      final bucketIndex = pathSegments.indexOf('public') + 1;
      if (bucketIndex >= pathSegments.length) {
        throw Exception('Invalid image URL format');
      }

      final bucket = pathSegments[bucketIndex];
      final path = pathSegments.skip(bucketIndex + 1).join('/');

      await _supabase.storage.from(bucket).remove([path]);
    } catch (e) {
      throw Exception('Failed to delete image: $e');
    }
  }

  Future<void> deletePostImages(String postId) async {
    try {
      final userId = _currentUserId;
      final folderPath = 'posts/$userId/$postId';

      final files =
          await _supabase.storage.from('images').list(path: folderPath);

      final filePaths =
          files.map((file) => '$folderPath/${file.name}').toList();

      if (filePaths.isNotEmpty) {
        await _supabase.storage.from('images').remove(filePaths);
      }
    } catch (e) {
      throw Exception('Failed to delete post images: $e');
    }
  }

  Future<void> _deleteOldProfileImages(
      String userId, String currentFileName) async {
    try {
      final folderPath = 'profiles/$userId';
      final files =
          await _supabase.storage.from('images').list(path: folderPath);

      final oldFiles = files
          .where((file) => file.name != currentFileName)
          .map((file) => '$folderPath/${file.name}')
          .toList();

      if (oldFiles.isNotEmpty) {
        await _supabase.storage.from('images').remove(oldFiles);
      }
    } catch (e) {
      // Don't throw error for cleanup failures
      log('Warning: Failed to delete old profile images: $e',
          name: 'ImageUploadService.cleanup');
    }
  }

  Future<Uint8List> _compressImage(File imageFile,
      {int maxWidth = 1920, int quality = 85}) async {
    try {
      final imageBytes = await imageFile.readAsBytes();

      log('Original image size: ${imageBytes.length} bytes', name: 'ImageUploadService');

      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      log('Original dimensions: ${image.width}x${image.height}', name: 'ImageUploadService');

      // Resize if image is too large
      img.Image resizedImage = image;
      if (image.width > maxWidth || image.height > maxWidth) {
        // 가로/세로 중 긴 쪽을 maxWidth로 맞춤
        if (image.width > image.height) {
          final aspectRatio = image.height / image.width;
          final newHeight = (maxWidth * aspectRatio).round();
          resizedImage =
              img.copyResize(image, width: maxWidth, height: newHeight, interpolation: img.Interpolation.linear);
        } else {
          final aspectRatio = image.width / image.height;
          final newWidth = (maxWidth * aspectRatio).round();
          resizedImage =
              img.copyResize(image, width: newWidth, height: maxWidth, interpolation: img.Interpolation.linear);
        }
        log('Resized dimensions: ${resizedImage.width}x${resizedImage.height}', name: 'ImageUploadService');
      }

      // Compress as JPEG with optimized quality
      final compressedBytes = img.encodeJpg(resizedImage, quality: quality);
      final compressedSize = compressedBytes.length;

      log('Compressed image size: $compressedSize bytes (${((1 - compressedSize / imageBytes.length) * 100).toStringAsFixed(1)}% reduction)',
          name: 'ImageUploadService');

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      log('Failed to compress image: $e', name: 'ImageUploadService', error: e);
      throw Exception('Failed to compress image: $e');
    }
  }

  Future<Uint8List> _processProfileImage(File imageFile) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      // Resize to profile image dimensions (square)
      const size = 300; // 300x300 for profile images
      final processedImage = img.copyResizeCropSquare(image, size: size);

      // High quality for profile images
      final compressedBytes = img.encodeJpg(processedImage, quality: 90);
      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      throw Exception('Failed to process profile image: $e');
    }
  }

  /// 썸네일 생성 (피드 목록에서 빠른 로딩을 위한 작은 이미지)
  Future<Uint8List> _generateThumbnail(File imageFile,
      {int maxWidth = 400, int quality = 75}) async {
    try {
      final imageBytes = await imageFile.readAsBytes();
      final image = img.decodeImage(imageBytes);

      if (image == null) {
        throw Exception('Failed to decode image');
      }

      log('Generating thumbnail (${image.width}x${image.height} -> ${maxWidth}px)',
          name: 'ImageUploadService');

      // Resize to thumbnail size
      img.Image thumbnail = image;
      if (image.width > maxWidth || image.height > maxWidth) {
        // 가로/세로 중 긴 쪽을 maxWidth로 맞춤
        if (image.width > image.height) {
          final aspectRatio = image.height / image.width;
          final newHeight = (maxWidth * aspectRatio).round();
          thumbnail = img.copyResize(image,
              width: maxWidth,
              height: newHeight,
              interpolation: img.Interpolation.average);
        } else {
          final aspectRatio = image.width / image.height;
          final newWidth = (maxWidth * aspectRatio).round();
          thumbnail = img.copyResize(image,
              width: newWidth,
              height: maxWidth,
              interpolation: img.Interpolation.average);
        }
      }

      // Compress with lower quality for thumbnail
      final compressedBytes = img.encodeJpg(thumbnail, quality: quality);

      log('Thumbnail generated: ${compressedBytes.length} bytes',
          name: 'ImageUploadService');

      return Uint8List.fromList(compressedBytes);
    } catch (e) {
      log('Failed to generate thumbnail: $e', name: 'ImageUploadService', error: e);
      throw Exception('Failed to generate thumbnail: $e');
    }
  }

  // Utility method to check if user has permission to delete image
  Future<bool> canDeleteImage(String imageUrl) async {
    try {
      final userId = _currentUserId;

      // Extract path from URL to check if it contains user's ID
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      // Check if user ID is in the path (for ownership verification)
      return pathSegments.any((segment) => segment == userId);
    } catch (e) {
      return false;
    }
  }

  // Get image metadata (limited in Supabase Storage)
  Future<Map<String, dynamic>?> getImageMetadata(String imageUrl) async {
    try {
      // Extract basic info from URL
      final uri = Uri.parse(imageUrl);
      final pathSegments = uri.pathSegments;

      if (pathSegments.length >= 2) {
        final bucketIndex = pathSegments.indexOf('public') + 1;
        if (bucketIndex < pathSegments.length) {
          final bucket = pathSegments[bucketIndex];
          final path = pathSegments.skip(bucketIndex + 1).join('/');

          return {
            'bucket': bucket,
            'path': path,
            'url': imageUrl,
          };
        }
      }

      return null;
    } catch (e) {
      return null;
    }
  }
}
