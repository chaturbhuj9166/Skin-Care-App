class RatingModel {
  final int score;
  final String? comment;
  final DateTime createdAt;

  const RatingModel({required this.score, this.comment, required this.createdAt});

  factory RatingModel.fromJson(Map<String, dynamic> json) => RatingModel(
        score: (json['score'] as num).toInt(),
        comment: json['comment'] as String?,
        createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      );
}
