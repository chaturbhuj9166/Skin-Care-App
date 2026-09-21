enum TicketStatus { open, inProgress, closed }

enum TicketPriority { low, medium, high }

extension TicketStatusX on TicketStatus {
  String get label {
    switch (this) {
      case TicketStatus.open:
        return 'Open';
      case TicketStatus.inProgress:
        return 'In Progress';
      case TicketStatus.closed:
        return 'Closed';
    }
  }
}

extension TicketPriorityX on TicketPriority {
  String get label {
    switch (this) {
      case TicketPriority.low:
        return 'Low';
      case TicketPriority.medium:
        return 'Medium';
      case TicketPriority.high:
        return 'High';
    }
  }

  String get backendValue {
    switch (this) {
      case TicketPriority.low:
        return 'LOW';
      case TicketPriority.medium:
        return 'MEDIUM';
      case TicketPriority.high:
        return 'HIGH';
    }
  }
}

class TicketModel {
  final String id;
  final String subject;
  final String description;
  final TicketPriority priority;
  TicketStatus status;
  final DateTime createdAt;
  String? adminReply;

  TicketModel({
    required this.id,
    required this.subject,
    required this.description,
    required this.priority,
    this.status = TicketStatus.open,
    required this.createdAt,
    this.adminReply,
  });

  static TicketStatus _statusFrom(String s) => switch (s) {
        'IN_PROGRESS' => TicketStatus.inProgress,
        'CLOSED' => TicketStatus.closed,
        _ => TicketStatus.open,
      };

  static TicketPriority _priorityFrom(String p) => switch (p) {
        'HIGH' => TicketPriority.high,
        'LOW' => TicketPriority.low,
        _ => TicketPriority.medium,
      };

  factory TicketModel.fromJson(Map<String, dynamic> json) => TicketModel(
        id: json['id'] as String,
        subject: (json['subject'] as String?) ?? '',
        description: (json['description'] as String?) ?? '',
        priority: _priorityFrom(json['priority'] as String? ?? 'MEDIUM'),
        status: _statusFrom(json['status'] as String? ?? 'OPEN'),
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
        adminReply: json['reply'] as String?,
      );
}
