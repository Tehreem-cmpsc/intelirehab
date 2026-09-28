import '../models/notification_item_model.dart';

abstract class NotificationsRemoteDataSource {
  Future<List<NotificationItemModel>> getNotifications();
}

class NotificationsRemoteDataSourceImpl
    implements NotificationsRemoteDataSource {
  @override
  Future<List<NotificationItemModel>> getNotifications() async {
    return [];
  }
}
