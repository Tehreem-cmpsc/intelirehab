class NotificationItemEntity {
  final String id;
  final String title;
  final String message;
  final DateTime createdAt;
  final bool isRead;

  const NotificationItemEntity({
    required this.id,
    required this.title,
    required this.message,
    required this.createdAt,
    required this.isRead,
  });
}
