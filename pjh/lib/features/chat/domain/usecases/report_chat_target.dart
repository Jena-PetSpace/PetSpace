import 'package:dartz/dartz.dart';
import 'package:equatable/equatable.dart';
import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../repositories/chat_repository.dart';

/// 채팅 신고 대상 종류.
enum ChatReportTarget { user, message }

/// 채팅 신고 저장 usecase. 대상이 사용자면 reportChatUser,
/// 메시지면 reportChatMessage 로 위임한다.
class ReportChatTarget extends UseCase<void, ReportChatTargetParams> {
  final ChatRepository repository;

  ReportChatTarget(this.repository);

  @override
  Future<Either<Failure, void>> call(ReportChatTargetParams params) {
    switch (params.target) {
      case ChatReportTarget.user:
        return repository.reportChatUser(
          reportedUserId: params.targetId,
          reporterId: params.reporterId,
          reason: params.reason,
        );
      case ChatReportTarget.message:
        return repository.reportChatMessage(
          messageId: params.targetId,
          reporterId: params.reporterId,
          reason: params.reason,
        );
    }
  }
}

class ReportChatTargetParams extends Equatable {
  final ChatReportTarget target;

  /// 사용자 신고면 reportedUserId, 메시지 신고면 messageId.
  final String targetId;
  final String reporterId;
  final String reason;

  const ReportChatTargetParams({
    required this.target,
    required this.targetId,
    required this.reporterId,
    required this.reason,
  });

  @override
  List<Object?> get props => [target, targetId, reporterId, reason];
}
