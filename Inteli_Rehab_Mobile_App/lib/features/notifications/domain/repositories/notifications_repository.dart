import '../entities/notification_item_entity.dart';

abstract class NotificationsRepository {
  Future<List<NotificationItemEntity>> getNotifications();
}
