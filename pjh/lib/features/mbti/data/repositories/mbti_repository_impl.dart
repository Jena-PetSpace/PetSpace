import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/error_messages.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/pet_mbti_result.dart';
import '../../domain/repositories/mbti_repository.dart';
import '../models/pet_mbti_result_model.dart';

class MbtiRepositoryImpl implements MbtiRepository {
  final SupabaseClient supabaseClient;
  final NetworkInfo networkInfo;

  MbtiRepositoryImpl({
    required this.supabaseClient,
    required this.networkInfo,
  });

  static const String _resultsTable = 'pet_mbti_results';
  static const String _petsTable = 'pets';

  @override
  Future<Either<Failure, PetMbtiResult>> saveResult(
      PetMbtiResult result) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure(message: ErrorMessages.authRequired));
      }

      final model = PetMbtiResultModel.fromEntity(result);

      // 1) 이력 INSERT (덮어쓰기 아님 — 검사마다 새 row 누적)
      final inserted = await supabaseClient
          .from(_resultsTable)
          .insert(model.toInsertJson())
          .select()
          .single();

      final saved =
          PetMbtiResultModel.fromJson(Map<String, dynamic>.from(inserted));

      // 2) pets 캐시 컬럼 최신 갱신 (빠른 표시용). RLS 로 본인 pet 만 갱신됨.
      //    캐시 갱신 실패가 저장 성공을 무효화하지 않도록 best-effort 처리.
      try {
        await supabaseClient.from(_petsTable).update({
          'current_mbti_type': saved.typeCode,
          'current_mbti_updated_at': saved.createdAt.toIso8601String(),
        }).eq('id', saved.petId);
      } catch (_) {
        // 캐시 갱신 실패는 무시 — 원천 데이터(pet_mbti_results)는 이미 저장됨.
      }

      return Right(saved);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return const Left(
          GeneralFailure(message: ErrorMessages.mbtiResultSaveFailed));
    }
  }

  @override
  Future<Either<Failure, PetMbtiResult?>> getLatestResult(String petId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      // 이력 누적 구조이므로 최신 1건은 created_at DESC LIMIT 1 로 조회.
      final response = await supabaseClient
          .from(_resultsTable)
          .select()
          .eq('pet_id', petId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return const Right(null);

      return Right(
          PetMbtiResultModel.fromJson(Map<String, dynamic>.from(response)));
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return const Left(
          GeneralFailure(message: ErrorMessages.mbtiResultLoadFailed));
    }
  }

  @override
  Future<Either<Failure, List<PetMbtiResult>>> getResultHistory(
    String petId, {
    int limit = 20,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      final response = await supabaseClient
          .from(_resultsTable)
          .select()
          .eq('pet_id', petId)
          .order('created_at', ascending: false)
          .limit(limit);

      final results = (response as List)
          .map((json) =>
              PetMbtiResultModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      return Right(results);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return const Left(
          GeneralFailure(message: ErrorMessages.mbtiResultLoadFailed));
    }
  }

  @override
  Future<Either<Failure, void>> deleteResult(String resultId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      await supabaseClient.from(_resultsTable).delete().eq('id', resultId);
      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return const Left(
          GeneralFailure(message: ErrorMessages.mbtiResultDeleteFailed));
    }
  }
}
