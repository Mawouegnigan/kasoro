class ConversationModel {
  const ConversationModel({
    required this.id,
    this.name,
    required this.isGroup,
    required this.createdAt,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      isGroup: json['is_group'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String? name;
  final bool isGroup;
  final DateTime createdAt;
}

class ConversationMemberModel {
  const ConversationMemberModel({
    required this.userId,
    required this.language,
  });

  factory ConversationMemberModel.fromJson(Map<String, dynamic> json) {
    return ConversationMemberModel(
      userId: json['user_id'] as String,
      language: json['language'] as String,
    );
  }

  final String userId;
  final String language;
}
