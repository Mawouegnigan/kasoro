class ConversationModel {
  const ConversationModel({
    required this.id,
    this.name,
    required this.isGroup,
    required this.createdAt,
    this.lastMessageType,
    this.lastMessageText,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadCount = 0,
  });

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id'] as String,
      name: json['name'] as String?,
      isGroup: json['is_group'] as bool? ?? false,
      createdAt: DateTime.parse(json['created_at'] as String),
      lastMessageType: json['last_message_type'] as String?,
      lastMessageText: json['last_message_text'] as String?,
      lastMessageAt: json['last_message_at'] == null
          ? null
          : DateTime.parse(json['last_message_at'] as String),
      lastMessageSenderId: json['last_message_sender_id'] as String?,
      unreadCount: (json['unread_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String id;
  final String? name;
  final bool isGroup;
  final DateTime createdAt;
  final String? lastMessageType;
  final String? lastMessageText;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final int unreadCount;
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
