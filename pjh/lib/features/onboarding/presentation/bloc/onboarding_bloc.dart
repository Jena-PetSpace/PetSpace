import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../pets/domain/entities/pet.dart';
import 'onboarding_event.dart';
import 'onboarding_state.dart';

class OnboardingBloc extends Bloc<OnboardingEvent, OnboardingState> {
  OnboardingBloc() : super(OnboardingState.initial()) {
    on<OnboardingStarted>(_onOnboardingStarted);
    on<OnboardingNextStep>(_onNextStep);
    on<OnboardingPreviousStep>(_onPreviousStep);
    on<OnboardingSkipToStep>(_onSkipToStep);
    on<OnboardingProfileUpdated>(_onProfileUpdated);
    on<OnboardingPetAdded>(_onPetAdded);
    on<OnboardingCompleted>(_onOnboardingCompleted);
    on<OnboardingSkipped>(_onOnboardingSkipped);
  }

  void _onOnboardingStarted(
    OnboardingStarted event,
    Emitter<OnboardingState> emit,
  ) {
    emit(OnboardingState.initial());
  }

  void _onNextStep(
    OnboardingNextStep event,
    Emitter<OnboardingState> emit,
  ) {
    if (!state.canGoNext) return;

    final nextIndex = state.currentStepIndex + 1;
    if (nextIndex >= OnboardingStep.values.length) {
      return;
    }

    final nextStep = OnboardingStep.values[nextIndex];
    emit(state.copyWith(
      currentStep: nextStep,
      currentStepIndex: nextIndex,
      error: null,
    ));
  }

  void _onPreviousStep(
    OnboardingPreviousStep event,
    Emitter<OnboardingState> emit,
  ) {
    if (!state.canGoPrevious) return;

    final previousIndex = state.currentStepIndex - 1;
    final previousStep = OnboardingStep.values[previousIndex];

    emit(state.copyWith(
      currentStep: previousStep,
      currentStepIndex: previousIndex,
      error: null,
    ));
  }

  void _onSkipToStep(
    OnboardingSkipToStep event,
    Emitter<OnboardingState> emit,
  ) {
    if (event.stepIndex < 0 ||
        event.stepIndex >= OnboardingStep.values.length) {
      return;
    }

    final step = OnboardingStep.values[event.stepIndex];
    emit(state.copyWith(
      currentStep: step,
      currentStepIndex: event.stepIndex,
      error: null,
    ));
  }

  void _onProfileUpdated(
    OnboardingProfileUpdated event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(
      displayName: event.displayName,
      bio: event.bio,
      isValid: event.displayName.trim().isNotEmpty,
      error: null,
    ));
  }

  void _onPetAdded(
    OnboardingPetAdded event,
    Emitter<OnboardingState> emit,
  ) {
    final updatedPets = List<Pet>.from(state.pets)..add(event.pet);
    emit(state.copyWith(
      pets: updatedPets,
      isValid: updatedPets.isNotEmpty,
      error: null,
    ));
  }

  void _onOnboardingCompleted(
    OnboardingCompleted event,
    Emitter<OnboardingState> emit,
  ) async {
    emit(state.copyWith(isLoading: true));

    try {
      // 실제 구현에서는 여기서 프로필과 반려동물 정보를 저장해야 함
      // await saveProfile(state.displayName, state.bio);
      // await savePets(state.pets);

      emit(state.copyWith(
        currentStep: OnboardingStep.complete,
        currentStepIndex: OnboardingStep.values.length - 1,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: '온보딩 완료 중 오류가 발생했습니다: ${e.toString()}',
      ));
    }
  }

  void _onOnboardingSkipped(
    OnboardingSkipped event,
    Emitter<OnboardingState> emit,
  ) {
    emit(state.copyWith(
      currentStep: OnboardingStep.complete,
      currentStepIndex: OnboardingStep.values.length - 1,
    ));
  }
}
