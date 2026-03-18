// firebase_options.dart
// Android (Google Play) 출시 기준 — iOS는 추후 추가 예정
// google-services.json (android/app/) 기반

import 'package:firebase_core/firebase_core.dart' show FirebaseOptions;
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;

class DefaultFirebaseOptions {
  static FirebaseOptions get currentPlatform {
    if (kIsWeb) {
      throw UnsupportedError('Web 플랫폼은 지원하지 않습니다.');
    }
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return android;
      case TargetPlatform.iOS:
        // iOS 출시 준비 시 GoogleService-Info.plist 추가 후 아래 값 교체
        throw UnsupportedError(
          'iOS Firebase 설정이 아직 완료되지 않았습니다.\n'
          'Firebase Console → iOS 앱 등록 → GoogleService-Info.plist 배치 후 설정하세요.',
        );
      default:
        throw UnsupportedError('지원하지 않는 플랫폼입니다.');
    }
  }

  /// Android — android/app/google-services.json 기반
  static const FirebaseOptions android = FirebaseOptions(
    apiKey: 'AIzaSyBc6Q5SJV4FgER-6RWzRNyh70qvGuX3rVE',
    appId: '1:295912994007:android:petspace',
    messagingSenderId: '295912994007',
    projectId: 'project-5e5638c5-de70-498d-8f2',
    storageBucket: 'project-5e5638c5-de70-498d-8f2.appspot.com',
  );

  // iOS 설정 추가 시 아래 주석 해제 후 값 채우기
  // static const FirebaseOptions ios = FirebaseOptions(
  //   apiKey: 'REPLACE_WITH_IOS_API_KEY',
  //   appId: 'REPLACE_WITH_IOS_APP_ID',
  //   messagingSenderId: '295912994007',
  //   projectId: 'project-5e5638c5-de70-498d-8f2',
  //   storageBucket: 'project-5e5638c5-de70-498d-8f2.appspot.com',
  //   iosBundleId: 'com.petspace.app',
  // );
}
