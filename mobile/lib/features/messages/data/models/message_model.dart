enum MessageType { text, audio }

MessageType _messageTypeFromString(String value) {
  return value == 'audio' ? MessageType.audio : MessageType.text;
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.type,
    required this.originalLanguage,
    this.originalText,
    this.originalAudioUrl,
    required this.createdAt,
  });

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id'] as String,
      conversationId: json['conversation_id'] as String,
      senderId: json['sender_id'] as String,
      type: _messageTypeFromString(json['message_type'] as String),
      originalLanguage: json['original_language'] as String,
      originalText: json['original_text'] as String?,
      originalAudioUrl: json['original_audio_url'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String conversationId;
  final String senderId;
  final MessageType type;
  final String originalLanguage;
  final String? originalText;
  final String? originalAudioUrl;
  final DateTime createdAt;
}

/// Réponse de `GET /messages/{id}/in/{language}` — la route clé du
/// produit : traduction texte + synthèse vocale, mises en cache côté
/// serveur après la première lecture dans cette langue.
class MessageInLanguageModel {
  const MessageInLanguageModel({
    required this.messageId,
    required this.language,
    required this.text,
    this.audioUrl,
    required this.wasCached,
  });

  factory MessageInLanguageModel.fromJson(Map<String, dynamic> json) {
    return MessageInLanguageModel(
      messageId: json['message_id'] as String,
      language: json['language'] as String,
      text: json['text'] as String,
      audioUrl: json['audio_url'] as String?,
      wasCached: json['was_cached'] as bool? ?? false,
    );
  }

  final String messageId;
  final String language;
  final String text;
  final String? audioUrl;
  final bool wasCached;
}
