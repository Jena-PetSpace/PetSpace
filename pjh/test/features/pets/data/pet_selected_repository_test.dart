import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:meong_nyang_diary/core/network/network_info.dart';
import 'package:meong_nyang_diary/core/services/image_upload_service.dart';
import 'package:meong_nyang_diary/features/pets/data/repositories/pet_repository_impl.dart';

class _MockNetworkInfo extends Mock implements NetworkInfo {}

class _MockSupabaseClient extends Mock implements SupabaseClient {}

class _MockImageUploadService extends Mock implements ImageUploadService {}

class _SelectedPetRepository extends PetRepositoryImpl {
  _SelectedPetRepository({
    required super.supabaseClient,
    required super.networkInfo,
    required super.imageUploadService,
  });

  Object? response;
  Object? error;
  String? functionName;
  Map<String, dynamic>? params;

  @override
  Future<dynamic> callRpc(
    String functionName, {
    Map<String, dynamic>? params,
  }) async {
    this.functionName = functionName;
    this.params = params;
    if (error != null) throw error!;
    return response;
  }
}

void main() {
  late _MockNetworkInfo network;
  late _SelectedPetRepository repository;

  setUp(() {
    network = _MockNetworkInfo();
    when(() => network.isConnected).thenAnswer((_) async => true);
    repository = _SelectedPetRepository(
      supabaseClient: _MockSupabaseClient(),
      networkInfo: network,
      imageUploadService: _MockImageUploadService(),
    );
  });

  test('대표 id 조회는 caller id 없이 고정 RPC를 호출한다', () async {
    repository.response = 'pet-2';

    final result = await repository.getSelectedPetId();

    expect(result.getOrElse(() => null), 'pet-2');
    expect(repository.functionName, 'get_my_selected_pet_id');
    expect(repository.params, isNull);
  });

  test('대표 변경은 pet id만 전송하며 null 해제도 지원한다', () async {
    repository.response = 'pet-3';
    final selected = await repository.setSelectedPetId('pet-3');
    expect(selected.getOrElse(() => null), 'pet-3');
    expect(repository.functionName, 'set_my_selected_pet_id');
    expect(repository.params, {'p_pet_id': 'pet-3'});

    repository.response = null;
    final cleared = await repository.setSelectedPetId(null);
    expect(cleared.isRight(), isTrue);
    expect(repository.params, {'p_pet_id': null});
  });

  test('RPC 원문 오류는 공개 Failure에 노출하지 않는다', () async {
    repository.error = StateError('token=private https://db.example');

    final result = await repository.setSelectedPetId('pet-1');

    result.fold(
      (failure) {
        expect(failure.message, '대표 반려동물을 변경하지 못했어요.');
        expect(failure.message, isNot(contains('token')));
        expect(failure.message, isNot(contains('https://')));
      },
      (_) => fail('failure expected'),
    );
  });
}
