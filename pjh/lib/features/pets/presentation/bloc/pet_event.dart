import 'package:equatable/equatable.dart';
import '../../domain/entities/pet.dart';

abstract class PetEvent extends Equatable {
  const PetEvent();

  @override
  List<Object?> get props => [];
}

class LoadUserPets extends PetEvent {}

class AddPetEvent extends PetEvent {
  final Pet pet;

  const AddPetEvent(this.pet);

  @override
  List<Object?> get props => [pet];
}

class UpdatePetEvent extends PetEvent {
  final Pet pet;

  const UpdatePetEvent(this.pet);

  @override
  List<Object?> get props => [pet];
}

class DeletePetEvent extends PetEvent {
  final String petId;

  const DeletePetEvent(this.petId);

  @override
  List<Object?> get props => [petId];
}

class SelectPet extends PetEvent {
  final Pet pet;

  const SelectPet(this.pet);

  @override
  List<Object?> get props => [pet];
}