import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Langue dans laquelle CE destinataire a choisi de lire/écouter CE
/// message précis. `null` tant qu'il n'a rien choisi — dans ce cas,
/// AUCUNE requête de traduction n'est lancée (comme le bouton de
/// téléchargement d'un vocal WhatsApp : rien ne se charge avant une
/// demande explicite).
///
/// Un provider par message (`family` sur l'id du message) : choisir une
/// langue pour un message n'affecte pas les autres.
class ReadingLanguageController extends FamilyNotifier<String?, String> {
  @override
  String? build(String messageId) => null;

  void select(String languageCode) {
    state = languageCode;
  }
}

final NotifierProviderFamily<ReadingLanguageController, String?, String>
    readingLanguageControllerProvider =
    NotifierProvider.family<ReadingLanguageController, String?, String>(
  ReadingLanguageController.new,
);