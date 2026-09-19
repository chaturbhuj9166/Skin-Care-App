class UserModel {
  final String id;
  String name;
  String email;
  String phone;
  String? gender;
  int? age;
  int avatarSeed;
  String? avatarUrl;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.gender,
    this.age,
    this.avatarSeed = 1,
    this.avatarUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) => UserModel(
        id: json['id'] as String,
        name: (json['name'] as String?) ?? 'User',
        email: (json['email'] as String?) ?? '',
        phone: (json['phone'] as String?) ?? '',
        gender: json['gender'] as String?,
        age: (json['age'] as num?)?.toInt(),
        avatarSeed: (json['id'] as String).hashCode,
        avatarUrl: json['avatar'] as String?,
      );
}
