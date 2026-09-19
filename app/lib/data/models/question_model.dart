enum QuestionType { singleChoice, multipleChoice, text, yesNo, rating, photo }

class QuestionOption {
  final String label;
  final String icon; // emoji-free icon key resolved in UI
  const QuestionOption({required this.label, required this.icon});
}

class QuestionModel {
  final String id;
  final String title;
  final QuestionType type;
  final List<QuestionOption> options;
  final bool required;

  const QuestionModel({
    required this.id,
    required this.title,
    required this.type,
    this.options = const [],
    this.required = true,
  });

  static QuestionType _typeFrom(String backendType) {
    switch (backendType) {
      case 'single_choice':
        return QuestionType.singleChoice;
      case 'multiple_choice':
        return QuestionType.multipleChoice;
      case 'yes_no':
        return QuestionType.yesNo;
      case 'rating':
        return QuestionType.rating;
      case 'photo_upload':
        return QuestionType.photo;
      default:
        return QuestionType.text;
    }
  }

  factory QuestionModel.fromJson(Map<String, dynamic> json) => QuestionModel(
        id: json['id'] as String,
        title: (json['text'] as String?) ?? '',
        type: _typeFrom(json['type'] as String? ?? 'text'),
        options: ((json['options'] as List?) ?? const [])
            .map((o) => QuestionOption(label: o as String, icon: 'other'))
            .toList(),
        required: (json['required'] as bool?) ?? true,
      );

  /// The key the backend expects this question's answer keyed by.
  String get backendType {
    switch (type) {
      case QuestionType.singleChoice:
        return 'single_choice';
      case QuestionType.multipleChoice:
        return 'multiple_choice';
      case QuestionType.text:
        return 'text';
      case QuestionType.yesNo:
        return 'yes_no';
      case QuestionType.rating:
        return 'rating';
      case QuestionType.photo:
        return 'photo_upload';
    }
  }
}
