import 'package:equatable/equatable.dart';

import '../../../pets/domain/entities/pet.dart';

abstract class OnboardingEvent extends Equatable {
  const OnboardingEvent();

  @override
  List<Object?> get props => [];
}

class OnboardingStarted extends OnboardingEvent {
  const OnboardingStarted();
}

class OnboardingNextStep extends OnboardingEvent {
  const OnboardingNextStep();
}

class OnboardingPreviousStep extends OnboardingEvent {
  const OnboardingPreviousStep();
}

class OnboardingSkipToStep extends OnboardingEvent {
  final int stepIndex;

  const OnboardingSkipToStep(this.stepIndex);

  @override
  List<Object?> get props => [stepIndex];
}

class OnboardingProfileUpdated extends OnboardingEvent {
  final String displayName;
  final String? bio;

  const OnboardingProfileUpdated({
    required this.displayName,
    this.bio,
  });

  @override
  List<Object?> get props => [displayName, bio];
}

class OnboardingPetAdded extends OnboardingEvent {
  final Pet pet;

  const OnboardingPetAdded(this.pet);

  @override
  List<Object?> get props => [pet];
}

class OnboardingCompleted extends OnboardingEvent {
  const OnboardingCompleted();
}

class OnboardingSkipped extends OnboardingEvent {
  const OnboardingSkipped();
}
