import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/pet_repository.dart';

class SetSelectedPetId {
  final PetRepository repository;

  const SetSelectedPetId(this.repository);

  Future<Either<Failure, String?>> call(String? petId) =>
      repository.setSelectedPetId(petId);
}
