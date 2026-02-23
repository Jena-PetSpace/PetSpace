part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  const AuthState();

  @override
  List<Object?> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final UserProfile? userProfile;

  const AuthAuthenticated(this.user, {this.userProfile});

  @override
  List<Object?> get props => [user, userProfile];
}

class AuthUnauthenticated extends AuthState {}

class AuthError extends AuthState {
  final String message;
  final Duration? retryAfter;

  const AuthError(this.message, {this.retryAfter});

  @override
  List<Object?> get props => [message, retryAfter];
}

class AuthEmailVerificationRequired extends AuthState {
  final User user;

  const AuthEmailVerificationRequired(this.user);

  @override
  List<Object?> get props => [user];
}