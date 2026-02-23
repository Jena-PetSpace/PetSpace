import 'package:equatable/equatable.dart';

import '../../../pets/domain/entities/pet.dart';

enum OnboardingStep {
  welcome,      // 환영 메시지
  profile,      // 프로필 설정
  petRegistration, // 반려동물 등록
  features,     // 주요 기능 소개
  permissions,  // 권한 요청
  complete,     // 완료
}

class OnboardingState extends Equatable {
  final OnboardingStep currentStep;
  final int currentStepIndex;
  final String? displayName;
  final String? bio;
  final List<Pet> pets;
  final bool isValid;
  final bool isLoading;
  final String? error;

  const OnboardingState({
    required this.currentStep,
    required this.currentStepIndex,
    this.displayName,
    this.bio,
    this.pets = const [],
    this.isValid = false,
    this.isLoading = false,
    this.error,
  });

  factory OnboardingState.initial() {
    return const OnboardingState(
      currentStep: OnboardingStep.welcome,
      currentStepIndex: 0,
    );
  }

  double get progress {
    return (currentStepIndex + 1) / OnboardingStep.values.length;
  }

  bool get canGoNext {
    switch (currentStep) {
      case OnboardingStep.welcome:
        return true;
      case OnboardingStep.profile:
        return displayName != null && displayName!.trim().isNotEmpty;
      case OnboardingStep.petRegistration:
        return pets.isNotEmpty;
      case OnboardingStep.features:
        return true;
      case OnboardingStep.permissions:
        return true;
      case OnboardingStep.complete:
        return false;
    }
  }

  bool get canGoPrevious {
    return currentStepIndex > 0;
  }

  OnboardingState copyWith({
    OnboardingStep? currentStep,
    int? currentStepIndex,
    String? displayName,
    String? bio,
    List<Pet>? pets,
    bool? isValid,
    bool? isLoading,
    String? error,
  }) {
    return OnboardingState(
      currentStep: currentStep ?? this.currentStep,
      currentStepIndex: currentStepIndex ?? this.currentStepIndex,
      displayName: displayName ?? this.displayName,
      bio: bio ?? this.bio,
      pets: pets ?? this.pets,
      isValid: isValid ?? this.isValid,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  @override
  List<Object?> get props => [
        currentStep,
        currentStepIndex,
        displayName,
        bio,
        pets,
        isValid,
        isLoading,
        error,
      ];
}
