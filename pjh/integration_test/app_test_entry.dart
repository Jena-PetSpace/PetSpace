// Integration Test 전용 앱 진입점
//
// main.dart와 달리 FlutterError.onError / PlatformDispatcher.onError를
// 오버라이드하지 않아 테스트 프레임워크와 충돌하지 않습니다.

import 'dart:async';
import 'dart:developer';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' hide AuthState;
import 'package:kakao_flutter_sdk/kakao_flutter_sdk.dart' as kakao;
import 'package:kakao_maps_flutter/kakao_maps_flutter.dart';

import 'package:meong_nyang_diary/config/injection_container.dart' as di;
import 'package:meong_nyang_diary/supabase_options.dart';
import 'package:meong_nyang_diary/config/api_config.dart';
import 'package:meong_nyang_diary/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:meong_nyang_diary/main.dart' show MeongNyangDiaryApp;

/// integration_test에서 호출할 앱 부팅 함수
Future<void> bootAppForTest() async {
  WidgetsFlutterBinding.ensureInitialized();

  // StatusBar 설정 (에러 핸들러 제외)
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.white,
    statusBarIconBrightness: Brightness.dark,
    statusBarBrightness: Brightness.light,
    systemNavigationBarColor: Colors.white,
    systemNavigationBarIconBrightness: Brightness.dark,
  ));

  // 이미지 캐시 제한
  PaintingBinding.instance.imageCache.maximumSize = 200;
  PaintingBinding.instance.imageCache.maximumSizeBytes = 50 << 20;

  // Kakao SDK
  if (ApiConfig.isKakaoLoginConfigured) {
    try {
      kakao.KakaoSdk.init(nativeAppKey: ApiConfig.kakaoAppKey);
      await KakaoMapsFlutter.init(ApiConfig.kakaoAppKey);
    } catch (e) {
      log('⚠️ Kakao SDK init failed: $e', name: 'testEntry.kakao');
    }
  }

  // Supabase
  if (SupabaseOptions.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseOptions.supabaseUrl,
        anonKey: SupabaseOptions.supabaseAnonKey,
        authOptions: const FlutterAuthClientOptions(
          authFlowType: AuthFlowType.pkce,
          detectSessionInUri: false,
        ),
        debug: false,
      );
    } catch (e) {
      // 이미 초기화된 경우 무시
      log('Supabase init skipped: $e', name: 'testEntry.supabase');
    }
  }

  // DI (첫 번째 테스트 케이스에서만 초기화, 이후엔 reset + 재초기화)
  try {
    if (di.sl.isRegistered<AuthBloc>()) {
      await di.sl.reset();
    }
    await di.init();
  } catch (e) {
    log('DI init error: $e', name: 'testEntry.di');
  }

  runApp(const MeongNyangDiaryApp());
}
