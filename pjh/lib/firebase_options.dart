// firebase_options.dart
// Android (Google Play) 출시 기준 — iOS는 추후 추가 예정
// API 키는 secrets.dart에서 관리 (git 미추적)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'config/secrets.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions? get currentPlatformOrNull {
    if (kIsWeb) return null;
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        // iOS Firebase 설정 미완료 — null 반환하여 Firebase 건너뜀
        return null;
      default:
        return null;
    }
  }

  // 하위 호환용 (기존 코드에서 참조 시)
  static FirebaseOptions get currentPlatform {
    final options = currentPlatformOrNull;
    if (options == null) {
      throw UnsupportedError('현재 플랫폼에서 Firebase가 지원되지 않습니다.');
    }
    return options;
  }

  /// Android — secrets.dart에서 키 참조
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: Secrets.firebaseApiKey,
    appId: Secrets.firebaseAppId,
    messagingSenderId: Secrets.firebaseMessagingSenderId,
    projectId: Secrets.firebaseProjectId,
    storageBucket: Secrets.firebaseStorageBucket,
  );
}
