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

/// 외부 인증 창에서 사용자가 직접 닫거나 뒤로 간 경우.
/// 실패와 구분해 재시도 압박이나 오류 색상을 노출하지 않는다.
class AuthCancelled extends AuthState {
  final String provider;

  const AuthCancelled(this.provider);

  @override
  List<Object?> get props => [provider];
}

class AuthEmailVerificationRequired extends AuthState {
  final User user;

  const AuthEmailVerificationRequired(this.user);

  @override
  List<Object?> get props => [user];
}

class AuthAccountDeleted extends AuthState {
  final User user;

  const AuthAccountDeleted(this.user);

  @override
  List<Object?> get props => [user];
}
