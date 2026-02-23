import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;

// Config
import 'config/injection_container.dart' as di;
import 'supabase_options.dart';
import 'config/api_config.dart';

// Shared
import 'shared/themes/app_theme.dart';

// Core
import 'core/constants/app_constants.dart';
import 'core/navigation/app_router.dart';

// Features
import 'features/auth/presentation/bloc/auth_bloc.dart';
import 'features/emotion/presentation/bloc/emotion_analysis_bloc.dart';
import 'features/social/presentation/bloc/feed_bloc.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Kakao SDK 초기화
  if (ApiConfig.isKakaoLoginConfigured) {
    kakao.KakaoSdk.init(nativeAppKey: ApiConfig.kakaoAppKey);
    log('✅ Kakao SDK 초기화 완료', name: 'main.kakao');
  } else {
    log('⚠️ Kakao 로그인을 사용하려면 API 키를 설정해주세요.', name: 'main.kakao');
  }

  // Supabase 초기화
  if (SupabaseOptions.isConfigured) {
    await Supabase.initialize(
      url: SupabaseOptions.supabaseUrl,
      anonKey: SupabaseOptions.supabaseAnonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
        // Supabase가 deep link를 자동으로 처리하지 않도록 설정
        // 대신 _handleDeepLink에서 수동으로 처리
        // NOTE: detectSessionInUri를 false로 설정하면 Supabase가 deep link를 자동으로 감지하지 않음
      ),
      // Deep link 자동 처리 비활성화 - Supabase가 모든 deep link를 가로채는 것을 방지
      // 이제 com.petspace.app scheme만 수동으로 처리하고, kakao scheme은 Kakao SDK에게 넘김
      debug: false,
    );
    log('✅ Supabase 초기화 완료', name: 'main.supabase');
  } else {
    log('⚠️ Supabase 설정이 필요합니다. supabase_options.dart 파일을 확인해주세요.', name: 'main.supabase');
  }

  // API 설정 확인 및 안내
  log('\n📱 펫페이스 설정 현황:', name: 'main.config');
  log('✅ Supabase: ${SupabaseOptions.isConfigured ? "설정됨" : "미설정 (데모용)"}', name: 'main.config');
  final features = ApiConfig.availableFeatures;
  log('🔧 사용 가능한 기능들:', name: 'main.config');
  for (final feature in features) {
    log('   • $feature', name: 'main.features');
  }

  if (!ApiConfig.isGoogleLoginConfigured && !ApiConfig.isKakaoLoginConfigured) {
    log('\n⚠️ 실제 소셜 로그인을 위해서는 API 키 설정이 필요합니다.', name: 'main.warning');
    log('   lib/config/api_config.dart 파일을 확인하세요.', name: 'main.warning');
  }

  await di.init();

  runApp(const MeongNyangDiaryApp());
}

class MeongNyangDiaryApp extends StatefulWidget {
  const MeongNyangDiaryApp({super.key});

  @override
  State<MeongNyangDiaryApp> createState() => _MeongNyangDiaryAppState();
}

class _MeongNyangDiaryAppState extends State<MeongNyangDiaryApp> {
  final _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    // 앱이 실행 중일 때 Deep Link 처리
    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      log('Deep Link received: $uri', name: 'DeepLink');

      // Kakao OAuth 콜백은 app_links로 처리하지 않음 - Kakao SDK가 직접 처리해야 함
      if (uri.scheme.startsWith('kakao') && uri.host == 'oauth') {
        log('✅ Kakao OAuth callback - skipping app_links processing', name: 'DeepLink.Kakao');
        // 중요: 여기서 아무것도 하지 않고 그냥 return하면 Kakao SDK가 받을 수 없음
        // 해결: app_links 사용 안 함 - AndroidManifest.xml의 intent-filter가 직접 처리
        return;
      }

      _handleDeepLink(uri);
    }, onError: (err) {
      log('Deep Link error: $err', name: 'DeepLink');
    });

    // 앱이 종료된 상태에서 Deep Link로 시작된 경우
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) {
        log('Initial Deep Link: $uri', name: 'DeepLink');

        // Kakao OAuth 콜백은 app_links로 처리하지 않음
        if (uri.scheme.startsWith('kakao') && uri.host == 'oauth') {
          log('✅ Initial Kakao OAuth callback - skipping app_links processing', name: 'DeepLink.Kakao');
          return;
        }

        _handleDeepLink(uri);
      }
    } catch (err) {
      log('Failed to get initial link: $err', name: 'DeepLink');
    }
  }

  void _handleDeepLink(Uri uri) {
    log('Handling deep link: $uri', name: 'DeepLink');
    log('Deep Link scheme: ${uri.scheme}', name: 'DeepLink');
    log('Deep Link host: ${uri.host}', name: 'DeepLink');
    log('Deep Link path: ${uri.path}', name: 'DeepLink');
    log('Deep Link fragment: ${uri.fragment}', name: 'DeepLink');
    log('Deep Link query params: ${uri.queryParameters}', name: 'DeepLink');

    // Kakao OAuth 콜백 처리
    // kakaoc9e18a9067b1d5b615849d787d7ef05b://oauth 형태의 링크
    if (uri.scheme.startsWith('kakao') && uri.host == 'oauth') {
      log('✅ Kakao OAuth callback detected - Kakao SDK will handle it automatically', name: 'DeepLink.Kakao');
      // Kakao SDK가 자동으로 OAuth 콜백을 처리하므로 GoRouter로 라우팅하지 않음
      // AuthBloc의 signInWithKakao가 완료되면 AuthAuthenticated 상태로 변경되어 자동으로 프로필 페이지로 이동
      return;
    }

    // Supabase 이메일 인증 콜백 처리
    // com.petspace.app://login-callback#... 형태의 링크
    if (uri.host == 'login-callback' || uri.path.contains('login-callback')) {
      log('Email verification callback detected', name: 'DeepLink');
      // Supabase에 deep link 수동 전달
      Supabase.instance.client.auth.getSessionFromUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final authBloc = di.sl<AuthBloc>()..add(AuthStarted());

    return ScreenUtilInit(
      // 디자인 기준 사이즈 (iPhone 13/14 기준 - 390x844)
      designSize: const Size(390, 844),
      minTextAdapt: true,
      splitScreenMode: true,
      builder: (context, child) {
        return MultiBlocProvider(
          providers: [
            BlocProvider<AuthBloc>(
              create: (_) => authBloc,
            ),
            BlocProvider<EmotionAnalysisBloc>(
              create: (_) => di.sl<EmotionAnalysisBloc>(),
            ),
            BlocProvider<FeedBloc>(
              create: (_) => di.sl<FeedBloc>(),
            ),
          ],
          child: MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: ThemeMode.light,
            routerConfig: AppRouter.createRouter(authBloc),
          ),
        );
      },
    );
  }
}
