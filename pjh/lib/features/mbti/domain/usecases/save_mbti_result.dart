import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/pet_mbti_result.dart';
import '../repositories/mbti_repository.dart';

class SaveMbtiResult implements UseCase<PetMbtiResult, SaveMbtiResultParams> {
  final MbtiRepository repository;

  SaveMbtiResult(this.repository);

  @override
  Future<Either<Failure, PetMbtiResult>> call(SaveMbtiResultParams params) {
    return repository.saveResult(params.result);
  }
}

class SaveMbtiResultParams extends Equatable {
  final PetMbtiResult result;

  const SaveMbtiResultParams({required this.result});

  @override
  List<Object?> get props => [result];
}
