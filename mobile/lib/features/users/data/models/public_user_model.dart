/// Représentation "publique" d'un utilisateur, telle que renvoyée par
/// `GET /users`, `GET /users/{id}`. Utilisée par les features contacts,
/// conversations et messages pour afficher des noms/langues sans dépendre
/// du modèle `UserModel` de la feature auth (qui porte la sémantique de
/// "session courante").
///
/// Note de cohérence : `UserModel` (dans `features/auth`) et ce modèle
/// représentent la même ressource backend sous deux angles différents.
/// À terme, `UserModel` de la feature auth devrait simplement encapsuler
/// un `PublicUserModel` plutôt que dupliquer les champs — laissé tel
/// quel pour l'instant pour ne pas complexifier prématurément.
class PublicUserModel {
  const PublicUserModel({
    required this.id,
    required this.phoneNumber,
    required this.displayName,
    required this.preferredLanguage,
    required this.isActive,
  });

  factory PublicUserModel.fromJson(Map<String, dynamic> json) {
    return PublicUserModel(
      id: json['id'] as String,
      phoneNumber: json['phone_number'] as String,
      displayName: json['display_name'] as String,
      preferredLanguage: json['preferred_language'] as String,
      isActive: json['is_active'] as bool? ?? true,
    );
  }

  final String id;
  final String phoneNumber;
  final String displayName;
  final String preferredLanguage;
  final bool isActive;
}
