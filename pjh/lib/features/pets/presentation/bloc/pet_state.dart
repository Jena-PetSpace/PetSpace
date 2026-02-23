import 'package:equatable/equatable.dart';
import '../../domain/entities/pet.dart';

abstract class PetState extends Equatable {
  const PetState();

  @override
  List<Object?> get props => [];
}

class PetInitial extends PetState {}

class PetLoading extends PetState {}

class PetLoaded extends PetState {
  final List<Pet> pets;
  final Pet? selectedPet;

  const PetLoaded({
    required this.pets,
    this.selectedPet,
  });

  @override
  List<Object?> get props => [pets, selectedPet];

  PetLoaded copyWith({
    List<Pet>? pets,
    Pet? selectedPet,
  }) {
    return PetLoaded(
      pets: pets ?? this.pets,
      selectedPet: selectedPet ?? this.selectedPet,
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