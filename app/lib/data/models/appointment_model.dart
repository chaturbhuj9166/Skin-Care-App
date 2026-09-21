enum CallStatus { scheduled, ongoing, completed, cancelled }

class AppointmentModel {
  final String id;
  final String caseId;
  final String patientOrDoctorName;
  final int avatarSeed;
  final DateTime scheduledAt;
  final CallStatus status;
  final bool isVideo;

  const AppointmentModel({
    required this.id,
    required this.caseId,
    required this.patientOrDoctorName,
    required this.avatarSeed,
    required this.scheduledAt,
    this.status = CallStatus.scheduled,
    this.isVideo = true,
  });

  static CallStatus _statusFrom(String s) => switch (s) {
        'ONGOING' => CallStatus.ongoing,
        'COMPLETED' => CallStatus.completed,
        'CANCELLED' => CallStatus.cancelled,
        _ => CallStatus.scheduled,
      };

  /// Backend shape: { id, caseId, scheduledAt, status, roomId, case: { user?: {...}, doctor?: {...} } }
  /// [isDoctorView] picks whether the "other side" shown is the patient (doctor app) or the doctor (user app).
  factory AppointmentModel.fromJson(Map<String, dynamic> json, {required bool isDoctorView}) {
    final caseJson = (json['case'] as Map?) ?? const {};
    final other = isDoctorView ? (caseJson['user'] as Map?) : (caseJson['doctor'] as Map?);
    final name = (other?['name'] as String?) ?? 'Unknown';
    return AppointmentModel(
      id: json['id'] as String,
      caseId: (caseJson['id'] as String?) ?? json['caseId'] as String,
      patientOrDoctorName: name,
      avatarSeed: name.hashCode,
      scheduledAt: DateTime.parse(json['scheduledAt'] as String).toLocal(),
      status: _statusFrom(json['status'] as String? ?? 'SCHEDULED'),
    );
  }
}
