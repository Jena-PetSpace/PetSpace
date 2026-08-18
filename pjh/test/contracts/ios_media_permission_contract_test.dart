import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('iOS는 실제 사진 촬영 권한만 선언하고 사용하지 않는 마이크를 요청하지 않는다', () {
    final info = File('ios/Runner/Info.plist').readAsStringSync();
    final camera = File(
      'lib/features/emotion/presentation/pages/guided_camera_page.dart',
    ).readAsStringSync();

    expect(info, contains('NSCameraUsageDescription'));
    expect(info, contains('NSPhotoLibraryUsageDescription'));
    expect(info, contains('NSPhotoLibraryAddUsageDescription'));
    expect(info, isNot(contains('NSMicrophoneUsageDescription')));
    expect(camera, contains('enableAudio: false'));
    expect(camera, isNot(contains('startVideoRecording')));
  });
}
