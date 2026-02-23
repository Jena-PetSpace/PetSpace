part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  const AuthEvent();

  @override
  List<Object?> get props => [];
}

class AuthStarted extends AuthEvent {}

class AuthUserChanged extends AuthEvent {
  final User? user;

  const AuthUserChanged(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthSignInWithGoogleRequested extends AuthEvent {}

class AuthSignInWithKakaoRequested extends AuthEvent {}

class AuthSignInWithEmailRequested extends AuthEvent {
  final String email;
  final String password;

  const AuthSignInWithEmailRequested({
    required this.email,
    required this.password,
  });

  @override
  List<Object?> get props => [email, password];
}

class AuthSignUpWithEmailRequested extends AuthEvent {
  final String email;
  final String password;
  final String? displayName;

  const AuthSignUpWithEmailRequested({
    required this.email,
    required this.password,
    this.displayName,
  });

  @override
  List<Object?> get props => [email, password, displayName];
}

class AuthSignOutRequested extends AuthEvent {}

class AuthDeleteAccountRequested extends AuthEvent {}

class AuthPasswordResetRequested extends AuthEvent {
  final String email;

  const AuthPasswordResetRequested(this.email);

  @override
  List<Object?> get props => [email];
}

class AuthOnboardingCompleted extends AuthEvent {
  final String displayName;
  final String? avatarUrl;

  const AuthOnboardingCompleted({
    required this.displayName,
    this.avatarUrl,
  });

  @override
  List<Object?> get props => [displayName, avatarUrl];
}