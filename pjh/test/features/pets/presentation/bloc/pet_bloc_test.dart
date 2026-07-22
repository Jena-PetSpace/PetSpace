import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/pets/domain/entities/pet.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/add_pet.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/delete_pet.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/get_selected_pet_id.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/get_user_pets.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/set_selected_pet_id.dart';
import 'package:meong_nyang_diary/features/pets/domain/usecases/update_pet.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_bloc.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_event.dart';
import 'package:meong_nyang_diary/features/pets/presentation/bloc/pet_state.dart';

class _MockGetUserPets extends Mock implements GetUserPets {}

class _MockAddPet extends Mock implements AddPet {}

class _MockUpdatePet extends Mock implements UpdatePet {}

class _MockDeletePet extends Mock implements DeletePet {}

class _MockGetSelectedPetId extends Mock implements GetSelectedPetId {}

class _MockSetSelectedPetId extends Mock implements SetSelectedPetId {}

void main() {
  late _MockGetUserPets getUserPets;
  late _MockAddPet addPet;
  late _MockUpdatePet updatePet;
  late _MockDeletePet deletePet;
  late _MockGetSelectedPetId getSelectedPetId;
  late _MockSetSelectedPetId setSelectedPetId;

  Pet pet(String id) => Pet(
        id: id,
        userId: 'user-1',
        name: id == 'pet-1' ? '보리' : '호두',
        type: PetType.dog,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  PetBloc buildBloc() => PetBloc(
        getUserPets: getUserPets,
        addPet: addPet,
        updatePet: updatePet,
        deletePet: deletePet,
        getSelectedPetId: getSelectedPetId,
        setSelectedPetId: setSelectedPetId,
        currentUserIdProvider: () => 'user-1',
      );

  setUp(() {
    getUserPets = _MockGetUserPets();
    addPet = _MockAddPet();
    updatePet = _MockUpdatePet();
    deletePet = _MockDeletePet();
    getSelectedPetId = _MockGetSelectedPetId();
    setSelectedPetId = _MockSetSelectedPetId();
  });

  blocTest<PetBloc, PetState>(
    '재실행 조회는 서버에 저장된 대표 pet을 복원한다',
    setUp: () {
      when(() => getUserPets('user-1'))
          .thenAnswer((_) async => Right([pet('pet-1'), pet('pet-2')]));
      when(() => getSelectedPetId())
          .thenAnswer((_) async => const Right('pet-2'));
    },
    build: buildBloc,
    act: (bloc) => bloc.add(LoadUserPets()),
    expect: () => [
      isA<PetLoading>(),
      isA<PetLoaded>()
          .having((state) => state.selectedPet?.id, 'selected id', 'pet-2')
          .having(
            (state) => state.selectionStatus,
            'selection status',
            PetSelectionStatus.idle,
          ),
    ],
  );

  blocTest<PetBloc, PetState>(
    '대표 변경은 pending 동안 기존 대표를 유지하고 RPC 성공 뒤 반영한다',
    setUp: () {
      when(() => setSelectedPetId('pet-2'))
          .thenAnswer((_) async => const Right('pet-2'));
    },
    build: buildBloc,
    seed: () => PetLoaded(
      pets: [pet('pet-1'), pet('pet-2')],
      selectedPet: pet('pet-1'),
    ),
    act: (bloc) => bloc.add(SelectPet(pet('pet-2'))),
    expect: () => [
      isA<PetLoaded>()
          .having(
            (state) => state.selectionStatus,
            'pending',
            PetSelectionStatus.pending,
          )
          .having((state) => state.selectedPet?.id, 'old selected', 'pet-1'),
      isA<PetLoaded>()
          .having(
            (state) => state.selectionStatus,
            'success',
            PetSelectionStatus.success,
          )
          .having((state) => state.selectedPet?.id, 'new selected', 'pet-2'),
    ],
  );

  blocTest<PetBloc, PetState>(
    '대표 변경 실패는 기존 대표와 목록을 보존한다',
    setUp: () {
      when(() => setSelectedPetId('pet-2')).thenAnswer(
        (_) async => const Left(
          DatabaseFailure(message: '대표 반려동물을 변경하지 못했어요.'),
        ),
      );
    },
    build: buildBloc,
    seed: () => PetLoaded(
      pets: [pet('pet-1'), pet('pet-2')],
      selectedPet: pet('pet-1'),
    ),
    act: (bloc) => bloc.add(SelectPet(pet('pet-2'))),
    expect: () => [
      isA<PetLoaded>().having(
        (state) => state.selectionStatus,
        'pending',
        PetSelectionStatus.pending,
      ),
      isA<PetLoaded>()
          .having(
            (state) => state.selectionStatus,
            'failure',
            PetSelectionStatus.failure,
          )
          .having((state) => state.selectedPet?.id, 'preserved', 'pet-1')
          .having((state) => state.pets.length, 'pets', 2),
    ],
  );

  blocTest<PetBloc, PetState>(
    '정보 수정 실패는 오류 뒤 기존 목록과 대표를 복원해 재시도를 허용한다',
    setUp: () {
      when(() => updatePet(pet('pet-1'))).thenAnswer(
        (_) async => const Left(
          DatabaseFailure(message: '반려동물 정보를 수정하지 못했어요.'),
        ),
      );
    },
    build: buildBloc,
    seed: () => PetLoaded(
      pets: [pet('pet-1'), pet('pet-2')],
      selectedPet: pet('pet-1'),
    ),
    act: (bloc) => bloc.add(UpdatePetEvent(pet('pet-1'))),
    expect: () => [
      isA<PetLoading>(),
      isA<PetError>().having(
        (state) => state.message,
        'safe error',
        '반려동물 정보를 수정하지 못했어요.',
      ),
      isA<PetLoaded>()
          .having((state) => state.pets.length, 'preserved pets', 2)
          .having(
              (state) => state.selectedPet?.id, 'preserved selected', 'pet-1'),
    ],
  );

  blocTest<PetBloc, PetState>(
    '첫 등록은 대표 RPC가 같은 id를 확정한 뒤에만 대표로 반영한다',
    setUp: () {
      when(() => addPet(pet('pet-1')))
          .thenAnswer((_) async => Right(pet('pet-1')));
      when(() => setSelectedPetId('pet-1'))
          .thenAnswer((_) async => const Right(null));
    },
    build: buildBloc,
    seed: () => const PetLoaded(pets: []),
    act: (bloc) => bloc.add(AddPetEvent(pet('pet-1'))),
    expect: () => [
      isA<PetLoading>(),
      isA<PetOperationSuccess>(),
      isA<PetLoaded>()
          .having((state) => state.pets.length, 'saved pet', 1)
          .having((state) => state.selectedPet, 'unconfirmed selection', null)
          .having(
            (state) => state.selectionStatus,
            'selection failure',
            PetSelectionStatus.failure,
          ),
    ],
  );

  blocTest<PetBloc, PetState>(
    '대표 삭제 뒤 대체 대표도 RPC가 같은 id를 확정한 뒤에만 반영한다',
    setUp: () {
      when(() => deletePet('pet-1')).thenAnswer((_) async => const Right(null));
      when(() => setSelectedPetId('pet-2'))
          .thenAnswer((_) async => const Right('pet-2'));
    },
    build: buildBloc,
    seed: () => PetLoaded(
      pets: [pet('pet-1'), pet('pet-2')],
      selectedPet: pet('pet-1'),
    ),
    act: (bloc) => bloc.add(const DeletePetEvent('pet-1')),
    expect: () => [
      isA<PetLoading>(),
      isA<PetOperationSuccess>(),
      isA<PetLoaded>()
          .having((state) => state.pets.length, 'remaining pets', 1)
          .having((state) => state.selectedPet?.id, 'fallback', 'pet-2')
          .having(
            (state) => state.selectionStatus,
            'selection success',
            PetSelectionStatus.success,
          ),
    ],
  );
}
