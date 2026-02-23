import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

class GetUserPets implements UseCase<List<Pet>, String> {
  final PetRepository repository;

  GetUserPets(this.repository);

  @override
  Future<Either<Failure, List<Pet>>> call(String userId) async {
    return await repository.getUserPets(userId);
  }
}