import 'doctor_model.dart';
import 'solution_model.dart';
import 'message_model.dart';
import 'question_model.dart';
import 'rating_model.dart';
import 'user_model.dart';

enum CaseStatus { pending, assigned, inReview, solved, closed }

extension CaseStatusX on CaseStatus {
  String get label {
    switch (this) {
      case CaseStatus.pending:
        return 'Pending';
      case CaseStatus.assigned:
        return 'Assigned';
      case CaseStatus.inReview:
        return 'In Review';
      case CaseStatus.solved:
        return 'Solved';
      case CaseStatus.closed:
        return 'Closed';
    }
  }

  int get step {
    switch (this) {
      case CaseStatus.pending:
        return 0;
      case CaseStatus.assigned:
        return 1;
      case CaseStatus.inReview:
        return 2;
      case CaseStatus.solved:
        return 3;
      case CaseStatus.closed:
        return 4;
    }
  }
}

class QuestionAnswer {
  final String question;
  final String answer;
  const QuestionAnswer({required this.question, required this.answer});
}

class CaseModel {
  final String id;
  final String caseNumber;
  final DateTime submittedAt;
  CaseStatus status;
  DoctorModel? doctor;
  final UserModel? patient; // the case owner; populated on doctor/admin views
  final String mainConcern;
  final List<QuestionAnswer> answers;
  final List<String> photoAssets; // real backend photo URLs once wired to storage
  SolutionModel? solution;
  final List<MessageModel> messages;
  DateTime? scheduledCallAt;
  RatingModel? rating;

  CaseModel({
    required this.id,
    required this.caseNumber,
    required this.submittedAt,
    required this.status,
    required this.mainConcern,
    required this.answers,
    required this.photoAssets,
    this.doctor,
    this.patient,
    this.solution,
    List<MessageModel>? messages,
    this.scheduledCallAt,
    this.rating,
  }) : messages = messages ?? [];

  static CaseStatus _statusFrom(String s) => switch (s) {
        'ASSIGNED' => CaseStatus.assigned,
        'IN_REVIEW' => CaseStatus.inReview,
        'SOLVED' => CaseStatus.solved,
        'CLOSED' => CaseStatus.closed,
        _ => CaseStatus.pending,
      };

  static String _formatAnswer(dynamic value) {
    if (value is bool) return value ? 'Yes' : 'No';
    if (value is List) return value.length > 3 || value.isEmpty ? '${value.length} selected' : value.join(', ');
    return value?.toString() ?? '-';
  }

  /// [questions] resolves each answer's question id to its label/type; pass the
  /// case's own embedded questionFlow.questions when present, else the
  /// currently active flow as a best-effort fallback for older cases.
  factory CaseModel.fromJson(Map<String, dynamic> json, {List<QuestionModel> questions = const []}) {
    final answersJson = (json['answers'] as Map?)?.cast<String, dynamic>() ?? const {};
    final byId = {for (final q in questions) q.id: q};

    final answers = answersJson.entries
        .where((e) => byId[e.key]?.type != QuestionType.photo)
        .map((e) => QuestionAnswer(
              question: byId[e.key]?.title ?? e.key,
              answer: _formatAnswer(e.value),
            ))
        .toList();

    String mainConcern = 'Skin Concern';
    if (questions.isNotEmpty) {
      final first = questions.first;
      final raw = answersJson[first.id];
      if (raw is String && raw.isNotEmpty) mainConcern = raw;
    }

    final videoCalls = (json['videoCalls'] as List?) ?? const [];
    DateTime? scheduledCallAt;
    for (final call in videoCalls) {
      if (call['status'] == 'SCHEDULED') {
        scheduledCallAt = DateTime.parse(call['scheduledAt'] as String);
      }
    }

    final id = json['id'] as String;
    return CaseModel(
      id: id,
      caseNumber: 'SKC-${id.substring(0, 6).toUpperCase()}',
      submittedAt: DateTime.parse(json['createdAt'] as String),
      status: _statusFrom(json['status'] as String? ?? 'PENDING'),
      mainConcern: mainConcern,
      answers: answers,
      photoAssets: ((json['photos'] as List?) ?? const []).cast<String>(),
      doctor: json['doctor'] != null ? DoctorModel.fromJson((json['doctor'] as Map).cast<String, dynamic>()) : null,
      patient: json['user'] != null ? UserModel.fromJson((json['user'] as Map).cast<String, dynamic>()) : null,
      solution: json['solution'] != null ? SolutionModel.fromJson((json['solution'] as Map).cast<String, dynamic>()) : null,
      scheduledCallAt: scheduledCallAt,
      rating: json['rating'] != null ? RatingModel.fromJson((json['rating'] as Map).cast<String, dynamic>()) : null,
    );
  }
}
