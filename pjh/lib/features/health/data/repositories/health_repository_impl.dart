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
    } on PostgrestException {
      return const Left(
        DatabaseFailure(message: ErrorMessages.healthRecordLoadFailed),
      );
    } catch (_) {
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
    } on PostgrestException {
      return const Left(
        DatabaseFailure(message: ErrorMessages.healthRecordCreateFailed),
      );
    } catch (_) {
      return const Left(
        GeneralFailure(message: ErrorMessages.healthRecordCreateFailed),
      );
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
    } on PostgrestException {
      return const Left(
        DatabaseFailure(message: ErrorMessages.healthRecordUpdateFailed),
      );
    } catch (_) {
      return const Left(
        GeneralFailure(message: ErrorMessages.healthRecordUpdateFailed),
      );
    }
  }

  @override
  Future<Either<Failure, void>> deleteHealthRecord(String recordId) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      final response = await supabaseClient
          .from('health_records')
          .delete()
          .eq('id', recordId)
          .select('id');
      if ((response as List).isEmpty) {
        return const Left(
          DatabaseFailure(message: ErrorMessages.healthRecordDeleteFailed),
        );
      }

      return const Right(null);
    } on PostgrestException {
      return const Left(
        DatabaseFailure(message: ErrorMessages.healthRecordDeleteFailed),
      );
    } catch (_) {
      return const Left(
        GeneralFailure(message: ErrorMessages.healthRecordDeleteFailed),
      );
    }
  }

  @override
  Future<Either<Failure, List<HealthRecord>>> getUpcomingRecords({
    required String userId,
    required String petId,
    int daysAhead = 30,
  }) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: ErrorMessages.networkError));
    }

    try {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final futureDate = today.add(Duration(days: daysAhead));
      final start = today.toIso8601String().split('T').first;
      final end = futureDate.toIso8601String().split('T').first;

      final response = await supabaseClient
          .from('health_records')
          .select()
          .eq('user_id', userId)
          .eq('pet_id', petId)
          .neq('status', 'cancelled')
          .or(
            'and(next_date.gte.$start,next_date.lte.$end),'
            'and(next_date.is.null,status.eq.scheduled,'
            'record_date.gte.$start,record_date.lte.$end)',
          );

      final byId = <String, HealthRecord>{};
      for (final record in (response as List).map((json) =>
          HealthRecordModel.fromJson(Map<String, dynamic>.from(json)))) {
        final due = record.dueDate;
        if (due == null) continue;
        final dueDay = DateTime(due.year, due.month, due.day);
        if (dueDay.isBefore(today) || dueDay.isAfter(futureDate)) continue;
        byId[record.id] = record;
      }

      final records = byId.values.toList()
        ..sort((left, right) {
          final dateOrder = left.dueDate!.compareTo(right.dueDate!);
          return dateOrder != 0 ? dateOrder : left.id.compareTo(right.id);
        });

      return Right(records);
    } on PostgrestException {
      return const Left(
        DatabaseFailure(message: ErrorMessages.healthUpcomingLoadFailed),
      );
    } catch (_) {
      return const Left(
        GeneralFailure(message: ErrorMessages.healthUpcomingLoadFailed),
      );
    }
  }
}
