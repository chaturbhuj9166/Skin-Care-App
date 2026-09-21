class DoctorModel {
  final String id;
  final String name;
  final String specialization;
  final int experienceYears;
  final double rating;
  final int reviewCount;
  final bool isOnline;
  final bool isAvailable;
  final int avatarSeed; // used to derive a consistent placeholder avatar color/initial
  final String? avatarUrl;

  const DoctorModel({
    required this.id,
    required this.name,
    required this.specialization,
    required this.experienceYears,
    required this.rating,
    required this.reviewCount,
    required this.isOnline,
    this.isAvailable = true,
    required this.avatarSeed,
    this.avatarUrl,
  });

  String get initials {
    final parts = name.replaceFirst('Dr. ', '').split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.length >= 2) return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    if (parts.isEmpty) return '?';
    return parts[0].substring(0, parts[0].length < 2 ? parts[0].length : 2).toUpperCase();
  }

  factory DoctorModel.fromJson(Map<String, dynamic> json) => DoctorModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'Doctor',
        specialization: (json['specialization'] as String?) ?? 'Dermatologist',
        experienceYears: (json['experience'] as num?)?.toInt() ?? 0,
        // Real average from the Rating table; no reviews yet shows as "not yet rated".
        rating: (json['rating'] as num?)?.toDouble() ?? (json['avgRating'] as num?)?.toDouble() ?? 0,
        reviewCount: (json['reviewCount'] as num?)?.toInt() ?? 0,
        isOnline: (json['isAvailable'] as bool?) ?? true,
        isAvailable: (json['isAvailable'] as bool?) ?? true,
        avatarSeed: (json['id'] as String).hashCode,
        avatarUrl: json['avatar'] as String?,
      );
}
