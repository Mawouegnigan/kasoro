class UserModel {
  const UserModel({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    required this.preferredLanguage,
    required this.isActive,
    required this.createdAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      phoneNumber: json['phone_number'] as String,
      displayName: json['display_name'] as String,
      preferredLanguage: json['preferred_language'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String phoneNumber;
  final String displayName;
  final String preferredLanguage;
  final bool isActive;
  final DateTime createdAt;

  UserModel copyWith({
    String? displayName,
    String? preferredLanguage,
    bool? isActive,
  }) {
    return UserModel(
      id: id,
      phoneNumber: phoneNumber,
      displayName: displayName ?? this.displayName,
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      isActive: isActive ?? this.isActive,
      createdAt: createdAt,
    );
  }
}
