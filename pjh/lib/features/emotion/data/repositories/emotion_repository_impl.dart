import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../domain/repositories/emotion_repository.dart';
import '../models/emotion_analysis_model.dart';
import '../datasources/emotion_ai_service.dart';
import '../datasources/image_service.dart';

class EmotionRepositoryImpl implements EmotionRepository {
  final SupabaseClient supabaseClient;
  final NetworkInfo networkInfo;
  final EmotionAIService aiService;
  final ImageService imageService;

  EmotionRepositoryImpl({
    required this.supabaseClient,
    required this.networkInfo,
    required this.aiService,
    required this.imageService,
  });

  @override
  Future<Either<Failure, EmotionAnalysis>> analyzeEmotion({
    required String imagePath,
    String? petId,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure(message: '로그인이 필요합니다.'));
      }

      final imageFile = File(imagePath);

      // 이미지 처리
      final processedImage = await imageService.processImage(imageFile);

      // AI 감정 분석
      final emotionScores =
          await aiService.analyzeEmotionFromImage(processedImage);

      // 이미지를 Supabase Storage에 업로드
      final imageUrl = await uploadImage(processedImage, 'emotions/${user.id}');
      final localImagePath = await imageService.saveImageToLocal(
        processedImage,
        'emotion_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      // 신뢰도 계산 (감정 점수의 분산을 이용)
      final confidence = _calculateConfidence(emotionScores);

      // 분석 결과 생성
      final analysis = EmotionAnalysisModel(
        id: '', // Supabase에서 자동 생성
        userId: user.id,
        petId: petId,
        imageUrl: imageUrl.fold((l) => '', (r) => r),
        localImagePath: localImagePath,
        emotions: emotionScores,
        confidence: confidence,
        analyzedAt: DateTime.now(),
        memo: null,
        tags: const [],
      );

      return Right(analysis);
    } catch (e) {
      return Left(
          AnalysisFailure(message: '감정 분석 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> saveAnalysis(EmotionAnalysis analysis) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final analysisModel = EmotionAnalysisModel.fromEntity(analysis);
      await supabaseClient
          .from('emotion_history')
          .insert(analysisModel.toMap());
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '분석 결과 저장 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<EmotionAnalysis>>> getAnalysisHistory({
    required String userId,
    String? petId,
    DateTime? startDate,
    DateTime? endDate,
    int limit = 20,
  }) async {
    try {
      var query =
          supabaseClient.from('emotion_history').select().eq('user_id', userId);

      if (petId != null) {
        query = query.eq('pet_id', petId);
      }

      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }

      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }

      final response =
          await query.order('created_at', ascending: false).limit(limit);

      final analyses = (response as List)
          .map((data) => EmotionAnalysisModel.fromJson(data))
          .toList();

      return Right(analyses);
    } catch (e) {
      return Left(
          ServerFailure(message: '히스토리 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, EmotionAnalysis>> getAnalysisById(String id) async {
    try {
      final response = await supabaseClient
          .from('emotion_history')
          .select()
          .eq('id', id)
          .maybeSingle();

      if (response == null) {
        return const Left(ServerFailure(message: '분석 결과를 찾을 수 없습니다.'));
      }

      final analysis = EmotionAnalysisModel.fromJson(response);
      return Right(analysis);
    } catch (e) {
      return Left(
          ServerFailure(message: '분석 결과 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAnalysis(String id) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      await supabaseClient.from('emotion_history').delete().eq('id', id);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '분석 결과 삭제 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Pet>> registerPet(Pet pet) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final petData = {
        'user_id': pet.userId,
        'name': pet.name,
        'type': pet.type.name,
        'breed': pet.breed,
        'birth_date': pet.birthDate?.toIso8601String(),
        'gender': pet.gender?.name,
        'avatar_url': pet.avatarUrl,
        'description': pet.description,
      };

      final response =
          await supabaseClient.from('pets').insert(petData).select().single();

      final savedPet = _petFromJson(response);
      return Right(savedPet);
    } catch (e) {
      return Left(
          ServerFailure(message: '반려동물 등록 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Pet>>> getUserPets(String userId) async {
    try {
      final response = await supabaseClient
          .from('pets')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      final pets =
          (response as List).map((data) => _petFromJson(data)).toList();

      return Right(pets);
    } catch (e) {
      return Left(
          ServerFailure(message: '반려동물 목록 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Pet>> getPetById(String petId) async {
    try {
      final response = await supabaseClient
          .from('pets')
          .select()
          .eq('id', petId)
          .maybeSingle();

      if (response == null) {
        return const Left(ServerFailure(message: '반려동물을 찾을 수 없습니다.'));
      }

      final pet = _petFromJson(response);
      return Right(pet);
    } catch (e) {
      return Left(
          ServerFailure(message: '반려동물 정보 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Pet>> updatePet(Pet pet) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final petData = {
        'name': pet.name,
        'type': pet.type.name,
        'breed': pet.breed,
        'birth_date': pet.birthDate?.toIso8601String(),
        'gender': pet.gender?.name,
        'avatar_url': pet.avatarUrl,
        'description': pet.description,
        'updated_at': DateTime.now().toIso8601String(),
      };

      await supabaseClient.from('pets').update(petData).eq('id', pet.id);
      return Right(pet);
    } catch (e) {
      return Left(
          ServerFailure(message: '반려동물 정보 업데이트 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deletePet(String petId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      await supabaseClient.from('pets').delete().eq('id', petId);
      return const Right(null);
    } catch (e) {
      return Left(
          ServerFailure(message: '반려동물 삭제 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadImage(
      File imageFile, String path) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$path/$fileName';

      await supabaseClient.storage.from('images').upload(filePath, imageFile);

      final publicUrl =
          supabaseClient.storage.from('images').getPublicUrl(filePath);

      return Right(publicUrl);
    } catch (e) {
      return Left(
          ServerFailure(message: '이미지 업로드 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, File>> processImage(File imageFile) async {
    try {
      final processedImage = await imageService.processImage(imageFile);
      return Right(processedImage);
    } catch (e) {
      return Left(
          ImageFailure(message: '이미지 처리 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, Map<String, dynamic>>> getEmotionStatistics({
    required String userId,
    String? petId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      final historyResult = await getAnalysisHistory(
        userId: userId,
        petId: petId,
        startDate: startDate,
        endDate: endDate,
        limit: 1000, // 통계를 위해 더 많은 데이터 조회
      );

      return historyResult.fold(
        (failure) => Left(failure),
        (analyses) {
          final statistics = _calculateStatistics(analyses);
          return Right(statistics);
        },
      );
    } catch (e) {
      return Left(
          ServerFailure(message: '통계 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  double _calculateConfidence(EmotionScoresModel scores) {
    final values = [
      scores.happiness,
      scores.sadness,
      scores.anxiety,
      scores.sleepiness,
      scores.curiosity,
    ];

    // 분산을 이용한 신뢰도 계산 (분산이 클수록 신뢰도가 높음)
    final mean = values.reduce((a, b) => a + b) / values.length;
    final variance =
        values.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            values.length;

    return variance.clamp(0.0, 1.0);
  }

  Map<String, dynamic> _calculateStatistics(List<EmotionAnalysis> analyses) {
    if (analyses.isEmpty) {
      return {
        'totalAnalyses': 0,
        'averageEmotions': {},
        'dominantEmotion': null,
        'emotionTrend': [],
      };
    }

    final emotionSums = {
      'happiness': 0.0,
      'sadness': 0.0,
      'anxiety': 0.0,
      'sleepiness': 0.0,
      'curiosity': 0.0,
    };

    final emotionCounts = Map<String, int>.fromIterables(
      emotionSums.keys,
      List.filled(emotionSums.length, 0),
    );

    // 감정별 평균 계산
    for (final analysis in analyses) {
      emotionSums['happiness'] =
          emotionSums['happiness']! + analysis.emotions.happiness;
      emotionSums['sadness'] =
          emotionSums['sadness']! + analysis.emotions.sadness;
      emotionSums['anxiety'] =
          emotionSums['anxiety']! + analysis.emotions.anxiety;
      emotionSums['sleepiness'] =
          emotionSums['sleepiness']! + analysis.emotions.sleepiness;
      emotionSums['curiosity'] =
          emotionSums['curiosity']! + analysis.emotions.curiosity;

      // 주요 감정 카운트
      final dominantEmotion = analysis.emotions.dominantEmotion;
      emotionCounts[dominantEmotion] =
          (emotionCounts[dominantEmotion] ?? 0) + 1;
    }

    final averageEmotions = emotionSums.map(
      (key, value) => MapEntry(key, value / analyses.length),
    );

    final dominantEmotion =
        emotionCounts.entries.reduce((a, b) => a.value > b.value ? a : b).key;

    // 시간별 트렌드 (최근 7일)
    final now = DateTime.now();
    final trend = <Map<String, dynamic>>[];

    for (int i = 6; i >= 0; i--) {
      final date = now.subtract(Duration(days: i));
      final dayStart = DateTime(date.year, date.month, date.day);
      final dayEnd = dayStart.add(const Duration(days: 1));

      final dayAnalyses = analyses
          .where((a) =>
              a.analyzedAt.isAfter(dayStart) && a.analyzedAt.isBefore(dayEnd))
          .toList();

      if (dayAnalyses.isNotEmpty) {
        final dayAverage = {
          'happiness': dayAnalyses
                  .map((a) => a.emotions.happiness)
                  .reduce((a, b) => a + b) /
              dayAnalyses.length,
          'sadness': dayAnalyses
                  .map((a) => a.emotions.sadness)
                  .reduce((a, b) => a + b) /
              dayAnalyses.length,
          'anxiety': dayAnalyses
                  .map((a) => a.emotions.anxiety)
                  .reduce((a, b) => a + b) /
              dayAnalyses.length,
          'sleepiness': dayAnalyses
                  .map((a) => a.emotions.sleepiness)
                  .reduce((a, b) => a + b) /
              dayAnalyses.length,
          'curiosity': dayAnalyses
                  .map((a) => a.emotions.curiosity)
                  .reduce((a, b) => a + b) /
              dayAnalyses.length,
        };

        trend.add({
          'date': dayStart.toIso8601String(),
          'emotions': dayAverage,
          'count': dayAnalyses.length,
        });
      }
    }

    return {
      'totalAnalyses': analyses.length,
      'averageEmotions': averageEmotions,
      'dominantEmotion': dominantEmotion,
      'emotionCounts': emotionCounts,
      'emotionTrend': trend,
    };
  }

  Pet _petFromJson(Map<String, dynamic> json) {
    return Pet(
      id: json['id'] ?? '',
      userId: json['user_id'] ?? '',
      name: json['name'] ?? '',
      type: _parseType(json['type']),
      breed: json['breed'],
      birthDate: json['birth_date'] != null
          ? DateTime.parse(json['birth_date'])
          : null,
      gender: _parseGender(json['gender']),
      avatarUrl: json['avatar_url'],
      description: json['description'],
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? DateTime.parse(json['updated_at'])
          : DateTime.now(),
    );
  }

  PetType _parseType(String? value) {
    switch (value) {
      case 'cat':
        return PetType.cat;
      default:
        return PetType.dog;
    }
  }

  PetGender? _parseGender(String? value) {
    switch (value) {
      case 'male':
        return PetGender.male;
      case 'female':
        return PetGender.female;
      default:
        return null;
    }
  }
}
