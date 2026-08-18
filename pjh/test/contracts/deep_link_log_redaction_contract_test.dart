import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('deep link 로그는 URI·query·fragment·인증 값을 기록하지 않는다', () {
    final source = File('lib/main.dart').readAsStringSync();
    final deepLinks = source.substring(
      source.indexOf('Future<void> _initDeepLinks()'),
      source.indexOf('@override\n  Widget build(BuildContext context)'),
    );

    expect(deepLinks, isNot(contains(r"$uri")));
    expect(deepLinks, isNot(contains('uri.queryParameters')));
    expect(deepLinks, isNot(contains('uri.fragment')));
    expect(deepLinks, isNot(contains(r"$err")));
    expect(deepLinks, isNot(contains(r"$error")));
    expect(deepLinks, contains('이메일 인증 callback 처리'));
  });
}
