// firebase_options.dart
// Android (Google Play) 출시 기준 — iOS는 추후 추가 예정
// API 키는 secrets.dart에서 관리 (git 미추적)

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'config/secrets.dart';

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web 플랫폼은 지원하지 않습니다.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        throw UnsupportedError(
          'iOS Firebase 설정이 아직 완료되지 않았습니다.\n'
          'Firebase Console → iOS 앱 등록 → GoogleService-Info.plist 배치 후 설정하세요.',
        );
      default:
        throw UnsupportedError('지원하지 않는 플랫폼입니다.');
    }
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
