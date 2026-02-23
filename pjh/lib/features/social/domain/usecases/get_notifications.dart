import '../../../../core/error/failures.dart';
import '../../../../core/usecases/usecase.dart';
import '../entities/notification.dart';
import '../repositories/social_repository.dart';
import 'package:dartz/dartz.dart';

class GetNotificationsParams {
  final String userId;
  final int limit;
  final String? lastNotificationId;

  const GetNotificationsParams({
    required this.userId,
    this.limit = 20,
    this.lastNotificationId,
  });
}

class GetNotifications extends UseCase<List<Notification>, GetNotificationsParams> {
  final SocialRepository repository;

  GetNotifications(this.repository);

  @override
  Future<Either<Failure, List<Notification>>> call(GetNotificationsParams params) async {
    return await repository.getNotifications(
      userId: params.userId,
      limit: params.limit,
      lastNotificationId: params.lastNotificationId,
    );
  }
}