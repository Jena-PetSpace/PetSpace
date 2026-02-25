import 'dart:async';
import 'dart:developer';
import 'dart:io';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;

import '../../../../core/error/failures.dart';
import '../../../../core/network/network_info.dart';
import '../../domain/entities/user.dart' as user_entity;
import '../../domain/repositories/auth_repository.dart';
import '../models/user_model.dart';

class AuthRepositoryImpl implements AuthRepository {
  final SupabaseClient supabaseClient;
  final GoogleSignIn googleSignIn;
  final NetworkInfo networkInfo;

  AuthRepositoryImpl({
    required this.supabaseClient,
    required this.googleSignIn,
    required this.networkInfo,
  });

  @override
  Stream<user_entity.User?> get authStateChanges {
    return supabaseClient.auth.onAuthStateChange.asyncMap((data) async {
      final supabaseUser = data.session?.user;
      if (supabaseUser == null) return null;

      try {
        final response = await supabaseClient
            .from('users')
            .select()
            .eq('id', supabaseUser.id)
            .maybeSingle();

        if (response != null) {
          // Supabase auth.users의 email_confirmed_at을 UserModel에 포함
          final userModel = UserModel.fromJson(response);
          return userModel.copyWith(
            emailConfirmedAt: supabaseUser.emailConfirmedAt != null
                ? DateTime.parse(supabaseUser.emailConfirmedAt!)
                : null,
          );
        }
        return null;
      } catch (e) {
        return null;
      }
    });
  }

  @override
  Future<Either<Failure, user_entity.User>> signInWithGoogle() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final GoogleSignInAccount? googleUser = await googleSignIn.signIn();
      if (googleUser == null) {
        return const Left(AuthFailure(message: '구글 로그인이 취소되었습니다.'));
      }

      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      final response = await supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: googleAuth.idToken!,
        accessToken: googleAuth.accessToken,
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        return const Left(AuthFailure(message: '구글 로그인에 실패했습니다.'));
      }

      final userResponse = await supabaseClient
          .from('users')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      UserModel user;
      if (userResponse != null) {
        user = UserModel.fromJson(userResponse);
      } else {
        user = UserModel(
          uid: supabaseUser.id,
          email: supabaseUser.email!,
          displayName: supabaseUser.userMetadata?['display_name'] ??
                       supabaseUser.userMetadata?['full_name'] ?? '사용자',
          photoURL: supabaseUser.userMetadata?['photo_url'] ??
                    supabaseUser.userMetadata?['avatar_url'],
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          pets: const [],
          following: const [],
          followers: const [],
          settings: const UserSettingsModel(
            notificationsEnabled: true,
            privacyLevel: user_entity.PrivacyLevel.public,
            showEmotionAnalysisToPublic: true,
          ),
        );

        await supabaseClient.from('users').insert(user.toMap());
      }

      return Right(user);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: _getAuthErrorMessage(e.message)));
    } catch (e) {
      return Left(
          GeneralFailure(message: '구글 로그인 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, user_entity.User>> signInWithKakao() async {
    log('🔵 [Kakao Login] 시작', name: 'AuthRepository');

    if (!await networkInfo.isConnected) {
      log('❌ [Kakao Login] 네트워크 연결 없음', name: 'AuthRepository');
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      // 1. 카카오 로그인 수행 - 카카오톡 앱이 있으면 앱으로, 없으면 브라우저로
      bool isKakaoTalkAvailable = await kakao.isKakaoTalkInstalled();

      if (isKakaoTalkAvailable) {
        // 카카오톡으로 로그인
        try {
          await kakao.UserApi.instance.loginWithKakaoTalk();
        } on kakao.KakaoClientException catch (error) {
          // 사용자가 카카오톡 로그인을 취소한 경우에만 브라우저로 재시도
          if (error.toString().contains('CANCELED')) {
            await kakao.UserApi.instance.loginWithKakaoAccount();
          } else {
            rethrow;
          }
        }
      } else {
        // 카카오톡이 없으면 브라우저로 로그인
        await kakao.UserApi.instance.loginWithKakaoAccount();
      }

      // 2. 카카오 사용자 정보 가져오기
      final kakaoUser = await kakao.UserApi.instance.me();

      // 3. Supabase에 카카오 계정으로 로그인 (카카오 ID를 이메일 형식으로 변환)
      final kakaoEmail = kakaoUser.kakaoAccount?.email ??
                        'kakao_${kakaoUser.id}@kakao.user';
      final kakaoId = kakaoUser.id.toString();

      log('🔵 [Kakao Login] 카카오 사용자 정보 - email: $kakaoEmail, id: $kakaoId, nickname: ${kakaoUser.kakaoAccount?.profile?.nickname}', name: 'AuthRepository');

      // 카카오 ID를 비밀번호로 사용 (고정값, 매번 동일해야 함)
      final password = 'kakao_user_${kakaoId}_secure_password';

      // 4. Supabase에서 사용자 확인 또는 생성
      User? supabaseUser;
      String debugLog = '';

      // Step 1: 먼저 로그인 시도
      try {
        debugLog += '1.signIn시도→';
        final authResult = await supabaseClient.auth.signInWithPassword(
          email: kakaoEmail,
          password: password,
        );
        supabaseUser = authResult.user;
        debugLog += '성공!';
        log('✅ [Kakao Login] 기존 사용자 로그인 성공: ${supabaseUser?.id}', name: 'AuthRepository');
      } on AuthException catch (e) {
        debugLog += '실패(${e.message})→';
        log('⚠️ [Kakao Login] signIn 실패: ${e.message}', name: 'AuthRepository');
      }

      // Step 2: 로그인 실패 시 회원가입 시도
      if (supabaseUser == null) {
        try {
          debugLog += '2.signUp시도→';
          final signUpResult = await supabaseClient.auth.signUp(
            email: kakaoEmail,
            password: password,
            data: {
              'display_name': kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오 사용자',
              'photo_url': kakaoUser.kakaoAccount?.profile?.profileImageUrl,
              'provider': 'kakao',
              'kakao_id': kakaoId,
            },
          );
          supabaseUser = signUpResult.user;
          debugLog += '성공(id:${supabaseUser?.id})→';
          log('✅ [Kakao Login] 회원가입 성공: ${supabaseUser?.id}', name: 'AuthRepository');
        } on AuthException catch (signUpError) {
          debugLog += 'signUp에러(${signUpError.message})→';
          log('⚠️ [Kakao Login] signUp 에러: ${signUpError.message}', name: 'AuthRepository');
        } catch (e) {
          debugLog += 'signUp예외($e)→';
          log('❌ [Kakao Login] signUp 예외: $e', name: 'AuthRepository');
        }

        // Step 3: RPC로 email_confirmed_at 설정 (signUp은 유저를 생성했지만 인증 이메일 발송 실패한 경우)
        debugLog += '3.RPC-confirm→';
        try {
          await supabaseClient.rpc('confirm_kakao_user_by_email', params: {
            'user_email': kakaoEmail,
          });
          debugLog += 'RPC성공→';
        } catch (e) {
          debugLog += 'RPC실패→';
          log('⚠️ [Kakao Login] confirm RPC: $e', name: 'AuthRepository');
        }

        // Step 4: RPC 후 로그인 재시도
        debugLog += '재로그인→';
        await Future.delayed(const Duration(milliseconds: 800));
        try {
          final retryResult = await supabaseClient.auth.signInWithPassword(
            email: kakaoEmail,
            password: password,
          );
          supabaseUser = retryResult.user;
          debugLog += '성공!';
          log('✅ [Kakao Login] 재로그인 성공: ${supabaseUser?.id}', name: 'AuthRepository');
        } on AuthException catch (e) {
          debugLog += '실패(${e.message})';
          log('❌ [Kakao Login] 재로그인 실패: ${e.message}', name: 'AuthRepository');
        }
      } else {
        // 이미 로그인 성공한 경우에도 RPC 실행 (email_confirmed_at 보장)
        try {
          await supabaseClient.rpc('confirm_kakao_user_by_email', params: {
            'user_email': kakaoEmail,
          });
        } catch (_) {}
      }

      // 최종 실패 시 디버그 로그와 함께 반환
      if (supabaseUser == null) {
        log('❌ [Kakao Login] 최종 실패 - debugLog: $debugLog', name: 'AuthRepository');
        return Left(AuthFailure(message: '[디버그] $debugLog'));
      }

      // 5. users 테이블에서 사용자 정보 가져오기
      // 트리거가 email_confirmed_at 체크로 프로필을 생성하지 않을 수 있으므로 직접 생성
      UserModel? user;
      final userResponse = await supabaseClient
          .from('users')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      if (userResponse != null) {
        user = UserModel.fromJson(userResponse);
      } else {
        // 트리거가 프로필을 생성하지 않은 경우 직접 생성
        log('🔵 [Kakao Login] 프로필 직접 생성 시도', name: 'AuthRepository');
        try {
          await supabaseClient.from('users').insert({
            'id': supabaseUser.id,
            'email': kakaoEmail,
            'display_name': kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오 사용자',
            'photo_url': kakaoUser.kakaoAccount?.profile?.profileImageUrl,
            'provider': 'kakao',
            'is_onboarding_completed': false,
          });

          final newUserResponse = await supabaseClient
              .from('users')
              .select()
              .eq('id', supabaseUser.id)
              .maybeSingle();

          if (newUserResponse != null) {
            user = UserModel.fromJson(newUserResponse);
            log('✅ [Kakao Login] 프로필 직접 생성 성공', name: 'AuthRepository');
          }
        } catch (profileError) {
          log('⚠️ [Kakao Login] 프로필 직접 생성 실패: $profileError', name: 'AuthRepository');
          // 동시성 문제로 이미 생성되었을 수 있으므로 다시 조회
          await Future.delayed(const Duration(milliseconds: 500));
          final retryResponse = await supabaseClient
              .from('users')
              .select()
              .eq('id', supabaseUser.id)
              .maybeSingle();
          if (retryResponse != null) {
            user = UserModel.fromJson(retryResponse);
          }
        }
      }

      if (user == null) {
        return const Left(AuthFailure(message: '사용자 프로필 생성에 실패했습니다.'));
      }

      // 카카오 로그인 사용자는 이미 카카오에서 인증되었으므로 이메일 인증 완료로 처리
      final authenticatedUser = user.copyWith(
        emailConfirmedAt: DateTime.now(),
      );

      return Right(authenticatedUser);
    } on kakao.KakaoException catch (e) {
      log('❌ [Kakao Login] KakaoException: ${e.message}', name: 'AuthRepository');
      return Left(AuthFailure(message: '[카카오SDK] ${e.message}'));
    } on AuthException catch (e) {
      log('❌ [Kakao Login] AuthException: ${e.message} (statusCode: ${e.statusCode})', name: 'AuthRepository');
      return Left(AuthFailure(message: '[Supabase] ${e.message}'));
    } catch (e, stackTrace) {
      log('❌ [Kakao Login] Unknown Exception: ${e.toString()}', name: 'AuthRepository', stackTrace: stackTrace);
      return Left(
          AuthFailure(message: '[오류] ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, user_entity.User>> signInWithEmail(
      String email, String password) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final response = await supabaseClient.auth.signInWithPassword(
        email: email,
        password: password,
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        return const Left(AuthFailure(message: '로그인에 실패했습니다.'));
      }

      // TODO: SMTP 설정 후 이메일 인증 체크 다시 활성화
      // 이메일 인증 여부 확인 (임시 비활성화 - SendGrid 만료)
      // if (supabaseUser.emailConfirmedAt == null) {
      //   await supabaseClient.auth.signOut();
      //   return const Left(AuthFailure(
      //     message: '이메일 인증이 필요합니다.\n가입 시 받은 인증 코드를 입력해주세요.',
      //   ));
      // }

      final userResponse = await supabaseClient
          .from('users')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      if (userResponse != null) {
        final user = UserModel.fromJson(userResponse);
        // 임시: 이메일 인증 완료로 처리
        return Right(user.copyWith(emailConfirmedAt: DateTime.now()));
      } else {
        return const Left(AuthFailure(message: '사용자 정보를 찾을 수 없습니다.'));
      }
    } on AuthException catch (e) {
      return Left(AuthFailure(message: _getAuthErrorMessage(e.message)));
    } catch (e) {
      return Left(GeneralFailure(message: '로그인 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, user_entity.User>> signUpWithEmail(
      String email, String password, {String? displayName}) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      log('🔵 [SignUp] 1단계: 회원가입 시작', name: 'AuthRepository');

      // 1단계: 회원가입
      // Supabase가 자동으로 "Confirm signup" 이메일 발송 ({{ .Token }} 포함)
      final response = await supabaseClient.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: null, // 앱 내에서 처리
        data: {
          'display_name': displayName ?? '사용자',
        },
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        return const Left(AuthFailure(message: '회원가입에 실패했습니다.'));
      }

      log('✅ [SignUp] 2단계: 회원가입 완료 (User ID: ${supabaseUser.id})', name: 'AuthRepository');
      log('   - Supabase가 자동으로 확인 이메일 발송 (6자리 OTP 포함)', name: 'AuthRepository');
      log('   - 이메일 인증 상태: ${supabaseUser.emailConfirmedAt}', name: 'AuthRepository');

      // signOut()을 제거하여 세션 유지 (verifyOtp를 위해 필요)
      // 대신 BLoC에서 email_confirmed_at 체크하여 AuthEmailVerificationRequired 상태로 처리

      log('🔵 [SignUp] 3단계: UserModel 생성', name: 'AuthRepository');

      // UserModel 생성 (emailConfirmedAt 포함)
      final user = UserModel(
        uid: supabaseUser.id,
        email: email,
        displayName: displayName ?? '사용자',
        photoURL: null,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
        pets: const [],
        following: const [],
        followers: const [],
        settings: const UserSettingsModel(
          notificationsEnabled: true,
          privacyLevel: user_entity.PrivacyLevel.public,
          showEmotionAnalysisToPublic: true,
        ),
        // TODO: SMTP 설정 후 이메일 인증 다시 활성화
        // 임시: 이메일 인증 완료로 처리 (SendGrid 만료)
        emailConfirmedAt: DateTime.now(),
      );

      log('✅ [SignUp] 완료: 사용자 모델 반환 (Email: $email)', name: 'AuthRepository');
      return Right(user);
    } on AuthException catch (e) {
      log('❌ [SignUp] 실패: ${e.message}', name: 'AuthRepository');

      // TODO: SMTP 설정 후 다시 활성화
      // 이메일 전송 실패는 무시하고 진행 (SendGrid 만료)
      if (e.message.toLowerCase().contains('error sending confirmation email') ||
          e.message.toLowerCase().contains('unexpected_failure')) {
        log('⚠️ [SignUp] 이메일 전송 실패 무시 (SMTP 미설정)', name: 'AuthRepository');
        // 사용자 생성은 완료되었을 수 있으므로 로그인 시도
        try {
          final loginResult = await supabaseClient.auth.signInWithPassword(
            email: email,
            password: password,
          );
          if (loginResult.user != null) {
            final user = UserModel(
              uid: loginResult.user!.id,
              email: email,
              displayName: displayName ?? '사용자',
              photoURL: null,
              createdAt: DateTime.now(),
              updatedAt: DateTime.now(),
              pets: const [],
              following: const [],
              followers: const [],
              settings: const UserSettingsModel(
                notificationsEnabled: true,
                privacyLevel: user_entity.PrivacyLevel.public,
                showEmotionAnalysisToPublic: true,
              ),
              emailConfirmedAt: DateTime.now(),
            );
            return Right(user);
          }
        } catch (_) {}
      }

      // Rate limit 에러 체크
      if (e.message.toLowerCase().contains('rate limit') ||
          e.message.toLowerCase().contains('email rate limit exceeded')) {
        return const Left(AuthFailure(
          message: '인증 이메일 전송 제한에 도달했습니다.\n3분 후 다시 시도해주세요.',
          retryAfter: Duration(minutes: 3),
        ));
      }

      // 사용자가 이미 존재하는 경우
      if (e.message.toLowerCase().contains('user already registered') ||
          e.message.toLowerCase().contains('email already registered') ||
          e.message.toLowerCase().contains('already been registered')) {
        return const Left(AuthFailure(
          message: '이미 가입된 이메일입니다.\n로그인 페이지에서 로그인해주세요.',
        ));
      }

      return Left(AuthFailure(message: _getAuthErrorMessage(e.message)));
    } catch (e) {
      log('❌ [SignUp] Unknown error: ${e.toString()}', name: 'AuthRepository');
      return Left(
          GeneralFailure(message: '회원가입 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> signOut() async {
    try {
      await Future.wait([
        supabaseClient.auth.signOut(),
        googleSignIn.signOut(),
      ]);
      return const Right(null);
    } catch (e) {
      return Left(AuthFailure(message: '로그아웃 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> deleteAccount() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final user = supabaseClient.auth.currentUser;
      if (user != null) {
        await supabaseClient.from('users').delete().eq('id', user.id);
        await supabaseClient.auth.admin.deleteUser(user.id);
      }
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: _getAuthErrorMessage(e.message)));
    } catch (e) {
      return Left(
          GeneralFailure(message: '계정 삭제 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, user_entity.User?>> getCurrentUser() async {
    try {
      final supabaseUser = supabaseClient.auth.currentUser;
      if (supabaseUser == null) return const Right(null);

      final response = await supabaseClient
          .from('users')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      if (response != null) {
        final user = UserModel.fromJson(response);
        return Right(user);
      } else {
        return const Right(null);
      }
    } catch (e) {
      return Left(
          GeneralFailure(message: '사용자 정보 조회 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, user_entity.User>> updateUserProfile(
      user_entity.User user) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final updatedUser =
          UserModel.fromEntity(user).copyWith(updatedAt: DateTime.now());

      final updateData = updatedUser.toMap();

      await supabaseClient
          .from('users')
          .update(updateData)
          .eq('id', user.uid);

      return Right(updatedUser);
    } catch (e) {
      log('Profile update error: $e', name: 'AuthRepository');
      return Left(
          GeneralFailure(message: '프로필 업데이트 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, String>> uploadProfileImage(String imagePath) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      final user = supabaseClient.auth.currentUser;
      if (user == null) {
        return const Left(AuthFailure(message: '로그인이 필요합니다.'));
      }

      final file = File(imagePath);
      final fileExt = imagePath.split('.').last;
      final fileName = 'profiles/${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

      await supabaseClient.storage.from('images').upload(fileName, file);

      final publicUrl =
          supabaseClient.storage.from('images').getPublicUrl(fileName);

      return Right(publicUrl);
    } catch (e) {
      return Left(
          GeneralFailure(message: '이미지 업로드 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> resetPassword(String email) async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      await supabaseClient.auth.resetPasswordForEmail(email);
      return const Right(null);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: _getAuthErrorMessage(e.message)));
    } catch (e) {
      return Left(
          GeneralFailure(message: '비밀번호 재설정 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, void>> sendEmailVerification() async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user != null && user.emailConfirmedAt == null) {
        await supabaseClient.auth
            .resend(type: OtpType.signup, email: user.email);
      }
      return const Right(null);
    } catch (e) {
      return Left(
          GeneralFailure(message: '이메일 인증 발송 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, bool>> isEmailVerified() async {
    try {
      final user = supabaseClient.auth.currentUser;
      if (user != null) {
        return Right(user.emailConfirmedAt != null);
      }
      return const Right(false);
    } catch (e) {
      return Left(GeneralFailure(
          message: '이메일 인증 상태 확인 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  String _getAuthErrorMessage(String errorMessage) {
    if (errorMessage.contains('Invalid login credentials')) {
      return '로그인 정보가 잘못되었습니다.';
    }
    if (errorMessage.contains('User not found')) {
      return '등록되지 않은 사용자입니다.';
    }
    if (errorMessage.contains('Email not confirmed')) {
      return '이메일 인증이 필요합니다.';
    }
    if (errorMessage.contains('Password should be at least')) {
      return '비밀번호가 너무 약합니다.';
    }
    if (errorMessage.contains('User already registered')) {
      return '이미 등록된 사용자입니다.';
    }
    return '인증 오류: $errorMessage';
  }
}
