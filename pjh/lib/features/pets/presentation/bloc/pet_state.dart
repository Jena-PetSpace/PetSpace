import 'package:equatable/equatable.dart';
import '../../domain/entities/pet.dart';

abstract class PetState extends Equatable {
  const PetState();

  @override
  List<Object?> get props => [];
}

enum PetSelectionStatus { idle, pending, success, failure }

class PetInitial extends PetState {}

class PetLoading extends PetState {}

class PetLoaded extends PetState {
  final List<Pet> pets;
  final Pet? selectedPet;
  final PetSelectionStatus selectionStatus;
  final String? pendingSelectedPetId;
  final String? selectionMessage;

  const PetLoaded({
    required this.pets,
    this.selectedPet,
    this.selectionStatus = PetSelectionStatus.idle,
    this.pendingSelectedPetId,
    this.selectionMessage,
  });

  @override
  List<Object?> get props => [
        pets,
        selectedPet,
        selectionStatus,
        pendingSelectedPetId,
        selectionMessage,
      ];

  static const _notProvided = Object();

  PetLoaded copyWith({
    List<Pet>? pets,
    Object? selectedPet = _notProvided,
    PetSelectionStatus? selectionStatus,
    Object? pendingSelectedPetId = _notProvided,
    Object? selectionMessage = _notProvided,
  }) {
    return PetLoaded(
      pets: pets ?? this.pets,
      selectedPet: identical(selectedPet, _notProvided)
          ? this.selectedPet
          : selectedPet as Pet?,
      selectionStatus: selectionStatus ?? this.selectionStatus,
      pendingSelectedPetId: identical(pendingSelectedPetId, _notProvided)
          ? this.pendingSelectedPetId
          : pendingSelectedPetId as String?,
      selectionMessage: identical(selectionMessage, _notProvided)
          ? this.selectionMessage
          : selectionMessage as String?,
    );
  }
}

class PetError extends PetState {
  final String message;

  const PetError(this.message);

  @override
  List<Object?> get props => [message];
}

class PetOperationSuccess extends PetState {
  final String message;
  final List<Pet> pets;

  const PetOperationSuccess({
    required this.message,
    required this.pets,
  });

  @override
  List<Object?> get props => [message, pets];
}
