class PrescriptionItem {
  final String medicine;
  final String instruction;
  final String duration;
  const PrescriptionItem({required this.medicine, required this.instruction, this.duration = ''});
}

class SolutionModel {
  final String diagnosis;
  final List<PrescriptionItem> prescription;
  final String note;
  final DateTime issuedAt;
  final DateTime? followUpDate;
  final String? attachmentUrl;

  const SolutionModel({
    required this.diagnosis,
    required this.prescription,
    required this.note,
    required this.issuedAt,
    this.followUpDate,
    this.attachmentUrl,
  });

  /// Backend shape: { text, prescription: { medications: [{name,dosage,duration}], instructions, attachmentUrl }, followUpDate, createdAt }
  factory SolutionModel.fromJson(Map<String, dynamic> json) {
    final prescriptionJson = (json['prescription'] as Map?) ?? const {};
    final medications = (prescriptionJson['medications'] as List?) ?? const [];
    return SolutionModel(
      diagnosis: (json['text'] as String?) ?? '',
      prescription: medications
          .map((m) => PrescriptionItem(
                medicine: (m['name'] as String?) ?? '',
                instruction: (m['dosage'] as String?) ?? '',
                duration: (m['duration'] as String?) ?? '',
              ))
          .toList(),
      note: (prescriptionJson['instructions'] as String?) ?? '',
      issuedAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      followUpDate: json['followUpDate'] != null ? DateTime.parse(json['followUpDate'] as String).toLocal() : null,
      attachmentUrl: prescriptionJson['attachmentUrl'] as String?,
    );
  }

  Map<String, dynamic> toRequestJson() => {
        'text': diagnosis,
        'prescription': {
          'medications': prescription.map((p) => {'name': p.medicine, 'dosage': p.instruction, 'duration': p.duration}).toList(),
          'instructions': note,
          if (attachmentUrl != null) 'attachmentUrl': attachmentUrl,
        },
        if (followUpDate != null) 'followUpDate': followUpDate!.toUtc().toIso8601String(),
      };
}
