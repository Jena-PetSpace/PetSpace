import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';

import '../../../../core/error/failures.dart';
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
    on<AuthOnboardingCompleted>(_onOnboardingCompleted);
  }

  void _onAuthStarted(AuthStarted event, Emitter<AuthState> emit) {
    _authStateSubscription = _authRepository.authStateChanges.listen(
      (user) => add(AuthUserChanged(user)),
      onError: (error) {
        // Kakao OAuth 콜백 시 Supabase가 발생시키는 "Code verifier" 에러는 무시
        final errorMessage = error.toString();
        if (errorMessage.contains('Code verifier could not be found')) {
          // Kakao SDK가 OAuth를 처리 중이므로 이 에러는 무시
          return;
        }

        // 그 외 실제 auth 에러 발생 시 로그아웃 상태로 처리
        emit(AuthUnauthenticated());
      },
    );
  }

  void _onAuthUserChanged(AuthUserChanged event, Emitter<AuthState> emit) {
    if (event.user != null) {
      // TODO: SMTP 설정 후 이메일 인증 체크 다시 활성화
      // 임시: 이메일 인증 체크 스킵 (SendGrid 만료)
      // if (!event.user!.isEmailConfirmed) {
      //   emit(AuthEmailVerificationRequired(event.user!));
      // } else {
      //   emit(AuthAuthenticated(event.user!));
      // }
      emit(AuthAuthenticated(event.user!));
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
      (user) => emit(AuthAuthenticated(user)),
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
      (user) => emit(AuthAuthenticated(user)),
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
      (user) => emit(AuthAuthenticated(user)),
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
        // 회원가입 성공 시 이메일 인증 대기 상태로 전환
        // 실제 로그인은 이메일 인증 후에만 가능
        emit(AuthEmailVerificationRequired(user));
      },
    );
  }

  Future<void> _onSignOutRequested(
    AuthSignOutRequested event,
    Emitter<AuthState> emit,
  ) async {
    emit(AuthLoading());

    final result = await _signOut();
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

    // 온보딩 완료 상태로 사용자 프로필 업데이트
    final updatedUser = currentState.user.copyWith(
      isOnboardingCompleted: true,
      displayName: event.displayName,
      photoURL: event.avatarUrl,
    );

    final result = await _authRepository.updateUserProfile(updatedUser);
    result.fold(
      (failure) => emit(AuthError(failure.message)),
      (user) => emit(AuthAuthenticated(user)),
    );
  }

  @override
  Future<void> close() {
    _authStateSubscription?.cancel();
    return super.close();
  }
}