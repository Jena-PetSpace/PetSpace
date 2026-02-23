import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

class UpdatePet implements UseCase<Pet, Pet> {
  final PetRepository repository;

  UpdatePet(this.repository);

  @override
  Future<Either<Failure, Pet>> call(Pet pet) async {
    return await repository.updatePet(pet);
  }
}