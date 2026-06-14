import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:meong_nyang_diary/core/error/failures.dart';
import 'package:meong_nyang_diary/features/chat/domain/repositories/chat_repository.dart';
import 'package:meong_nyang_diary/features/chat/domain/usecases/report_chat_target.dart';

class MockChatRepository extends Mock implements ChatRepository {}

void main() {
  late MockChatRepository repo;
  late ReportChatTarget uc;

  setUp(() {
    repo = MockChatRepository();
    uc = ReportChatTarget(repo);
  });

  // ── 사용자 신고 ───────────────────────────────────────────────────────────
  group('사용자 신고', () {
    test('성공 → reportChatUser 위임 + Right(void)', () async {
      when(() => repo.reportChatUser(
            reportedUserId: any(named: 'reportedUserId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => const Right(null));

      final result = await uc(const ReportChatTargetParams(
        target: ChatReportTarget.user,
        targetId: 'user-002',
        reporterId: 'user-001',
        reason: '스팸 또는 광고',
      ));

      expect(result.isRight(), true);
      verify(() => repo.reportChatUser(
            reportedUserId: 'user-002',
            reporterId: 'user-001',
            reason: '스팸 또는 광고',
          )).called(1);
      verifyNever(() => repo.reportChatMessage(
            messageId: any(named: 'messageId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          ));
    });

    test('실패 → Left(ServerFailure)', () async {
      when(() => repo.reportChatUser(
            reportedUserId: any(named: 'reportedUserId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          )).thenAnswer(
          (_) async => const Left(ServerFailure(message: '신고 접수에 실패했습니다')));

      final result = await uc(const ReportChatTargetParams(
        target: ChatReportTarget.user,
        targetId: 'user-002',
        reporterId: 'user-001',
        reason: '기타',
      ));

      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<ServerFailure>()), (_) => fail('실패해야 함'));
    });
  });

  // ── 메시지 신고 ───────────────────────────────────────────────────────────
  group('메시지 신고', () {
    test('성공 → reportChatMessage 위임 + Right(void)', () async {
      when(() => repo.reportChatMessage(
            messageId: any(named: 'messageId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => const Right(null));

      final result = await uc(const ReportChatTargetParams(
        target: ChatReportTarget.message,
        targetId: 'msg-100',
        reporterId: 'user-001',
        reason: '혐오 발언 또는 차별',
      ));

      expect(result.isRight(), true);
      verify(() => repo.reportChatMessage(
            messageId: 'msg-100',
            reporterId: 'user-001',
            reason: '혐오 발언 또는 차별',
          )).called(1);
      verifyNever(() => repo.reportChatUser(
            reportedUserId: any(named: 'reportedUserId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          ));
    });

    test('네트워크 실패 → Left(NetworkFailure)', () async {
      when(() => repo.reportChatMessage(
            messageId: any(named: 'messageId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          )).thenAnswer(
          (_) async => const Left(NetworkFailure(message: '네트워크 연결을 확인해주세요.')));

      final result = await uc(const ReportChatTargetParams(
        target: ChatReportTarget.message,
        targetId: 'msg-100',
        reporterId: 'user-001',
        reason: '기타',
      ));

      expect(result.isLeft(), true);
      result.fold((f) => expect(f, isA<NetworkFailure>()), (_) => fail('실패해야 함'));
    });
  });

  // ── 중복 신고 정책 ─────────────────────────────────────────────────────────
  group('중복 신고', () {
    test('같은 대상 재신고 허용 — 매번 새 신고로 접수(Right)', () async {
      when(() => repo.reportChatUser(
            reportedUserId: any(named: 'reportedUserId'),
            reporterId: any(named: 'reporterId'),
            reason: any(named: 'reason'),
          )).thenAnswer((_) async => const Right(null));

      const params = ReportChatTargetParams(
        target: ChatReportTarget.user,
        targetId: 'user-002',
        reporterId: 'user-001',
        reason: '스팸 또는 광고',
      );

      final first = await uc(params);
      final second = await uc(params);

      expect(first.isRight(), true);
      expect(second.isRight(), true);
      // 차단/UNIQUE 제약 없이 두 번 모두 접수됨(social과 동일 정책)
      verify(() => repo.reportChatUser(
            reportedUserId: 'user-002',
            reporterId: 'user-001',
            reason: '스팸 또는 광고',
          )).called(2);
    });
  });
}
