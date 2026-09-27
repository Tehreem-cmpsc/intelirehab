import '../entities/notification_item_entity.dart';
import '../repositories/notifications_repository.dart';

class GetNotificationsUsecase {
  final NotificationsRepository repository;
  const GetNotificationsUsecase(this.repository);

  Future<List<NotificationItemEntity>> call() {
    return repository.getNotifications();
  }
}
