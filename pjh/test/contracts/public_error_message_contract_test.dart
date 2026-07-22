import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/core/error/error_messages.dart';

void main() {
  test('민감한 인증 원문은 고정된 공개 오류로 치환한다', () {
    const sensitive = [
      'AuthException token=secret',
      'https://project.supabase.co/auth/v1/callback',
      'oauth code verifier failed',
      'select auth.uid() from public.users',
      '/Users/jena/private/path',
    ];

    for (final raw in sensitive) {
      final safe = publicAuthErrorMessage(raw);
      expect(safe, ErrorMessages.authOperationFailed);
      expect(safe, isNot(contains(raw)));
    }
  });

  test('이미 정제된 한국어 안내는 유지한다', () {
    const message = '네트워크 연결을 확인한 뒤 다시 시도해주세요.';
    expect(publicAuthErrorMessage(message), message);
  });
}
