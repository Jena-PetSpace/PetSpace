import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/error/error_messages.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/health_record.dart';
import '../../domain/repositories/health_repository.dart';
import '../models/health_record_model.dart';

class HealthRepositoryImpl implements HealthRepository {
  final SupabaseClient supabaseClient;
  final NetworkInfo networkInfo;

  HealthRepositoryImpl({
    required this.supabaseClient,
    required this.networkInfo,
  });

  @override
  Future<Either<Failure, List<HealthRecord>>> getHealthRecords({
    required String petId,
    HealthRecordType? type,
    int limit = 50,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      var query =
          supabaseClient.from('health_records').select().eq('pet_id', petId);

      if (type != null) {
        query = query.eq('record_type', type.name);
      }

      final response =
          await query.order('record_date', ascending: false).limit(limit);

      final records = (response as List)
          .map((json) =>
              HealthRecordModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      return Right(records);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return const Left(
          GeneralFailure(message: ErrorMessages.healthRecordLoadFailed));
    }
  }

  @override
  Future<Either<Failure, HealthRecord>> addHealthRecord(
      HealthRecord record) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure(message: '로그인이 필요합니다.'));
      }

      final model = HealthRecordModel.fromEntity(record);
      final json = model.toJson();
      json['user_id'] = user.id;

      final response = await supabaseClient
          .from('health_records')
          .insert(json)
          .select()
          .single();

      return Right(
          HealthRecordModel.fromJson(Map<String, dynamic>.from(response)));
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return Left(GeneralFailure(message: '건강 기록 추가 실패: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, HealthRecord>> updateHealthRecord(
      HealthRecord record) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      final model = HealthRecordModel.fromEntity(record);
      final response = await supabaseClient
          .from('health_records')
          .update(model.toJson())
          .eq('id', record.id)
          .select()
          .single();

      return Right(
          HealthRecordModel.fromJson(Map<String, dynamic>.from(response)));
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return Left(GeneralFailure(message: '건강 기록 수정 실패: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteHealthRecord(String recordId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      await supabaseClient.from('health_records').delete().eq('id', recordId);

      return const Right(null);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return Left(GeneralFailure(message: '건강 기록 삭제 실패: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, List<HealthRecord>>> getUpcomingRecords({
    required String userId,
    int daysAhead = 30,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      final now = DateTime.now();
      final futureDate = now.add(Duration(days: daysAhead));

      final response = await supabaseClient
          .from('health_records')
          .select()
          .eq('user_id', userId)
          .eq('status', 'scheduled')
          .gte('record_date', now.toIso8601String().split('T').first)
          .lte('record_date', futureDate.toIso8601String().split('T').first)
          .order('record_date', ascending: true);

      final records = (response as List)
          .map((json) =>
              HealthRecordModel.fromJson(Map<String, dynamic>.from(json)))
          .toList();

      return Right(records);
    } on PostgrestException catch (e) {
      return Left(DatabaseFailure(message: 'DB 오류: ${e.message}'));
    } catch (e) {
      return Left(GeneralFailure(message: '예정 기록 조회 실패: ${e.toString()}'));
    }
  }
}
