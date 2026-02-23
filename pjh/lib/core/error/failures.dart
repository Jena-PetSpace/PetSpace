import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;

  const Failure({required this.message});

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message});
}

class CacheFailure extends Failure {
  const CacheFailure({required super.message});
}

class NetworkFailure extends Failure {
  const NetworkFailure({required super.message});
}

class GeneralFailure extends Failure {
  const GeneralFailure({required super.message});
}

class ValidationFailure extends Failure {
  const ValidationFailure({required super.message});
}

class UnauthorizedFailure extends Failure {
  const UnauthorizedFailure({required super.message});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure({required super.message});
}

class TimeoutFailure extends Failure {
  const TimeoutFailure({required super.message});
}

class AuthFailure extends Failure {
  final Duration? retryAfter;

  const AuthFailure({
    required super.message,
    this.retryAfter,
  });

  @override
  List<Object?> get props => [message, retryAfter];
}

class AnalysisFailure extends Failure {
  const AnalysisFailure({required super.message});
}

class ImageFailure extends Failure {
  const ImageFailure({required super.message});
}

class DatabaseFailure extends Failure {
  const DatabaseFailure({required super.message});
}