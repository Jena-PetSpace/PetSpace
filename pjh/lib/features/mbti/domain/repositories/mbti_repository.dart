import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/pet_mbti_result.dart';

abstract class MbtiRepository {
  /// 검사 결과를 새 row 로 INSERT 누적(덮어쓰기 아님)하고,
  /// pets.current_mbti_type / current_mbti_updated_at 캐시를 최신으로 갱신한다.
  /// 저장된 결과(서버 생성 id/created_at 포함)를 반환.
  Future<Either<Failure, PetMbtiResult>> saveResult(PetMbtiResult result);

  /// 해당 pet 의 최신 결과 1건(created_at DESC LIMIT 1). 없으면 Right(null).
  Future<Either<Failure, PetMbtiResult?>> getLatestResult(String petId);

  /// 해당 pet 의 결과 이력(created_at DESC). 추이/이력 화면용.
  Future<Either<Failure, List<PetMbtiResult>>> getResultHistory(
    String petId, {
    int limit = 20,
  });

  /// 특정 결과 1건 삭제(이력 관리용).
  Future<Either<Failure, void>> deleteResult(String resultId);
}
