import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/auth/domain/entities/user.dart';
import 'package:meong_nyang_diary/features/auth/domain/entities/user_profile.dart';
import 'package:meong_nyang_diary/features/auth/domain/repositories/auth_repository.dart';
import 'package:meong_nyang_diary/features/auth/domain/usecases/sign_in_with_google.dart';
import 'package:meong_nyang_diary/features/auth/domain/usecases/sign_in_with_kakao.dart';
import 'package:meong_nyang_diary/features/auth/domain/usecases/sign_out.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';

// ── Mocks ─────────────────────────────────────────────────────────────────────
class MockAuthRepository extends Mock implements AuthRepository {}
class MockSignInWithGoogle extends Mock implements SignInWithGoogle {}
class MockSignInWithKakao extends Mock implements SignInWithKakao {}
class MockSignOut extends Mock implements SignOut {}

// ── Fixtures ──────────────────────────────────────────────────────────────────
final _tUser = User(
  uid: 'test-uid-001',
  email: 'test@petspace.kr',
  displayName: '테스트유저',
  photoURL: null,
  createdAt: DateTime(2025, 1, 1),
  updatedAt: DateTime(2025, 1, 1),
  pets: const [],
  following: const [],
  followers: const [],
  settings: const UserSettings(),
  isOnboardingCompleted: true,
);

void main() {
  late AuthBloc bloc;
  late MockAuthRepository mockRepo;
  late MockSignInWithGoogle mockGoogle;
  late MockSignInWithKakao mockKakao;
  late MockSignOut mockSignOut;
  late StreamController<User?> authStreamController;

  setUp(() {
    mockRepo = MockAuthRepository();
    mockGoogle = MockSignInWithGoogle();
    mockKakao = MockSignInWithKakao();
    mockSignOut = MockSignOut();
    authStreamController = StreamController<User?>.broadcast();

    when(() => mockRepo.authStateChanges)
        .thenAnswer((_) => authStreamController.stream);

    bloc = AuthBloc(
      authRepository: mockRepo,
      signInWithGoogle: mockGoogle,
      signInWithKakao: mockKakao,
      signOut: mockSignOut,
    );
  });

  tearDown(() {
    bloc.close();
    authStreamController.close();
  });

  // ── 초기 상태 ────────────────────────────────────────────────────────────────
  group('초기 상태', () {
    test('AuthInitial 상태로 시작', () {
      expect(bloc.state, isA<AuthInitial>());
    });
  });

  // ── AuthStarted ──────────────────────────────────────────────────────────────
  group('AuthStarted', () {
    blocTest<AuthBloc, AuthState>(
      '스트림에서 User가 emit되면 AuthAuthenticated로 전환',
      build: () {
        when(() => mockRepo.authStateChanges)
            .thenAnswer((_) => Stream.value(_tUser));
        return AuthBloc(
          authRepository: mockRepo,
          signInWithGoogle: mockGoogle,
          signInWithKakao: mockKakao,
          signOut: mockSignOut,
        );
      },
      act: (b) => b.add(AuthStarted()),
      expect: () => [
        isA<AuthAuthenticated>().having((s) => s.user.uid, 'uid', 'test-uid-001'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      '스트림에서 null이 emit되면 AuthUnauthenticated로 전환',
      build: () {
        when(() => mockRepo.authStateChanges)
            .thenAnswer((_) => Stream.value(null));
        return AuthBloc(
          authRepository: mockRepo,
          signInWithGoogle: mockGoogle,
          signInWithKakao: mockKakao,
          signOut: mockSignOut,
        );
      },
      act: (b) => b.add(AuthStarted()),
      expect: () => [isA<AuthUnauthenticated>()],
    );
  });

  // ── Google 로그인 ─────────────────────────────────────────────────────────────
  group('AuthSignInWithGoogleRequested', () {
    blocTest<AuthBloc, AuthState>(
      '성공 → AuthAuthenticated',
      build: () {
        when(() => mockGoogle()).thenAnswer((_) async => Right(_tUser));
        return bloc;
      },
      act: (b) => b.add(AuthSignInWithGoogleRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>().having((s) => s.user.email, 'email', 'test@petspace.kr'),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      '실패 → AuthError',
      build: () {
        when(() => mockGoogle())
            .thenAnswer((_) async => const Left(AuthFailure(message: '구글 로그인 실패')));
        return bloc;
      },
      act: (b) => b.add(AuthSignInWithGoogleRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>().having((s) => s.message, 'message', '구글 로그인 실패'),
      ],
    );
  });

  // ── 카카오 로그인 ─────────────────────────────────────────────────────────────
  group('AuthSignInWithKakaoRequested', () {
    blocTest<AuthBloc, AuthState>(
      '성공 → AuthAuthenticated',
      build: () {
        when(() => mockKakao()).thenAnswer((_) async => Right(_tUser));
        return bloc;
      },
      act: (b) => b.add(AuthSignInWithKakaoRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthAuthenticated>(),
      ],
    );

    blocTest<AuthBloc, AuthState>(
      '실패 → AuthError',
      build: () {
        when(() => mockKakao())
            .thenAnswer((_) async => const Left(AuthFailure(message: '카카오 로그인 실패')));
        return bloc;
      },
      act: (b) => b.add(AuthSignInWithKakaoRequested()),
      expect: () => [
        isA<AuthLoading>(),
        isA<AuthError>(),
      ],
    );
  });

  // ── 로그아웃 ─────────────────────────────────────────────────────────────────
  group('AuthSignOutRequested', () {
    blocTest<AuthBloc, AuthState>(
      '성공 → AuthUnauthenticated',
      build: () {
        when(() => mockSignOut()).thenAnswer((_) async => const Right(null));
        return bloc;
      },
      seed: () => AuthAuthenticated(_tUser),
      act: (b) => b.add(AuthSignOutRequested()),
      expect: () => [isA<AuthUnauthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      '실패 → AuthError',
      build: () {
        when(() => mockSignOut())
            .thenAnswer((_) async => const Left(AuthFailure(message: '로그아웃 실패')));
        return bloc;
      },
      seed: () => AuthAuthenticated(_tUser),
      act: (b) => b.add(AuthSignOutRequested()),
      expect: () => [isA<AuthError>()],
    );
  });

  // ── AuthUserChanged ───────────────────────────────────────────────────────────
  group('AuthUserChanged', () {
    blocTest<AuthBloc, AuthState>(
      'User 객체 → AuthAuthenticated',
      build: () => bloc,
      act: (b) => b.add(AuthUserChanged(_tUser)),
      expect: () => [isA<AuthAuthenticated>()],
    );

    blocTest<AuthBloc, AuthState>(
      'null → AuthUnauthenticated',
      build: () => bloc,
      act: (b) => b.add(AuthUserChanged(null)),
      expect: () => [isA<AuthUnauthenticated>()],
    );
  });
}
