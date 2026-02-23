import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../domain/entities/pet.dart';
import '../../domain/usecases/add_pet.dart';
import '../../domain/usecases/delete_pet.dart';
import '../../domain/usecases/get_user_pets.dart';
import '../../domain/usecases/update_pet.dart';
import 'pet_event.dart';
import 'pet_state.dart';

class PetBloc extends Bloc<PetEvent, PetState> {
  final GetUserPets getUserPets;
  final AddPet addPet;
  final UpdatePet updatePet;
  final DeletePet deletePet;

  PetBloc({
    required this.getUserPets,
    required this.addPet,
    required this.updatePet,
    required this.deletePet,
  }) : super(PetInitial()) {
    on<LoadUserPets>(_onLoadUserPets);
    on<AddPetEvent>(_onAddPet);
    on<UpdatePetEvent>(_onUpdatePet);
    on<DeletePetEvent>(_onDeletePet);
    on<SelectPet>(_onSelectPet);
  }

  Future<void> _onLoadUserPets(
    LoadUserPets event,
    Emitter<PetState> emit,
  ) async {
    emit(PetLoading());

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        emit(const PetError('로그인이 필요합니다.'));
        return;
      }

      final result = await getUserPets(user.id);

      result.fold(
        (failure) => emit(PetError(failure.message)),
        (pets) {
          emit(PetLoaded(
            pets: pets,
            selectedPet: pets.isNotEmpty ? pets.first : null,
          ));
        },
      );
    } catch (e) {
      emit(PetError('반려동물 목록을 불러오는데 실패했습니다: ${e.toString()}'));
    }
  }

  Future<void> _onAddPet(
    AddPetEvent event,
    Emitter<PetState> emit,
  ) async {
    if (state is! PetLoaded) return;

    final currentState = state as PetLoaded;
    emit(PetLoading());

    try {
      final result = await addPet(event.pet);

      result.fold(
        (failure) => emit(PetError(failure.message)),
        (newPet) {
          final updatedPets = [...currentState.pets, newPet];
          emit(PetOperationSuccess(
            message: '반려동물이 성공적으로 등록되었습니다.',
            pets: updatedPets,
          ));
          emit(PetLoaded(
            pets: updatedPets,
            selectedPet: currentState.selectedPet ?? newPet,
          ));
        },
      );
    } catch (e) {
      emit(PetError('반려동물 등록에 실패했습니다: ${e.toString()}'));
    }
  }

  Future<void> _onUpdatePet(
    UpdatePetEvent event,
    Emitter<PetState> emit,
  ) async {
    if (state is! PetLoaded) return;

    final currentState = state as PetLoaded;
    emit(PetLoading());

    try {
      final result = await updatePet(event.pet);

      result.fold(
        (failure) => emit(PetError(failure.message)),
        (updatedPet) {
          final updatedPets = currentState.pets
              .map((pet) => pet.id == updatedPet.id ? updatedPet : pet)
              .toList();

          emit(PetOperationSuccess(
            message: '반려동물 정보가 성공적으로 업데이트되었습니다.',
            pets: updatedPets,
          ));
          emit(PetLoaded(
            pets: updatedPets,
            selectedPet: currentState.selectedPet?.id == updatedPet.id
                ? updatedPet
                : currentState.selectedPet,
          ));
        },
      );
    } catch (e) {
      emit(PetError('반려동물 정보 업데이트에 실패했습니다: ${e.toString()}'));
    }
  }

  Future<void> _onDeletePet(
    DeletePetEvent event,
    Emitter<PetState> emit,
  ) async {
    if (state is! PetLoaded) return;

    final currentState = state as PetLoaded;
    emit(PetLoading());

    try {
      final result = await deletePet(event.petId);

      result.fold(
        (failure) => emit(PetError(failure.message)),
        (_) {
          final updatedPets = currentState.pets
              .where((pet) => pet.id != event.petId)
              .toList();

          Pet? newSelectedPet = currentState.selectedPet;
          if (currentState.selectedPet?.id == event.petId) {
            newSelectedPet = updatedPets.isNotEmpty ? updatedPets.first : null;
          }

          emit(PetOperationSuccess(
            message: '반려동물이 성공적으로 삭제되었습니다.',
            pets: updatedPets,
          ));
          emit(PetLoaded(
            pets: updatedPets,
            selectedPet: newSelectedPet,
          ));
        },
      );
    } catch (e) {
      emit(PetError('반려동물 삭제에 실패했습니다: ${e.toString()}'));
    }
  }

  void _onSelectPet(
    SelectPet event,
    Emitter<PetState> emit,
  ) {
    if (state is PetLoaded) {
      final currentState = state as PetLoaded;
      emit(currentState.copyWith(selectedPet: event.pet));
    }
  }
}