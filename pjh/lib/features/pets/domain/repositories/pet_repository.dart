import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/pet.dart';

abstract class PetRepository {
  Future<Either<Failure, List<Pet>>> getUserPets(String userId);
  Future<Either<Failure, Pet>> addPet(Pet pet);
  Future<Either<Failure, Pet>> updatePet(Pet pet);
  Future<Either<Failure, void>> deletePet(String petId);
  Future<Either<Failure, Pet>> getPetById(String petId);

  /// 공개 프로필용 반려동물 상세 (owner 정보 JOIN 포함).
  /// Pet entity 가 owner_name / owner_photo 필드를 포함하지 않아 raw Map 반환.
  Future<Either<Failure, Map<String, dynamic>?>> getPetDetail(String petId);
}
