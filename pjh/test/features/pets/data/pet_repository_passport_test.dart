import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/core/services/image_upload_service.dart';
import 'package:meong_nyang_diary/features/pets/data/repositories/pet_repository_impl.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/domain/services/passport_number_generator.dart';

class MockNetworkInfo extends Mock implements NetworkInfo {}

class MockSupabaseClient extends Mock implements SupabaseClient {}

class MockImageUploadService extends Mock implements ImageUploadService {}

/// insertPetRow 를 가로채서 여권번호 재시도 로직만 단위 테스트하는 테스트용 서브클래스.
/// - [conflictUntil]: 이 횟수만큼은 23505(UNIQUE 위반)을 던지고, 이후 성공.
/// - 성공 시 전달된 insertJson 을 그대로 row 로 반환(passport_no 확인용).
class _StubPetRepository extends PetRepositoryImpl {
  _StubPetRepository({
    required super.supabaseClient,
    required super.networkInfo,
    required super.imageUploadService,
    required super.passportNumberGenerator,
    this.conflictUntil = 0,
  });

  final int conflictUntil;
  int attempts = 0;
  final List<String?> seenPassportNos = [];

  @override
  Future<Map<String, dynamic>> insertPetRow(
      Map<String, dynamic> insertJson) async {
    attempts++;
    seenPassportNos.add(insertJson['passport_no'] as String?);
    if (attempts <= conflictUntil) {
      throw const PostgrestException(
          message: 'duplicate key value violates unique constraint',
          code: '23505');
    }
    // 성공: 최소한의 유효 row 반환(fromJson 통과용 필드 채움).
    return {
      'id': 'pet-test-id',
      'user_id': insertJson['user_id'],
      'name': insertJson['name'],
      'type': insertJson['type'],
      'breed': insertJson['breed'],
      'birth_date': insertJson['birth_date'],
      'gender': insertJson['gender'],
      'avatar_url': insertJson['avatar_url'],
      'description': insertJson['description'],
      'created_at': '2026-06-08T00:00:00.000Z',
      'updated_at': '2026-06-08T00:00:00.000Z',
      'passport_no': insertJson['passport_no'],
      'passport_surname': insertJson['passport_surname'],
      'passport_given_name': insertJson['passport_given_name'],
      'name_hanguel': insertJson['name_hanguel'],
      'country_code': insertJson['country_code'] ?? 'KOR',
    };
  }
}

Pet _basePet({String? passportNo}) {
  final now = DateTime(2026, 6, 8);
  return Pet(
    id: 'local-id',
    userId: 'user-1',
    name: '몽이',
    type: PetType.dog,
    createdAt: now,
    updatedAt: now,
    passportNo: passportNo,
  );
}

void main() {
  late MockNetworkInfo network;
  late MockSupabaseClient supabase;
  late MockImageUploadService imageService;

  setUp(() {
    network = MockNetworkInfo();
    supabase = MockSupabaseClient();
    imageService = MockImageUploadService();
    when(() => network.isConnected).thenAnswer((_) async => true);
  });

  group('addPet 여권번호 생성', () {
    test('신규 등록 → 형식에 맞는 여권번호가 생성·저장된다', () async {
      final repo = _StubPetRepository(
        supabaseClient: supabase,
        networkInfo: network,
        imageUploadService: imageService,
        passportNumberGenerator: PassportNumberGenerator(random: Random(1)),
      );

      final result = await repo.addPet(_basePet());

      expect(result.isRight(), true);
      result.fold((_) => fail('Left'), (pet) {
        expect(PassportNumberGenerator.isValid(pet.passportNo), isTrue,
            reason: '생성된 여권번호 형식 위반: ${pet.passportNo}');
      });
      expect(repo.attempts, 1);
    });

    test('UNIQUE 충돌 → 번호 재생성 후 재시도하여 성공한다', () async {
      final repo = _StubPetRepository(
        supabaseClient: supabase,
        networkInfo: network,
        imageUploadService: imageService,
        passportNumberGenerator: PassportNumberGenerator(random: Random(2)),
        conflictUntil: 2, // 2번 충돌 후 3번째 성공
      );

      final result = await repo.addPet(_basePet());

      expect(result.isRight(), true);
      expect(repo.attempts, 3, reason: '충돌 2회 + 성공 1회 = 3회 시도');
      // 매 시도마다 번호가 재생성되어야 함(앞 2개는 충돌, 마지막이 저장됨)
      final nos = repo.seenPassportNos;
      expect(nos.length, 3);
      expect(nos.toSet().length, 3, reason: '시도마다 서로 다른 번호 재생성');
      for (final no in nos) {
        expect(PassportNumberGenerator.isValid(no), isTrue);
      }
    });

    test('재시도 한도(5회) 초과 → 실패(Left) 반환', () async {
      final repo = _StubPetRepository(
        supabaseClient: supabase,
        networkInfo: network,
        imageUploadService: imageService,
        passportNumberGenerator: PassportNumberGenerator(random: Random(3)),
        conflictUntil: 999, // 항상 충돌
      );

      final result = await repo.addPet(_basePet());

      expect(result.isLeft(), true);
      expect(repo.attempts, 5, reason: '최대 5회까지만 시도');
    });

    test('수정/재등록(번호 이미 있음) → 기존 번호 유지, 재생성 안 함', () async {
      const existing = 'PZZ98765';
      final repo = _StubPetRepository(
        supabaseClient: supabase,
        networkInfo: network,
        imageUploadService: imageService,
        passportNumberGenerator: PassportNumberGenerator(random: Random(4)),
      );

      final result = await repo.addPet(_basePet(passportNo: existing));

      expect(result.isRight(), true);
      expect(repo.attempts, 1);
      expect(repo.seenPassportNos.single, existing,
          reason: '기존 번호가 그대로 저장되어야 함');
      result.fold((_) => fail('Left'), (pet) {
        expect(pet.passportNo, existing);
      });
    });

    test('번호 이미 있고 UNIQUE 충돌 → 재생성하지 않고 실패(번호 보존)', () async {
      const existing = 'PZZ98765';
      final repo = _StubPetRepository(
        supabaseClient: supabase,
        networkInfo: network,
        imageUploadService: imageService,
        passportNumberGenerator: PassportNumberGenerator(random: Random(5)),
        conflictUntil: 1, // 1회 충돌
      );

      final result = await repo.addPet(_basePet(passportNo: existing));

      // 번호를 직접 부여한 경우 재시도하지 않으므로 충돌이 그대로 실패로 이어짐.
      expect(result.isLeft(), true);
      expect(repo.attempts, 1, reason: '재생성 없이 1회만 시도');
    });
  });
}
