// firebase_options.dart
// Android (Google Play) + iOS (App Store) 출시 기준
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
        return ios;
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

  /// iOS — apiKey·appId만 Android와 다름, 나머지는 프로젝트 공통
  static const FirebaseOptions ios = FirebaseOptions(
    apiKey: Secrets.firebaseIosApiKey,
    appId: Secrets.firebaseIosAppId,
    messagingSenderId: Secrets.firebaseMessagingSenderId,
    projectId: Secrets.firebaseProjectId,
    storageBucket: Secrets.firebaseStorageBucket,
    iosBundleId: Secrets.firebaseIosBundleId,
  );
}
