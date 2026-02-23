import 'package:dartz/dartz.dart';

import '../../../../core/error/failures.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  Stream<User?> get authStateChanges;

  Future<Either<Failure, User>> signInWithGoogle();
  Future<Either<Failure, User>> signInWithKakao();
  Future<Either<Failure, User>> signInWithEmail(String email, String password);
  Future<Either<Failure, User>> signUpWithEmail(String email, String password, {String? displayName});
  Future<Either<Failure, void>> signOut();
  Future<Either<Failure, void>> deleteAccount();

  Future<Either<Failure, User?>> getCurrentUser();
  Future<Either<Failure, User>> updateUserProfile(User user);
  Future<Either<Failure, String>> uploadProfileImage(String imagePath);

  Future<Either<Failure, void>> resetPassword(String email);
  Future<Either<Failure, void>> sendEmailVerification();
  Future<Either<Failure, bool>> isEmailVerified();
}