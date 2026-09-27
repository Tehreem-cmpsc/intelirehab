import '../../domain/entities/notification_item_entity.dart';
import '../../domain/repositories/notifications_repository.dart';
import '../datasources/notifications_remote_data_source.dart';

class NotificationsRepositoryImpl implements NotificationsRepository {
  final NotificationsRemoteDataSource remoteDataSource;

  const NotificationsRepositoryImpl(this.remoteDataSource);

  @override
  Future<List<NotificationItemEntity>> getNotifications() {
    return remoteDataSource.getNotifications();
  }
}
