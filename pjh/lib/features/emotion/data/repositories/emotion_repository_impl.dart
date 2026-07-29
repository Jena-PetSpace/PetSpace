import 'dart:developer';
import 'dart:io';
import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/ai_history.dart';
import '../../domain/entities/emotion_analysis.dart';
import '../../domain/entities/health_analysis.dart';
import '../../../pets/domain/entities/pet.dart';
import '../../domain/repositories/emotion_repository.dart';
import '../models/emotion_analysis_model.dart';
import '../models/health_analysis_model.dart';
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
    required List<String> imagePaths,
    String? petId,
    String? petType,
    String? breed,
    String? contextNote,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure(message: '로그인이 필요합니다.'));
      }

      // 이미지 전처리 (모든 이미지)
      final processedImages = <File>[];
      for (final path in imagePaths) {
        final processed = await imageService.processImage(File(path));
        processedImages.add(processed);
      }

      // AI 감정 분석 (여러 이미지를 한 번의 API 호출로)
      // contextNote는 GeminiAIService._buildPrompt의 additionalContext로 주입된다.
      // null/빈 문자열이면 프롬프트에 아무 줄도 추가되지 않으므로 기존 동작과 동일.
      final trimmedContext = contextNote?.trim();
      final emotionScores = await aiService.analyzeEmotionFromImages(
        processedImages,
        petType: petType,
        breed: breed,
        additionalContext: (trimmedContext != null && trimmedContext.isNotEmpty)
            ? trimmedContext
            : null,
      );

      // 대표 이미지(첫 번째)를 Supabase Storage에 업로드
      final imageUrlResult = await uploadImage(
        processedImages.first,
        'emotions/${user.id}',
      );
      final resolvedImageUrl = imageUrlResult.fold(
        (l) {
          log(
            '[DEBUG] analyzeEmotion - upload FAILED: ${l.message}',
            name: 'EmotionRepo',
          );
          return '';
        },
        (r) {
          log(
            '[DEBUG] analyzeEmotion - upload SUCCESS: $r',
            name: 'EmotionRepo',
          );
          return r;
        },
      );
      final localImagePath = await imageService.saveImageToLocal(
        processedImages.first,
        'emotion_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );

      final confidence = _calculateConfidence(emotionScores);

      final analysis = EmotionAnalysisModel(
        id: '',
        userId: user.id,
        petId: petId,
        imageUrl: resolvedImageUrl,
        localImagePath: localImagePath,
        emotions: emotionScores,
        confidence: confidence,
        analyzedAt: DateTime.now(),
        memo: null,
        tags: const [],
        isSleepy: emotionScores.isSleepy,
        contextNote: (trimmedContext != null && trimmedContext.isNotEmpty)
            ? trimmedContext
            : null,
      );

      return Right(analysis);
    } catch (e) {
      return Left(
        AnalysisFailure(message: '감정 분석 중 오류가 발생했습니다: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, void>> saveAnalysis(EmotionAnalysis analysis) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final user = supabaseClient.auth.currentUser;
      String imageUrl = analysis.imageUrl;

      log(
        '[DEBUG] saveAnalysis - initial imageUrl="$imageUrl" localPath="${analysis.localImagePath}"',
        name: 'EmotionRepo',
      );

      // imageUrl이 비어있고 localImagePath가 있으면 저장 시점에 재업로드
      if (imageUrl.isEmpty && analysis.localImagePath.isNotEmpty) {
        final localFile = File(analysis.localImagePath);
        if (localFile.existsSync()) {
          log(
            '[DEBUG] saveAnalysis - re-uploading from localPath',
            name: 'EmotionRepo',
          );
          final uploadResult = await uploadImage(
            localFile,
            'emotions/${user?.id ?? 'unknown'}',
          );
          imageUrl = uploadResult.fold((_) => '', (url) => url);
          log(
            '[DEBUG] saveAnalysis - re-upload result imageUrl="$imageUrl"',
            name: 'EmotionRepo',
          );
        } else {
          log(
            '[DEBUG] saveAnalysis - localFile does NOT exist: ${analysis.localImagePath}',
            name: 'EmotionRepo',
          );
        }
      }

      log(
        '[DEBUG] saveAnalysis - final imageUrl="$imageUrl"',
        name: 'EmotionRepo',
      );

      final analysisModel = (analysis is EmotionAnalysisModel)
          ? analysis.copyWith(imageUrl: imageUrl)
          : EmotionAnalysisModel.fromEntity(
              analysis,
            ).copyWith(imageUrl: imageUrl);

      await supabaseClient
          .from('emotion_history')
          .insert(analysisModel.toMap());
      log('[DEBUG] saveAnalysis - INSERT success', name: 'EmotionRepo');
      return const Right(null);
    } catch (e) {
      log('[DEBUG] saveAnalysis - ERROR: $e', name: 'EmotionRepo');
      return Left(
        ServerFailure(message: '분석 결과 저장 중 오류가 발생했습니다: ${e.toString()}'),
      );
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

      // 🔍 임시 디버그 로그 - image_url 확인
      for (final a in analyses.take(3)) {
        log('[DEBUG] id=${a.id} imageUrl="${a.imageUrl}"', name: 'EmotionRepo');
      }

      return Right(analyses);
    } catch (e) {
      return Left(
        ServerFailure(message: '히스토리 조회 중 오류가 발생했습니다: ${e.toString()}'),
      );
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
        return const Left(NotFoundFailure(message: '이 기록을 열 수 없어요.'));
      }

      final analysis = EmotionAnalysisModel.fromJson(response);
      return Right(analysis);
    } catch (e) {
      return Left(
        ServerFailure(message: '분석 결과 조회 중 오류가 발생했습니다: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, HealthAnalysis>> getHealthAnalysisById(
    String id,
  ) async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const Left(UnauthorizedFailure(message: '로그인이 필요합니다.'));
    }
    try {
      final response = await supabaseClient
          .from('health_history')
          .select()
          .eq('id', id)
          .eq('user_id', userId)
          .maybeSingle();

      if (response == null) {
        return const Left(NotFoundFailure(message: '건강 기록을 찾을 수 없습니다.'));
      }
      return Right(HealthAnalysisModel.fromSupabaseRow(response));
    } catch (e) {
      return Left(ServerFailure(message: '건강 기록 조회 중 오류가 발생했습니다: $e'));
    }
  }

  @override
  Future<Either<Failure, EmotionAnalysis>> updateAnalysisMemo({
    required String analysisId,
    required String memo,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const Left(UnauthorizedFailure(message: '로그인이 필요합니다.'));
    }

    try {
      final response = await supabaseClient
          .from('emotion_history')
          .update({'memo': memo.trim().isEmpty ? null : memo.trim()})
          .eq('id', analysisId)
          .eq('user_id', userId)
          .select()
          .maybeSingle();
      if (response == null) {
        return const Left(NotFoundFailure(message: '수정할 기록을 찾을 수 없습니다.'));
      }
      return Right(EmotionAnalysisModel.fromJson(response));
    } catch (e) {
      return Left(ServerFailure(message: '메모 저장 중 오류가 발생했습니다: $e'));
    }
  }

  @override
  Future<Either<Failure, AiHistoryPageBatch>> getAiHistoryPage({
    required String userId,
    required AiHistoryPetScope petScope,
    required List<String> activePetIds,
    AiHistoryTypeFilter typeFilter = AiHistoryTypeFilter.all,
    AiHistoryDateRange dateRange = AiHistoryDateRange.all,
    bool healthAttentionOnly = false,
    AiHistoryCursor cursor = const AiHistoryCursor.initial(),
    int pageSize = 20,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final start = _historyRangeStart(dateRange);
      final sourceLimit =
          petScope.kind == AiHistoryPetScopeKind.unlinked ? 250 : pageSize + 1;
      var emotionRows = <Map<String, dynamic>>[];
      var healthRows = <Map<String, dynamic>>[];

      final loadEmotion =
          typeFilter != AiHistoryTypeFilter.health && !cursor.emotionExhausted;
      final loadHealth =
          typeFilter != AiHistoryTypeFilter.emotion && !cursor.healthExhausted;

      if (loadEmotion) {
        dynamic query = supabaseClient
            .from('emotion_history')
            .select()
            .eq('user_id', userId);
        if (petScope.kind == AiHistoryPetScopeKind.registered) {
          query = query.eq('pet_id', petScope.petId!);
        }
        if (start != null) {
          query = query.gte('created_at', start.toUtc().toIso8601String());
        }
        if (cursor.emotionBefore != null) {
          query = query.lt(
            'created_at',
            cursor.emotionBefore!.toUtc().toIso8601String(),
          );
        }
        final response = await query
            .order('created_at', ascending: false)
            .limit(sourceLimit);
        emotionRows = (response as List).cast<Map<String, dynamic>>();
      }

      if (loadHealth) {
        dynamic query = supabaseClient
            .from('health_history')
            .select()
            .eq('user_id', userId);
        if (petScope.kind == AiHistoryPetScopeKind.registered) {
          query = query.eq('pet_id', petScope.petId!);
        }
        if (start != null) {
          query = query.gte('created_at', start.toUtc().toIso8601String());
        }
        if (cursor.healthBefore != null) {
          query = query.lt(
            'created_at',
            cursor.healthBefore!.toUtc().toIso8601String(),
          );
        }
        final response = await query
            .order('created_at', ascending: false)
            .limit(sourceLimit);
        healthRows = (response as List).cast<Map<String, dynamic>>();
      }

      var emotionRecords = emotionRows
          .map(EmotionAnalysisModel.fromJson)
          .where((analysis) {
            if (petScope.kind != AiHistoryPetScopeKind.unlinked) return true;
            final petId = analysis.petId;
            return petId == null ||
                petId.isEmpty ||
                !activePetIds.contains(petId);
          })
          .map(AiHistoryRecord.emotion)
          .toList();
      var healthRecords = healthRows
          .map(HealthAnalysisModel.fromSupabaseRow)
          .where((analysis) {
            if (petScope.kind != AiHistoryPetScopeKind.unlinked) return true;
            final petId = analysis.petId;
            return petId == null ||
                petId.isEmpty ||
                !activePetIds.contains(petId);
          })
          .where(
            (analysis) => !healthAttentionOnly || _isAttentionHealth(analysis),
          )
          .map(AiHistoryRecord.health)
          .toList();

      final merged = [...emotionRecords, ...healthRecords]
        ..sort((a, b) => b.analyzedAt.compareTo(a.analyzedAt));
      final records = merged.take(pageSize).toList(growable: false);
      final consumedEmotion = records
          .where((record) => record.kind == AiHistoryKind.emotion)
          .toList();
      final consumedHealth = records
          .where((record) => record.kind == AiHistoryKind.health)
          .toList();

      DateTime? emotionBefore = cursor.emotionBefore;
      if (consumedEmotion.isNotEmpty) {
        emotionBefore = consumedEmotion.last.analyzedAt;
      } else if (emotionRecords.isEmpty && emotionRows.isNotEmpty) {
        emotionBefore = _rowCreatedAt(emotionRows.last);
      }

      DateTime? healthBefore = cursor.healthBefore;
      if (consumedHealth.isNotEmpty) {
        healthBefore = consumedHealth.last.analyzedAt;
      } else if (healthRecords.isEmpty && healthRows.isNotEmpty) {
        healthBefore = _rowCreatedAt(healthRows.last);
      }

      final emotionExhausted = !loadEmotion ||
          (emotionRows.length < sourceLimit &&
              consumedEmotion.length == emotionRecords.length);
      final healthExhausted = !loadHealth ||
          (healthRows.length < sourceLimit &&
              consumedHealth.length == healthRecords.length);
      final reachedScanLimit =
          petScope.kind == AiHistoryPetScopeKind.unlinked &&
              (emotionRows.length == sourceLimit ||
                  healthRows.length == sourceLimit);

      return Right(
        AiHistoryPageBatch(
          records: records,
          nextCursor: AiHistoryCursor(
            emotionBefore: emotionBefore,
            healthBefore: healthBefore,
            emotionExhausted: emotionExhausted,
            healthExhausted: healthExhausted,
          ),
          hasMore: !emotionExhausted || !healthExhausted,
          reachedUnlinkedScanLimit: reachedScanLimit,
        ),
      );
    } catch (e) {
      return Left(ServerFailure(message: 'AI 분석 기록 조회 중 오류가 발생했습니다: $e'));
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
        ServerFailure(message: '분석 결과 삭제 중 오류가 발생했습니다: ${e.toString()}'),
      );
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
        ServerFailure(message: '반려동물 등록 중 오류가 발생했습니다: ${e.toString()}'),
      );
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
        ServerFailure(message: '반려동물 목록 조회 중 오류가 발생했습니다: ${e.toString()}'),
      );
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
        ServerFailure(message: '반려동물 정보 조회 중 오류가 발생했습니다: ${e.toString()}'),
      );
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
        ServerFailure(message: '반려동물 정보 업데이트 중 오류가 발생했습니다: ${e.toString()}'),
      );
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
        ServerFailure(message: '반려동물 삭제 중 오류가 발생했습니다: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, String>> uploadImage(
    File imageFile,
    String path,
  ) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final filePath = '$path/$fileName';

      log(
        '[DEBUG] uploadImage - uploading to bucket=images path=$filePath size=${imageFile.lengthSync()}bytes',
        name: 'EmotionRepo',
      );
      await supabaseClient.storage.from('images').upload(filePath, imageFile);

      final publicUrl =
          supabaseClient.storage.from('images').getPublicUrl(filePath);

      log('[DEBUG] uploadImage - SUCCESS url=$publicUrl', name: 'EmotionRepo');
      return Right(publicUrl);
    } catch (e) {
      log('[DEBUG] uploadImage - FAILED: $e', name: 'EmotionRepo');
      return Left(
        ServerFailure(message: '이미지 업로드 중 오류가 발생했습니다: ${e.toString()}'),
      );
    }
  }

  @override
  Future<Either<Failure, File>> processImage(File imageFile) async {
    try {
      final processedImage = await imageService.processImage(imageFile);
      return Right(processedImage);
    } catch (e) {
      return Left(
        ImageFailure(message: '이미지 처리 중 오류가 발생했습니다: ${e.toString()}'),
      );
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

      return historyResult.fold((failure) => Left(failure), (analyses) {
        final statistics = _calculateStatistics(analyses);
        return Right(statistics);
      });
    } catch (e) {
      return Left(
        ServerFailure(message: '통계 조회 중 오류가 발생했습니다: ${e.toString()}'),
      );
    }
  }

  double _calculateConfidence(EmotionScoresModel scores) {
    final values = [
      scores.happiness,
      scores.calm,
      scores.excitement,
      scores.curiosity,
      scores.anxiety,
      scores.fear,
      scores.sadness,
      scores.discomfort,
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
      'calm': 0.0,
      'excitement': 0.0,
      'curiosity': 0.0,
      'anxiety': 0.0,
      'fear': 0.0,
      'sadness': 0.0,
      'discomfort': 0.0,
    };

    final emotionCounts = Map<String, int>.fromIterables(
      emotionSums.keys,
      List.filled(emotionSums.length, 0),
    );

    // 감정별 합산
    for (final analysis in analyses) {
      emotionSums['happiness'] =
          emotionSums['happiness']! + analysis.emotions.happiness;
      emotionSums['calm'] = emotionSums['calm']! + analysis.emotions.calm;
      emotionSums['excitement'] =
          emotionSums['excitement']! + analysis.emotions.excitement;
      emotionSums['curiosity'] =
          emotionSums['curiosity']! + analysis.emotions.curiosity;
      emotionSums['anxiety'] =
          emotionSums['anxiety']! + analysis.emotions.anxiety;
      emotionSums['fear'] = emotionSums['fear']! + analysis.emotions.fear;
      emotionSums['sadness'] =
          emotionSums['sadness']! + analysis.emotions.sadness;
      emotionSums['discomfort'] =
          emotionSums['discomfort']! + analysis.emotions.discomfort;

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
          .where(
            (a) =>
                a.analyzedAt.isAfter(dayStart) && a.analyzedAt.isBefore(dayEnd),
          )
          .toList();

      if (dayAnalyses.isNotEmpty) {
        double avg(double Function(EmotionAnalysis a) f) =>
            dayAnalyses.map(f).reduce((a, b) => a + b) / dayAnalyses.length;

        final dayAverage = {
          'happiness': avg((a) => a.emotions.happiness),
          'calm': avg((a) => a.emotions.calm),
          'excitement': avg((a) => a.emotions.excitement),
          'curiosity': avg((a) => a.emotions.curiosity),
          'anxiety': avg((a) => a.emotions.anxiety),
          'fear': avg((a) => a.emotions.fear),
          'sadness': avg((a) => a.emotions.sadness),
          'discomfort': avg((a) => a.emotions.discomfort),
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

  @override
  Future<Either<Failure, Map<String, dynamic>>> getBreedAverage({
    required String breed,
    int days = 30,
  }) async {
    try {
      final response = await supabaseClient.rpc(
        'get_breed_average',
        params: {'p_breed': breed, 'p_days': days},
      );
      if (response == null) {
        return const Right({'count': 0});
      }
      return Right(Map<String, dynamic>.from(response as Map));
    } catch (e) {
      // RPC가 없거나 에러 → 빈 데이터 반환
      return const Right({'count': 0});
    }
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

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getLatestHealthByArea({
    required String userId,
    String? petId,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요'));
      }
      final result = await supabaseClient.rpc(
        'get_latest_health_by_area',
        params: {'p_user_id': userId, 'p_pet_id': petId},
      );
      return Right((result as List).cast<Map<String, dynamic>>());
    } catch (e) {
      return Left(ServerFailure(message: '건강 현황 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getHealthHistory(
    String userId,
  ) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요'));
      }
      final result = await supabaseClient
          .from('health_history')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: false);
      return Right((result as List).cast<Map<String, dynamic>>());
    } catch (e) {
      return Left(ServerFailure(message: '건강 이력 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<Map<String, dynamic>>>> getEmotionTimeline({
    required String petId,
    int days = 30,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요'));
      }
      final response = await supabaseClient.rpc(
        'get_emotion_timeline',
        params: {'p_pet_id': petId, 'p_days': days},
      );
      return Right((response as List).cast<Map<String, dynamic>>());
    } catch (e) {
      return Left(ServerFailure(message: '감정 타임라인 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> canAccessOwnedPet(String petId) async {
    final userId = supabaseClient.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return const Left(UnauthorizedFailure(message: '로그인이 필요합니다.'));
    }
    if (petId.isEmpty) return const Right(false);

    try {
      final row = await supabaseClient
          .from('pets')
          .select('id')
          .eq('id', petId)
          .eq('user_id', userId)
          .maybeSingle();
      return Right(row != null);
    } catch (e) {
      return Left(ServerFailure(message: '반려동물 접근 권한 확인 중 오류가 발생했습니다: $e'));
    }
  }

  @override
  Future<Either<Failure, void>> saveHealthAnalysis({
    required String userId,
    required List<String> imagePathsOrUrls,
    required Map<String, dynamic> resultJson,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요'));
      }
      // 로컬 경로 → Storage 업로드, URL 이면 그대로
      final uploadedUrls = <String>[];
      for (int i = 0; i < imagePathsOrUrls.length; i++) {
        final p = imagePathsOrUrls[i];
        if (p.startsWith('http')) {
          uploadedUrls.add(p);
          continue;
        }
        final file = File(p);
        if (!await file.exists()) continue;
        final storagePath =
            'health/$userId/${DateTime.now().millisecondsSinceEpoch}_$i.jpg';
        await supabaseClient.storage.from('images').uploadBinary(
              storagePath,
              await file.readAsBytes(),
              fileOptions: const FileOptions(contentType: 'image/jpeg'),
            );
        final url =
            supabaseClient.storage.from('images').getPublicUrl(storagePath);
        uploadedUrls.add(url);
      }

      final payload = Map<String, dynamic>.from(resultJson);
      payload['image_urls'] = uploadedUrls;
      await supabaseClient.from('health_history').insert(payload);
      return const Right(null);
    } catch (e) {
      return Left(ServerFailure(message: '건강 분석 저장 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<EmotionAnalysis>>> getAnalysesByPet({
    required String petId,
    int limit = 20,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
      }
      final response = await supabaseClient
          .from('emotion_history')
          .select()
          .eq('pet_id', petId)
          .order('created_at', ascending: false)
          .limit(limit);
      final analyses = (response as List)
          .map((data) => EmotionAnalysisModel.fromJson(data) as EmotionAnalysis)
          .toList();
      return Right(analyses);
    } catch (e) {
      return Left(ServerFailure(message: '감정 기록 조회 중 오류: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String?>> getEmotionComparisonInsight({
    required String petId,
    required String emotion,
    required num value,
    int days = 7,
  }) async {
    try {
      if (!await networkInfo.isConnected) {
        return const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요'));
      }
      final response = await supabaseClient.rpc(
        'get_emotion_timeline',
        params: {'p_pet_id': petId, 'p_days': days},
      );
      final entries = response as List;
      if (entries.isEmpty) return const Right(null);

      final avgKey = '${emotion}_avg';
      final avgs = entries
          .map((e) => (e[avgKey] as num?)?.toDouble() ?? 0.0)
          .where((v) => v > 0)
          .toList();
      if (avgs.isEmpty) return const Right(null);

      final avg = avgs.reduce((a, b) => a + b) / avgs.length;
      final diff = ((value.toDouble() - avg) * 100).round();
      if (diff.abs() < 5) return const Right('지난 7일 평균과 비슷해요');
      if (diff > 0) return Right('지난 7일 평균보다 $diff% 높아요');
      return Right('지난 7일 평균보다 ${diff.abs()}% 낮아요');
    } catch (e) {
      return Left(
        ServerFailure(message: '감정 비교 조회 중 오류가 발생했습니다: ${e.toString()}'),
      );
    }
  }
}

DateTime? _historyRangeStart(AiHistoryDateRange range) {
  if (range == AiHistoryDateRange.all) return null;
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final days = switch (range) {
    AiHistoryDateRange.last7Days => 7,
    AiHistoryDateRange.last30Days => 30,
    AiHistoryDateRange.last90Days => 90,
    AiHistoryDateRange.all => 0,
  };
  return today.subtract(Duration(days: days - 1));
}

DateTime _rowCreatedAt(Map<String, dynamic> row) {
  final value = row['created_at'];
  if (value is DateTime) return value.toLocal();
  if (value is String) return DateTime.parse(value).toLocal();
  return DateTime.fromMillisecondsSinceEpoch(0);
}

bool _isAttentionHealth(HealthAnalysis analysis) {
  return analysis.requiresReview;
}
