import 'dart:async';
import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:crypto/crypto.dart';

import 'package:dartz/dartz.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../../config/secrets.dart';
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

      // handle_new_user 트리거가 프로필을 생성할 시간 대기
      await Future.delayed(const Duration(milliseconds: 500));

      var userResponse = await supabaseClient
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
              supabaseUser.userMetadata?['full_name'] ??
              '사용자',
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

        await supabaseClient
            .from('users')
            .upsert(user.toMap(), onConflict: 'id');
      }

      // 구글 로그인 사용자는 이미 구글에서 신원이 검증되었으므로 이메일 인증 완료로 처리.
      final authenticatedUser = user.copyWith(
        emailConfirmedAt: supabaseUser.emailConfirmedAt != null
            ? DateTime.parse(supabaseUser.emailConfirmedAt!)
            : DateTime.now(),
      );

      return Right(authenticatedUser);
    } on AuthException catch (e) {
      return Left(AuthFailure(message: _getAuthErrorMessage(e.message)));
    } on PostgrestException catch (e) {
      // 같은 이메일이 이미 다른 방식으로 가입된 계정에 존재 → 자동 연동 미적용 케이스.
      if (e.code == '23505') {
        return const Left(AuthFailure(
            message: '이미 다른 방식으로 가입된 이메일입니다. 기존 로그인 방식(이메일·애플·카카오)으로 로그인해 주세요.'));
      }
      return Left(
          GeneralFailure(message: '구글 로그인 중 오류가 발생했습니다: ${e.message}'));
    } catch (e) {
      return Left(
          GeneralFailure(message: '구글 로그인 중 오류가 발생했습니다: ${e.toString()}'));
    }
  }

  @override
  Future<Either<Failure, user_entity.User>> signInWithApple() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    // Apple 로그인은 iOS 13+ / macOS 10.15+ 에서만 동작.
    // Android 는 web flow 가 가능하지만 본 앱은 iOS 전용으로 노출.
    if (!Platform.isIOS && !Platform.isMacOS) {
      return const Left(
        AuthFailure(message: 'Apple 로그인은 iOS 기기에서만 사용할 수 있습니다.'),
      );
    }

    try {
      // Supabase 가 nonce 검증에 사용 — 평문은 Apple 에 전달하고
      // 해시본은 Supabase signInWithIdToken 의 nonce 파라미터로 전달.
      final rawNonce = supabaseClient.auth.generateRawNonce();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null || idToken.isEmpty) {
        return const Left(
            AuthFailure(message: 'Apple 로그인 토큰을 가져오지 못했습니다. 다시 시도해주세요.'));
      }

      final response = await supabaseClient.auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );

      final supabaseUser = response.user;
      if (supabaseUser == null) {
        return const Left(AuthFailure(message: 'Apple 로그인에 실패했습니다.'));
      }

      // handle_new_user 트리거가 프로필을 생성할 시간 대기
      await Future.delayed(const Duration(milliseconds: 500));

      final userResponse = await supabaseClient
          .from('users')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      UserModel user;
      if (userResponse != null) {
        user = UserModel.fromJson(userResponse);
      } else {
        // Apple 은 첫 로그인에서만 fullName/email 을 반환함.
        // 이후엔 비어 있으므로 Supabase userMetadata 또는 임의 닉네임 사용.
        final fullName = [
          credential.givenName,
          credential.familyName,
        ].where((s) => s != null && s.isNotEmpty).join(' ').trim();

        final displayName = fullName.isNotEmpty
            ? fullName
            : (supabaseUser.userMetadata?['full_name'] as String?) ??
                (supabaseUser.userMetadata?['name'] as String?) ??
                '사용자';

        final email = supabaseUser.email ??
            credential.email ??
            'apple_${supabaseUser.id}@apple.user';

        user = UserModel(
          uid: supabaseUser.id,
          email: email,
          displayName: displayName,
          photoURL: supabaseUser.userMetadata?['avatar_url'] as String?,
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

        await supabaseClient
            .from('users')
            .upsert(user.toMap(), onConflict: 'id');
      }

      // Apple 로그인 사용자는 이미 Apple 에서 신원이 검증되었으므로 이메일 인증 완료로 처리.
      // (Apple Hide My Email 의 privaterelay 주소로는 OTP 수신 불가 → 인증 단계 자체가 부적합)
      final authenticatedUser = user.copyWith(
        emailConfirmedAt: supabaseUser.emailConfirmedAt != null
            ? DateTime.parse(supabaseUser.emailConfirmedAt!)
            : DateTime.now(),
      );

      return Right(authenticatedUser);
    } on SignInWithAppleAuthorizationException catch (e) {
      // 사용자 취소 / 권한 거부 등 — 빈 메시지로 SnackBar 노출 억제
      if (e.code == AuthorizationErrorCode.canceled) {
        return const Left(AuthFailure(message: ''));
      }
      return Left(AuthFailure(message: 'Apple 로그인 실패: ${e.message}'));
    } on AuthException catch (e) {
      return Left(AuthFailure(message: _getAuthErrorMessage(e.message)));
    } on PostgrestException catch (e) {
      // 같은 이메일이 이미 다른 방식으로 가입된 계정에 존재 → 자동 연동 미적용 케이스.
      // (H2 마이그레이션 적용 후에는 GoTrue 가 기존 계정에 연동하므로 정상적으로는 도달하지 않음)
      if (e.code == '23505') {
        return const Left(AuthFailure(
            message: '이미 다른 방식으로 가입된 이메일입니다. 기존 로그인 방식(이메일·구글·카카오)으로 로그인해 주세요.'));
      }
      return Left(
          GeneralFailure(message: 'Apple 로그인 중 오류가 발생했습니다: ${e.message}'));
    } catch (e) {
      return Left(
          GeneralFailure(message: 'Apple 로그인 중 오류가 발생했습니다: ${e.toString()}'));
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
      final kakaoEmail =
          kakaoUser.kakaoAccount?.email ?? 'kakao_${kakaoUser.id}@kakao.user';
      final kakaoId = kakaoUser.id.toString();

      log('🔵 [Kakao Login] 카카오 사용자 정보 - email: $kakaoEmail, id: $kakaoId, nickname: ${kakaoUser.kakaoAccount?.profile?.nickname}',
          name: 'AuthRepository');

      // 카카오 ID + 시크릿 솔트로 SHA-256 해싱 비밀번호 생성 (소스코드만으로 유추 불가)
      final saltedInput =
          '${kakaoId}_${Secrets.kakaoPasswordSalt}_petspace_kakao_auth';
      final hash = sha256.convert(utf8.encode(saltedInput));
      final newPassword = 'K_${hash.toString()}';
      // 기존 비밀번호 패턴 (마이그레이션용)
      final legacyPassword = 'kakao_${kakaoId}_${Secrets.kakaoPasswordSalt}';

      // 4. Supabase에서 사용자 확인 또는 생성
      User? supabaseUser;
      String debugLog = '';

      // Step 1: 새 비밀번호로 로그인 시도
      try {
        debugLog += '1.signIn(new)→';
        final authResult = await supabaseClient.auth.signInWithPassword(
          email: kakaoEmail,
          password: newPassword,
        );
        supabaseUser = authResult.user;
        debugLog += '성공!';
        log('✅ [Kakao Login] 새 비밀번호로 로그인 성공: ${supabaseUser?.id}',
            name: 'AuthRepository');
      } on AuthException catch (e) {
        debugLog += '실패→';
        log('⚠️ [Kakao Login] 새 비밀번호 signIn 실패: ${e.message}',
            name: 'AuthRepository');
      }

      // Step 1-b: 새 비밀번호 실패 시 기존 비밀번호로 시도 (마이그레이션)
      if (supabaseUser == null) {
        try {
          debugLog += '1b.signIn(legacy)→';
          final authResult = await supabaseClient.auth.signInWithPassword(
            email: kakaoEmail,
            password: legacyPassword,
          );
          supabaseUser = authResult.user;
          debugLog += '성공→';
          log('✅ [Kakao Login] 기존 비밀번호로 로그인 성공 (마이그레이션 필요): ${supabaseUser?.id}',
              name: 'AuthRepository');

          // 기존 비밀번호로 로그인 성공 → 새 비밀번호로 업데이트
          try {
            await supabaseClient.auth.updateUser(
              UserAttributes(password: newPassword),
            );
            log('✅ [Kakao Login] 비밀번호 마이그레이션 완료', name: 'AuthRepository');
            debugLog += '비밀번호갱신성공→';
          } catch (updateError) {
            log('⚠️ [Kakao Login] 비밀번호 갱신 실패 (다음 로그인 시 재시도): $updateError',
                name: 'AuthRepository');
            debugLog += '비밀번호갱신실패→';
          }
        } on AuthException catch (e) {
          debugLog += '실패(${e.message})→';
          log('⚠️ [Kakao Login] 기존 비밀번호 signIn도 실패: ${e.message}',
              name: 'AuthRepository');
        }
      }

      // Step 2: 로그인 실패 시 회원가입 시도
      if (supabaseUser == null) {
        try {
          debugLog += '2.signUp시도→';
          final signUpResult = await supabaseClient.auth.signUp(
            email: kakaoEmail,
            password: newPassword,
            data: {
              'display_name':
                  kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오 사용자',
              'photo_url': kakaoUser.kakaoAccount?.profile?.profileImageUrl,
              'provider': 'kakao',
              'kakao_id': kakaoId,
            },
          );
          supabaseUser = signUpResult.user;
          debugLog += '성공(id:${supabaseUser?.id})→';
          log('✅ [Kakao Login] 회원가입 성공: ${supabaseUser?.id}',
              name: 'AuthRepository');
        } on AuthException catch (signUpError) {
          debugLog += 'signUp에러(${signUpError.message})→';
          log('⚠️ [Kakao Login] signUp 에러: ${signUpError.message}',
              name: 'AuthRepository');
        } catch (e) {
          debugLog += 'signUp예외($e)→';
          log('❌ [Kakao Login] signUp 예외: $e', name: 'AuthRepository');
        }

        // Step 3: RPC로 email_confirmed_at 설정 (signUp은 유저를 생성했지만 인증 이메일 발송 실패한 경우)
        // [세션1 1-A 검증] Step 3 시점 세션 유무 진단 — confirm RPC를 authenticated로 잠가도
        //   카카오 플로우가 깨지지 않는지 판단 근거. 검증 후 제거 예정.
        final s3Session = supabaseClient.auth.currentSession;
        // print()는 logcat 'flutter :' 태그로 확실히 출력됨(log()는 VM Service로만 가 logcat 미표시).
        // 검증 후 제거 예정.
        // ignore: avoid_print
        print('KAKAO_1A_VERIFY Step3 currentSession='
            '${s3Session == null ? 'NULL_세션없음' : 'NONNULL_uid_${s3Session.user.id}'}');
        log('🔍 [Kakao 1-A검증] Step3 시점 currentSession='
            '${s3Session == null ? 'NULL(세션없음)' : 'non-null(uid:${s3Session.user.id})'}',
            name: 'AuthRepository');
        debugLog += '[S3세션:${s3Session == null ? 'NULL' : 'OK'}]→';
        debugLog += '3.RPC-confirm→';
        try {
          await supabaseClient.rpc('confirm_kakao_user_by_email', params: {
            'p_email': kakaoEmail,
          });
          debugLog += 'RPC성공→';
        } catch (e) {
          debugLog += 'RPC실패→';
          log('⚠️ [Kakao Login] confirm RPC: $e', name: 'AuthRepository');
        }

        // Step 4: RPC 후 로그인 재시도
        debugLog += '재로그인→';
        await Future.delayed(const Duration(milliseconds: 1000));
        try {
          final retryResult = await supabaseClient.auth.signInWithPassword(
            email: kakaoEmail,
            password: newPassword,
          );
          supabaseUser = retryResult.user;
          debugLog += '성공!';
          log('✅ [Kakao Login] 재로그인 성공: ${supabaseUser?.id}',
              name: 'AuthRepository');
        } on AuthException catch (e) {
          debugLog += '실패(${e.message})';
          log('❌ [Kakao Login] 재로그인 실패: ${e.message}', name: 'AuthRepository');
        }
      } else {
        // 이미 로그인 성공한 경우에도 RPC 실행 (email_confirmed_at 보장)
        // [세션1 1-A 검증] else 분기(기존 계정 로그인)에서도 세션 상태 진단. 검증 후 제거 예정.
        final elseSession = supabaseClient.auth.currentSession;
        // ignore: avoid_print
        print('KAKAO_1A_VERIFY ElseBranch currentSession='
            '${elseSession == null ? 'NULL_세션없음' : 'NONNULL_uid_${elseSession.user.id}'}');
        try {
          await supabaseClient.rpc('confirm_kakao_user_by_email', params: {
            'p_email': kakaoEmail,
          });
        } catch (e) {
          log('⚠️ [Kakao Login] confirm RPC 실패: $e', name: 'AuthRepository');
        }
      }

      // 최종 실패 시 디버그 로그와 함께 반환
      if (supabaseUser == null) {
        log('❌ [Kakao Login] 최종 실패 - debugLog: $debugLog',
            name: 'AuthRepository');
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
          await supabaseClient.from('users').upsert({
            'id': supabaseUser.id,
            'email': kakaoEmail,
            'display_name':
                kakaoUser.kakaoAccount?.profile?.nickname ?? '카카오 사용자',
            'photo_url': kakaoUser.kakaoAccount?.profile?.profileImageUrl,
            'provider': 'kakao',
            'is_onboarding_completed': false,
          }, onConflict: 'id');

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
          log('⚠️ [Kakao Login] 프로필 직접 생성 실패: $profileError',
              name: 'AuthRepository');
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
      log('❌ [Kakao Login] KakaoException: ${e.message}',
          name: 'AuthRepository');
      return Left(AuthFailure(message: '[카카오SDK] ${e.message}'));
    } on AuthException catch (e) {
      log('❌ [Kakao Login] AuthException: ${e.message} (statusCode: ${e.statusCode})',
          name: 'AuthRepository');
      return Left(AuthFailure(message: '[Supabase] ${e.message}'));
    } catch (e, stackTrace) {
      // 사용자가 취소한 경우 조용히 처리
      final errorMsg = e.toString().toLowerCase();
      if (errorMsg.contains('cancel') || errorMsg.contains('user_canceled')) {
        log('ℹ️ [Kakao Login] 사용자 취소', name: 'AuthRepository');
        return const Left(AuthFailure(message: ''));
      }
      log('❌ [Kakao Login] Unknown Exception: ${e.toString()}',
          name: 'AuthRepository', stackTrace: stackTrace);
      return const Left(AuthFailure(message: '카카오 로그인 중 오류가 발생했습니다.'));
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

      // 이메일 인증 여부 확인
      if (supabaseUser.emailConfirmedAt == null) {
        await supabaseClient.auth.signOut();
        return const Left(AuthFailure(
          message: '이메일 인증이 필요합니다.\n가입 시 받은 인증 코드를 입력해주세요.',
        ));
      }

      final userResponse = await supabaseClient
          .from('users')
          .select()
          .eq('id', supabaseUser.id)
          .maybeSingle();

      if (userResponse != null) {
        final user = UserModel.fromJson(userResponse);
        return Right(user.copyWith(
          emailConfirmedAt: supabaseUser.emailConfirmedAt != null
              ? DateTime.parse(supabaseUser.emailConfirmedAt!)
              : null,
        ));
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
      String email, String password,
      {String? displayName}) async {
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

      log('✅ [SignUp] 2단계: 회원가입 완료 (User ID: ${supabaseUser.id})',
          name: 'AuthRepository');
      log('   - Supabase가 자동으로 확인 이메일 발송 (6자리 OTP 포함)', name: 'AuthRepository');
      log('   - 이메일 인증 상태: ${supabaseUser.emailConfirmedAt}',
          name: 'AuthRepository');

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
        emailConfirmedAt: null,
      );

      log('✅ [SignUp] 완료: 사용자 모델 반환 (Email: $email)', name: 'AuthRepository');
      return Right(user);
    } on AuthException catch (e) {
      log('❌ [SignUp] 실패: ${e.message}', name: 'AuthRepository');

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
        // 30일 유예 soft delete — Storage 정리·영구 삭제는
        // purge-deleted-accounts 배치가 30일 후 수행
        await supabaseClient.functions.invoke('request-account-deletion');

        // Edge Function 서버 측에서 글로벌 signOut이 일어나므로
        // 로컬 signOut 실패 시에도 탈퇴 자체는 성공으로 처리
        try {
          await supabaseClient.auth.signOut();
        } catch (_) {
          // 이미 서버에서 세션 무효화됨 — 무시
        }

        // 로컬 저장소 초기화 (가이드 표시 기록 등)
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();
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
  Future<Either<Failure, void>> restoreAccount() async {
    if (!await networkInfo.isConnected) {
      return const Left(NetworkFailure(message: '인터넷 연결을 확인해주세요.'));
    }

    try {
      await supabaseClient.rpc('restore_my_account');
      return const Right(null);
    } catch (e) {
      return Left(
          GeneralFailure(message: '계정 복구 중 오류가 발생했습니다: ${e.toString()}'));
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

      await supabaseClient.from('users').update(updateData).eq('id', user.uid);

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
      final fileName =
          'profiles/${user.id}/profile_${DateTime.now().millisecondsSinceEpoch}.$fileExt';

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
