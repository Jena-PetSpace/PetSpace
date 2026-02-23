import 'dart:io';
import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/emotion_analysis.dart';
import '../../../pets/domain/entities/pet.dart';

abstract class EmotionRepository {
  // 감정 분석
  Future<Either<Failure, EmotionAnalysis>> analyzeEmotion({
    required String imagePath,
    String? petId,
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
}