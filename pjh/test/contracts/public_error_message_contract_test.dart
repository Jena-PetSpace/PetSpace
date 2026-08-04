import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:meong_nyang_diary/core/error/error_messages.dart';
import 'package:meong_nyang_diary/core/error/failures.dart';

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

  test('일반 기능도 내부 상세와 영문 SDK 원문을 공개하지 않는다', () {
    const rawMessages = [
      'PostgrestException(message: permission denied)',
      'SocketException: failed host lookup',
      'https://project.supabase.co/rest/v1/posts',
      'package:meong_nyang_diary/page.dart:42',
      '/private/var/mobile/image.jpg',
      'plain english backend failure',
      '처리 실패: 123e4567-e89b-12d3-a456-426614174000',
      '사용자 jena@example.com 조회 실패',
      '{"message":"처리 실패"}',
    ];

    for (final raw in rawMessages) {
      final safe = publicErrorMessage(raw);
      expect(safe, ErrorMessages.operationFailed);
      expect(safe, isNot(contains(raw)));
    }
  });

  test('기능별 fallback과 짧은 한국어 validation 안내를 보존한다', () {
    expect(
      publicErrorMessage(
        'AuthException token=secret',
        fallback: ErrorMessages.petUpdateFailed,
      ),
      ErrorMessages.petUpdateFailed,
    );
    const validation = '이름을 입력해주세요.';
    expect(publicErrorMessage(validation), validation);
    const numericValidation = '비밀번호는 영문과 숫자를 포함해 8자 이상 입력해주세요.';
    expect(publicErrorMessage(numericValidation), numericValidation);
  });

  test('ErrorInfo도 Failure 내부 상세를 공개 문구로 정제한다', () {
    const failure = ServerFailure(
      message: '처리 실패: 123e4567-e89b-12d3-a456-426614174000',
    );
    final info = ErrorInfo.fromFailure(failure);
    expect(info.message, ErrorMessages.databaseError);
    expect(info.message, isNot(contains('123e4567')));
  });

  test('공용 UI와 저장·대표 반려동물 상태는 원문을 직접 표시하지 않는다', () {
    final errorDialog =
        File('lib/shared/widgets/error_dialog.dart').readAsStringSync();
    final lazyList =
        File('lib/shared/widgets/lazy_load_list.dart').readAsStringSync();
    final bookmarkBloc = File(
      'lib/features/social/presentation/bloc/bookmark_bloc.dart',
    ).readAsStringSync();
    final petManagement = File(
      'lib/features/pets/presentation/pages/pet_management_page.dart',
    ).readAsStringSync();

    expect(
        errorDialog, isNot(contains('Text(\n              failure.message')));
    expect(errorDialog, contains('ErrorInfo.fromFailure(failure).message'));
    expect(lazyList, isNot(contains('e.toString()')));
    expect(bookmarkBloc, isNot(contains('Error: failure.message')));
    expect(bookmarkBloc, contains('publicErrorMessage(failure.message)'));
    expect(
      petManagement,
      isNot(contains('_showFeedback(state.selectionMessage!)')),
    );
  });

  test('남은 raw UI 직접 노출은 Home/AI 잠금 allowlist 8개로만 제한한다', () {
    const lockedAllowlist = {
      'lib/features/emotion/presentation/pages/ai_history_page.dart',
      'lib/features/emotion/presentation/pages/emotion_analysis_page.dart',
      'lib/features/emotion/presentation/pages/emotion_result_loader_page.dart',
      'lib/features/emotion/presentation/pages/emotion_result_page.dart',
      'lib/features/emotion/presentation/pages/emotion_timeline_page.dart',
      'lib/features/emotion/presentation/pages/health_result_page.dart',
      'lib/features/my/presentation/pages/my_emotion_history_page.dart',
      'lib/features/mbti/presentation/widgets/home_mbti_card.dart',
    };
    final rawPatterns = [
      RegExp(r'Text\(\s*(?:state|failure)\.message'),
      RegExp(
        r'''Text\(\s*'[^']{0,80}(?:오류|실패)[^']{0,80}(?:\$\{?e|\$\{?state\.message)''',
      ),
      RegExp(r'_error(?:Message)?\s*=\s*failure\.message'),
      RegExp(r'_showErrorDialog\(result\.message'),
      RegExp(r'Text\(\s*cubit\.state\.message'),
    ];
    final found = <String>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final source = entity.readAsStringSync();
      if (source.contains('publicAuthErrorMessage(state.message)')) continue;
      if (rawPatterns.any((pattern) => pattern.hasMatch(source))) {
        found.add(entity.path);
      }
    }
    expect(found, lockedAllowlist);
  });
}
