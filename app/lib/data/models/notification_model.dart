enum NotificationType { caseUpdate, message, appointment, system }

class NotificationModel {
  final String id;
  final String title;
  final String body;
  final DateTime time;
  bool isRead;
  final NotificationType type;
  final String? caseId;

  NotificationModel({
    required this.id,
    required this.title,
    required this.body,
    required this.time,
    this.isRead = false,
    this.type = NotificationType.system,
    this.caseId,
  });

  static NotificationType _typeFrom(String? backendType) {
    switch (backendType) {
      case 'NEW_MESSAGE':
        return NotificationType.message;
      case 'CALL_SCHEDULED':
        return NotificationType.appointment;
      case 'CASE_ASSIGNED':
      case 'NEW_CASE':
      case 'SOLUTION_ADDED':
        return NotificationType.caseUpdate;
      default:
        return NotificationType.system;
    }
  }

  factory NotificationModel.fromJson(Map<String, dynamic> json) => NotificationModel(
        id: json['id'] as String,
        title: (json['title'] as String?) ?? '',
        body: (json['body'] as String?) ?? '',
        time: DateTime.parse(json['createdAt'] as String),
        isRead: (json['isRead'] as bool?) ?? false,
        type: _typeFrom(json['type'] as String?),
        caseId: json['caseId'] as String?,
      );
}
