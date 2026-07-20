import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/core/services/app_package_info.dart';

void main() {
  test('빌드 번호가 있으면 version과 함께 표시한다', () {
    const info = AppPackageInfo(version: '1.2.3', buildNumber: '45');
    expect(info.displayVersion, '1.2.3 (45)');
  });

  test('빌드 번호가 비어 있으면 version만 표시한다', () {
    const info = AppPackageInfo(version: '1.2.3', buildNumber: '');
    expect(info.displayVersion, '1.2.3');
  });
}
