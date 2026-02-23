import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/pet.dart';

abstract class PetRepository {
  Future<Either<Failure, List<Pet>>> getUserPets(String userId);
  Future<Either<Failure, Pet>> addPet(Pet pet);
  Future<Either<Failure, Pet>> updatePet(Pet pet);
  Future<Either<Failure, void>> deletePet(String petId);
  Future<Either<Failure, Pet>> getPetById(String petId);
}