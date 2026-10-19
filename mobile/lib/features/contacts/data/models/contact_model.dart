class ContactModel {
  const ContactModel({
    required this.id,
    required this.ownerId,
    required this.contactUserId,
    this.alias,
    required this.createdAt,
  });

  factory ContactModel.fromJson(Map<String, dynamic> json) {
    return ContactModel(
      id: json['id'] as String,
      ownerId: json['owner_id'] as String,
      contactUserId: json['contact_user_id'] as String,
      alias: json['alias'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final String id;
  final String ownerId;
  final String contactUserId;
  final String? alias;
  final DateTime createdAt;
}
