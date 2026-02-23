import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../error/failures.dart';

// 기본 UseCase 인터페이스
abstract class UseCase<T, Params> {
  Future<Either<Failure, T>> call(Params params);
}

// 매개변수가 없는 UseCase
abstract class NoParamUseCase<T> {
  Future<Either<Failure, T>> call();
}

// Stream을 반환하는 UseCase
abstract class StreamUseCase<T, Params> {
  Stream<Either<Failure, T>> call(Params params);
}

// 매개변수가 없는 Stream UseCase
abstract class NoParamStreamUseCase<T> {
  Stream<Either<Failure, T>> call();
}

// 기본 매개변수 클래스
class NoParams extends Equatable {
  @override
  List<Object?> get props => [];
}

// 페이지네이션 매개변수
class PaginationParams extends Equatable {
  final int page;
  final int limit;

  const PaginationParams({
    required this.page,
    required this.limit,
  });

  @override
  List<Object?> get props => [page, limit];
}

// ID를 사용하는 매개변수
class IdParams extends Equatable {
  final String id;

  const IdParams({required this.id});

  @override
  List<Object?> get props => [id];
}

// 문자열을 사용하는 매개변수
class StringParams extends Equatable {
  final String value;

  const StringParams({required this.value});

  @override
  List<Object?> get props => [value];
}