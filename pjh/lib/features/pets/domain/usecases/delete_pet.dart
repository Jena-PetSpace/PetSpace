import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/pet_repository.dart';

class DeletePet implements UseCase<void, String> {
  final PetRepository repository;

  DeletePet(this.repository);

  @override
  Future<Either<Failure, void>> call(String petId) async {
    return await repository.deletePet(petId);
  }
}