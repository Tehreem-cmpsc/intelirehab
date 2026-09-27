import 'notifications_state.dart';

class NotificationsCubit {
  NotificationsState _state = const NotificationsInitial();
  NotificationsState get state => _state;

  void emit(NotificationsState newState) {
    _state = newState;
  }

  void loadNotifications() {}
}
