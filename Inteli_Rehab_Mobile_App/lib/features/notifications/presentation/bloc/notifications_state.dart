abstract class NotificationsState {
  const NotificationsState();
}

class NotificationsInitial extends NotificationsState {
  const NotificationsInitial();
}

class NotificationsLoading extends NotificationsState {
  const NotificationsLoading();
}

class NotificationsLoaded extends NotificationsState {
  final List<dynamic> notifications;
  const NotificationsLoaded(this.notifications);
}

class NotificationsError extends NotificationsState {
  final String message;
  const NotificationsError(this.message);
}
