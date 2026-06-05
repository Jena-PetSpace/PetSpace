import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/pet_mbti_result.dart';
import '../repositories/mbti_repository.dart';

/// 해당 pet 의 최신 결과 1건(created_at DESC LIMIT 1). 없으면 Right(null).
class GetLatestMbtiResult implements UseCase<PetMbtiResult?, StringParams> {
  final MbtiRepository repository;

  GetLatestMbtiResult(this.repository);

  @override
  Future<Either<Failure, PetMbtiResult?>> call(StringParams params) {
    return repository.getLatestResult(params.value);
  }
}
