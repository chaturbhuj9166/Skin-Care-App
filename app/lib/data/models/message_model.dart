enum SenderType { user, doctor }

class MessageModel {
  final String id;
  final SenderType sender;
  final String text;
  final String? fileUrl;
  final DateTime time;
  bool isRead;

  MessageModel({
    required this.id,
    required this.sender,
    required this.text,
    this.fileUrl,
    required this.time,
    this.isRead = true,
  });

  bool get isImage {
    if (fileUrl == null) return false;
    final lower = fileUrl!.toLowerCase();
    return lower.endsWith('.jpg') || lower.endsWith('.jpeg') || lower.endsWith('.png') || lower.endsWith('.webp') || lower.endsWith('.gif');
  }

  factory MessageModel.fromJson(Map<String, dynamic> json) => MessageModel(
        id: json['id'] as String,
        sender: json['senderType'] == 'DOCTOR' ? SenderType.doctor : SenderType.user,
        text: (json['text'] as String?) ?? '',
        fileUrl: json['fileUrl'] as String?,
        time: DateTime.parse(json['createdAt'] as String).toLocal(),
        isRead: (json['isRead'] as bool?) ?? false,
      );
}
