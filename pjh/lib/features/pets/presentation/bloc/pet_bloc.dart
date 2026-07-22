import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/services/analytics_service.dart';
import '../../domain/entities/pet.dart';
import '../../domain/usecases/add_pet.dart';
import '../../domain/usecases/delete_pet.dart';
import '../../domain/usecases/get_user_pets.dart';
import '../../domain/usecases/get_selected_pet_id.dart';
import '../../domain/usecases/set_selected_pet_id.dart';
import '../../domain/usecases/update_pet.dart';
import 'pet_event.dart';
import 'pet_state.dart';

class PetBloc extends Bloc<PetEvent, PetState> {
  final GetUserPets getUserPets;
  final AddPet addPet;
  final UpdatePet updatePet;
  final DeletePet deletePet;
  final GetSelectedPetId getSelectedPetId;
  final SetSelectedPetId setSelectedPetId;
  final String? Function() currentUserIdProvider;

  PetBloc({
    required this.getUserPets,
    required this.addPet,
    required this.updatePet,
    required this.deletePet,
    required this.getSelectedPetId,
    required this.setSelectedPetId,
    String? Function()? currentUserIdProvider,
  })  : currentUserIdProvider = currentUserIdProvider ??
            (() => Supabase.instance.client.auth.currentUser?.id),
        super(PetInitial()) {
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
      final userId = currentUserIdProvider();
      if (userId == null) {
        emit(const PetError('로그인이 필요합니다.'));
        return;
      }

      final result = await getUserPets(userId);

      await result.fold(
        (failure) async => emit(PetError(failure.message)),
        (pets) async {
          final selectedResult = await getSelectedPetId();
          selectedResult.fold(
            (failure) => emit(
              PetLoaded(
                pets: pets,
                selectionStatus: PetSelectionStatus.failure,
                selectionMessage: failure.message,
              ),
            ),
            (selectedPetId) {
              Pet? selectedPet;
              if (selectedPetId != null) {
                selectedPet = _findPet(pets, selectedPetId);
              }
              emit(
                PetLoaded(
                  pets: pets,
                  selectedPet: selectedPet,
                  selectionStatus: selectedPetId != null && selectedPet == null
                      ? PetSelectionStatus.failure
                      : PetSelectionStatus.idle,
                  selectionMessage: selectedPetId != null && selectedPet == null
                      ? '대표 반려동물 정보를 다시 선택해주세요.'
                      : null,
                ),
              );
            },
          );
        },
      );
    } catch (_) {
      emit(const PetError('반려동물 목록을 불러오지 못했어요.'));
    }
  }

  Future<void> _onAddPet(
    AddPetEvent event,
    Emitter<PetState> emit,
  ) async {
    final currentState =
        state is PetLoaded ? state as PetLoaded : const PetLoaded(pets: []);
    emit(PetLoading());

    try {
      final result = await addPet(event.pet);

      await result.fold(
        (failure) async {
          emit(PetError(failure.message));
          emit(currentState);
        },
        (newPet) async {
          AnalyticsService.instance.logPetRegistered(petType: newPet.type.name);
          final updatedPets = [...currentState.pets, newPet];
          var selectedPet = currentState.selectedPet;
          var selectionStatus = currentState.selectionStatus;
          String? selectionMessage;
          if (selectedPet == null) {
            final selectionResult = await setSelectedPetId(newPet.id);
            selectionResult.fold(
              (failure) {
                selectionStatus = PetSelectionStatus.failure;
                selectionMessage = failure.message;
              },
              (selectedPetId) {
                if (selectedPetId == newPet.id) {
                  selectedPet = newPet;
                  selectionStatus = PetSelectionStatus.success;
                  selectionMessage = '대표 반려동물로 설정했어요: ${newPet.name}';
                } else {
                  selectionStatus = PetSelectionStatus.failure;
                  selectionMessage = '대표 반려동물을 변경하지 못했어요.';
                }
              },
            );
          }
          emit(PetOperationSuccess(
            message: '반려동물을 등록했어요.',
            pets: updatedPets,
          ));
          emit(PetLoaded(
            pets: updatedPets,
            selectedPet: selectedPet,
            selectionStatus: selectionStatus,
            selectionMessage: selectionMessage,
          ));
        },
      );
    } catch (_) {
      emit(const PetError('반려동물을 등록하지 못했어요. 입력 내용을 확인해주세요.'));
      emit(currentState);
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

      await result.fold(
        (failure) async {
          emit(PetError(failure.message));
          emit(currentState);
        },
        (updatedPet) {
          final updatedPets = currentState.pets
              .map((pet) => pet.id == updatedPet.id ? updatedPet : pet)
              .toList();

          emit(PetOperationSuccess(
            message: '반려동물 정보를 저장했어요.',
            pets: updatedPets,
          ));
          emit(PetLoaded(
            pets: updatedPets,
            selectedPet: currentState.selectedPet?.id == updatedPet.id
                ? updatedPet
                : currentState.selectedPet,
            selectionStatus: currentState.selectionStatus,
            selectionMessage: currentState.selectionMessage,
          ));
        },
      );
    } catch (_) {
      emit(const PetError('반려동물 정보를 저장하지 못했어요.'));
      emit(currentState);
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

      await result.fold(
        (failure) async {
          emit(PetError(failure.message));
          emit(currentState);
        },
        (_) async {
          final updatedPets =
              currentState.pets.where((pet) => pet.id != event.petId).toList();

          Pet? newSelectedPet = currentState.selectedPet;
          var selectionStatus = currentState.selectionStatus;
          String? selectionMessage;
          if (currentState.selectedPet?.id == event.petId) {
            newSelectedPet = null;
            if (updatedPets.isNotEmpty) {
              final fallback = updatedPets.first;
              final selectionResult = await setSelectedPetId(fallback.id);
              selectionResult.fold(
                (failure) {
                  selectionStatus = PetSelectionStatus.failure;
                  selectionMessage = failure.message;
                },
                (selectedPetId) {
                  if (selectedPetId == fallback.id) {
                    newSelectedPet = fallback;
                    selectionStatus = PetSelectionStatus.success;
                    selectionMessage = '대표 반려동물로 설정했어요: ${fallback.name}';
                  } else {
                    selectionStatus = PetSelectionStatus.failure;
                    selectionMessage = '대표 반려동물을 변경하지 못했어요.';
                  }
                },
              );
            } else {
              selectionStatus = PetSelectionStatus.idle;
            }
          }

          emit(PetOperationSuccess(
            message: '반려동물을 삭제했어요.',
            pets: updatedPets,
          ));
          emit(PetLoaded(
            pets: updatedPets,
            selectedPet: newSelectedPet,
            selectionStatus: selectionStatus,
            selectionMessage: selectionMessage,
          ));
        },
      );
    } catch (_) {
      emit(const PetError('반려동물을 삭제하지 못했어요.'));
      emit(currentState);
    }
  }

  Future<void> _onSelectPet(
    SelectPet event,
    Emitter<PetState> emit,
  ) async {
    if (state is! PetLoaded) return;
    final currentState = state as PetLoaded;
    if (currentState.selectionStatus == PetSelectionStatus.pending ||
        currentState.selectedPet?.id == event.pet.id) {
      return;
    }

    emit(
      currentState.copyWith(
        selectionStatus: PetSelectionStatus.pending,
        pendingSelectedPetId: event.pet.id,
        selectionMessage: null,
      ),
    );

    try {
      final result = await setSelectedPetId(event.pet.id);
      result.fold(
        (failure) => emit(
          currentState.copyWith(
            selectionStatus: PetSelectionStatus.failure,
            pendingSelectedPetId: null,
            selectionMessage: failure.message,
          ),
        ),
        (selectedPetId) {
          if (selectedPetId != event.pet.id) {
            emit(
              currentState.copyWith(
                selectionStatus: PetSelectionStatus.failure,
                pendingSelectedPetId: null,
                selectionMessage: '대표 반려동물을 변경하지 못했어요.',
              ),
            );
            return;
          }
          emit(
            currentState.copyWith(
              selectedPet: event.pet,
              selectionStatus: PetSelectionStatus.success,
              pendingSelectedPetId: null,
              selectionMessage: '대표 반려동물로 설정했어요: ${event.pet.name}',
            ),
          );
        },
      );
    } catch (_) {
      emit(
        currentState.copyWith(
          selectionStatus: PetSelectionStatus.failure,
          pendingSelectedPetId: null,
          selectionMessage: '대표 반려동물을 변경하지 못했어요.',
        ),
      );
    }
  }

  Pet? _findPet(List<Pet> pets, String petId) {
    for (final pet in pets) {
      if (pet.id == petId) return pet;
    }
    return null;
  }
}
