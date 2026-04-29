import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/services/analytics_service.dart';
import '../../../../core/services/notification_service.dart';
import '../../domain/entities/user.dart';
import '../../domain/entities/user_profile.dart';
import '../../domain/usecases/sign_in_with_google.dart';
import '../../domain/usecases/sign_in_with_kakao.dart';
import '../../domain/usecases/sign_out.dart';
import '../../domain/repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository _authRepository;
  final SignInWithGoogle _signInWithGoogle;
  final SignInWithKakao _signInWithKakao;
  final SignOut _signOut;

  StreamSubscription<User?>? _authStateSubscription;

  AuthBloc({
    required AuthRepository authRepository,
    required SignInWithGoogle signInWithGoogle,
    required SignInWithKakao signInWithKakao,
    required SignOut signOut,
  })  : _authRepository = authRepository,
        _signInWithGoogle = signInWithGoogle,
        _signInWithKakao = signInWithKakao,
        _signOut = signOut,
        super(AuthInitial()) {
    on<AuthStarted>(_onAuthStarted);
    on<AuthUserChanged>(_onAuthUserChanged);
    on<AuthSignInWithGoogleRequested>(_onSignInWithGoogleRequested);
    on<AuthSignInWithKakaoRequested>(_onSignInWithKakaoRequested);
    on<AuthSignInWithEmailRequested>(_onSignInWithEmailRequested);
    on<AuthSignUpWithEmailRequested>(_onSignUpWithEmailRequested);
    on<AuthSignOutRequested>(_onSignOutRequested);
    on<AuthDeleteAccountRequested>(_onDeleteAccountRequested);
    on<AuthPasswordResetRequested>(_onPasswordResetRequested);
    on<AuthOnboardingCompleted>(_onOnboardingCompleted);
    on<AuthProfileRefreshRequested>(_onProfileRefreshRequested);
  }

  Future<void> _onAuthStarted(
      AuthStarted event, Emitter<AuthState> emit) async {
    // 1) 즉시 현재 세션 체크 → AuthInitial 에서 빠르게 탈출
    //    (실기기에서 onAuthStateChange 의 INITIAL 이벤트 누락 시 무한 스플래시 방지)
    try {
      final currentResult = await _authRepository.getCurrentUser();
      currentResult.fold(
        (_) => add(const AuthUserChanged(null)),
        (user) => add(AuthUserChanged(user)),
      );
    } catch (_) {
      add(const AuthUserChanged(null));
    }

    // 2) 이후 인증 상태 변경 스트림 구독
    _authStateSubscription = _authRepository.authStateChanges.listen(
      (user) => add(AuthUserChanged(user)),
      onError: (error) {
        // Kakao OAuth 콜백 시 Supabase가 발생시키는 "Code verifier" 에러는 무시
        final errorMessage = error.toString();
        if (errorMessage.contains('Code verifier could not be found')) {
          return;
        }

        // 그 외 실제 auth 에러 발생 시 이벤트로 처리 (emit 직접 호출 금지)
        add(const AuthUserChanged(null));
      },
    );
  }

  void _onAuthUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      if (!event.user!.isEmailConfirmed) {
        emit(AuthEmailVerificationRequired(event.user!));
      } else {
        emit(AuthAuthenticated(event.user!));
      }
    } else {
      emit(AuthUnauthenticated());
    }
  }

  Future<void> _onSignInWithGoogleRequested(
    AuthSignInWithGoogleRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signInWithGoogle();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) {
        AnalyticsService.instance.logLogin(method: 'google');
        NotificationService().registerToken(user.id);
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onSignInWithKakaoRequested(
    AuthSignInWithKakaoRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signInWithKakao();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) {
        AnalyticsService.instance.logLogin(method: 'kakao');
        NotificationService().registerToken(user.id);
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onSignInWithEmailRequested(
    AuthSignInWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.signInWithEmail(
      event.email,
      event.password,
    );
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) {
        AnalyticsService.instance.logLogin(method: 'email');
        NotificationService().registerToken(user.id);
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onSignUpWithEmailRequested(
    AuthSignUpWithEmailRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.signUpWithEmail(
      event.email,
      event.password,
      displayName: event.displayName,
    );
    result.fold(
      (failure) {
        if (failure is AuthFailure && failure.retryAfter != null) {
          emit(AuthError(failure.message, retryAfter: failure.retryAfter));
        } else {
          emit(AuthError(failure.message));
        }
      },
      (user) {
        AnalyticsService.instance.logSignUp(method: 'email');
        emit(AuthEmailVerificationRequired(user));
      },
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    // 로그아웃 전 토큰 비활성화 (실패해도 로그아웃 계속)
    await NotificationService().deactivateToken();

    final result = await _signOut();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthUnauthenticated()),
    );
  }

  Future<void> _onPasswordResetRequested(
    AuthPasswordResetRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.resetPassword(event.email);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthUnauthenticated()),
    );
  }

  Future<void> _onDeleteAccountRequested(
    AuthDeleteAccountRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _authRepository.deleteAccount();
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (_) => emit(AuthUnauthenticated()),
    );
  }

  Future<void> _onOnboardingCompleted(
    AuthOnboardingCompleted event,
    Emitter<AuthState> emit,
  ) async {
    final currentState = state;
    if (currentState is! AuthAuthenticated) return;

    // DB에서 최신 프로필 가져오기 (온보딩 중 ProfileService로 저장된 값 반영)
    var baseUser = currentState.user;
    final freshProfile = await _authRepository.getCurrentUser();
    freshProfile.fold(
      (_) {},
      (user) {
        if (user != null) baseUser = user;
      },
    );

    // 온보딩 완료 상태만 업데이트 (프로필은 이미 ProfileService에서 저장됨)
    final updatedUser = baseUser.copyWith(
      isOnboardingCompleted: true,
    );

    final result = await _authRepository.updateUserProfile(updatedUser);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) {
        AnalyticsService.instance.logOnboardingComplete();
        emit(AuthAuthenticated(user));
      },
    );
  }

  Future<void> _onProfileRefreshRequested(
    AuthProfileRefreshRequested event,
    Emitter<AuthState> emit,
  ) async {
    final result = await _authRepository.getCurrentUser();
    result.fold(
      (_) {},
      (user) {
        if (user != null) emit(AuthAuthenticated(user));
      },
    );
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}
