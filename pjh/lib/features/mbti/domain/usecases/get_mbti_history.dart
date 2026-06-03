import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/pet_mbti_result.dart';
import '../repositories/mbti_repository.dart';

class GetMbtiHistory
    implements UseCase<List<PetMbtiResult>, GetMbtiHistoryParams> {
  final MbtiRepository repository;

  GetMbtiHistory(this.repository);

  @override
  Future<Either<Failure, List<PetMbtiResult>>> call(
      GetMbtiHistoryParams params) {
    return repository.getResultHistory(params.petId, limit: params.limit);
  }
}

class GetMbtiHistoryParams extends Equatable {
  final String petId;
  final int limit;

  const GetMbtiHistoryParams({required this.petId, this.limit = 20});

  @override
  List<Object?> get props => [petId, limit];
}
