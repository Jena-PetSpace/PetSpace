import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../repositories/pet_repository.dart';

class GetSelectedPetId {
  final PetRepository repository;

  const GetSelectedPetId(this.repository);

  Future<Either<Failure, String?>> call() => repository.getSelectedPetId();
}
