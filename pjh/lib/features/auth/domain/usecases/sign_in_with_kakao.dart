import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/user.dart';
import '../repositories/auth_repository.dart';

class SignInWithKakao implements NoParamUseCase<User> {
  final AuthRepository repository;

  SignInWithKakao(this.repository);

  @override
  Future<Either<Failure, User>> call() async {
    return await repository.signInWithKakao();
  }
}