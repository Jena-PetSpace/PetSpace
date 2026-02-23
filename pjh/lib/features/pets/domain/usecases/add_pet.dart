import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/pet.dart';
import '../repositories/pet_repository.dart';

class AddPet implements UseCase<Pet, Pet> {
  final PetRepository repository;

  AddPet(this.repository);

  @override
  Future<Either<Failure, Pet>> call(Pet pet) async {
    return await repository.addPet(pet);
  }
}