import 'dart:io';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/emotion_analysis.dart';
import '../../../pets/domain/entities/pet.dart';

abstract class EmotionRepository {
  // 감정 분석
  Future<Either<Failure, EmotionAnalysis>> analyzeEmotion({
    required List<String> imagePaths,
    String? petId,
    String? petType,
    String? breed,
  });

  // 히스토리 관리
  Future<Either<Failure, void>> saveAnalysis(EmotionAnalysis analysis);
  Future<Either<Failure, List<EmotionAnalysis>>> getAnalysisHistory({
    required String userId,
    String? petId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  });
  Future<Either<Failure, EmotionAnalysis>> getAnalysisById(String id);
  Future<Either<Failure, void>> deleteAnalysis(String id);

  // 반려동물 관리
  Future<Either<Failure, Pet>> registerPet(Pet pet);
  Future<Either<Failure, List<Pet>>> getUserPets(String userId);
  Future<Either<Failure, Pet>> getPetById(String petId);
  Future<Either<Failure, Pet>> updatePet(Pet pet);
  Future<Either<Failure, void>> deletePet(String petId);

  // 이미지 관리
  Future<Either<Failure, String>> uploadImage(File imageFile, String path);
  Future<Either<Failure, File>> processImage(File imageFile);

  // 통계
  Future<Either<Failure, Map<String, dynamic>>> getEmotionStatistics({
    required String userId,
    String? petId,
    DateTime? startDate,
    DateTime? endDate,
  });

  // C-2: 커뮤니티 품종 평균
  Future<Either<Failure, Map<String, dynamic>>> getBreedAverage({
    required String breed,
    int days = 30,
  });

  /// 최근 7일 해당 감정 평균과 비교해 상대값 텍스트 반환.
  /// 데이터 부족 / 오류 시 null.
  Future<Either<Failure, String?>> getEmotionComparisonInsight({
    required String petId,
    required String emotion,
    required num value,
    int days = 7,
  });

  /// 특정 반려동물의 감정 분석 이력 (RLS 로 본인 기록만 반환).
  /// 공개 프로필에서 다른 유저 조회 시 빈 리스트.
  Future<Either<Failure, List<EmotionAnalysis>>> getAnalysesByPet({
    required String petId,
    int limit = 20,
  });

  /// 부위별 최신 건강 분석 결과 (RPC get_latest_health_by_area)
  Future<Either<Failure, List<Map<String, dynamic>>>> getLatestHealthByArea({
    required String userId,
    String? petId,
  });

  /// 내 건강분석 이력 전체 (health_history 테이블)
  Future<Either<Failure, List<Map<String, dynamic>>>> getHealthHistory(
      String userId);

  /// 감정 타임라인 (RPC get_emotion_timeline) — 지정 기간 일자별 평균
  Future<Either<Failure, List<Map<String, dynamic>>>> getEmotionTimeline({
    required String petId,
    int days = 30,
  });

  /// 건강분석 결과 저장 (Storage 업로드 + health_history INSERT)
  /// localImagePaths 를 Storage 로 업로드한 뒤 resultJson 의 image_urls 를 갱신.
  /// 이미 URL 인 경로는 재업로드 없이 그대로 사용.
  Future<Either<Failure, void>> saveHealthAnalysis({
    required String userId,
    required List<String> imagePathsOrUrls,
    required Map<String, dynamic> resultJson,
  });
}
