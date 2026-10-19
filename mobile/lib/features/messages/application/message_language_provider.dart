import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/application/auth_state.dart';

/// Langue sélectionnée pour le prochain message à envoyer (texte ou
/// audio) dans une conversation donnée. Initialisée à la langue
/// préférée du profil, mais modifiable ponctuellement par
/// l'utilisateur avant d'enregistrer ou d'envoyer — utile pour
/// quelqu'un de bilingue qui écrit/parle parfois dans une langue
/// différente de son réglage par défaut, sans avoir à changer ce
/// réglage à chaque fois.
///
/// Un provider par conversation (`family`) : changer de langue dans
/// une conversation ne doit pas affecter les autres.
class MessageLanguageController extends FamilyNotifier<String, String> {
  @override
  String build(String conversationId) {
    // IMPORTANT : `ref.read`, pas `ref.watch`. Avec `watch`, ce
    // contrôleur se reconstruit — et donc RÉINITIALISE la sélection
    // de l'utilisateur — à chaque fois que l'état d'auth notifie un
    // changement, même sans rapport avec la sélection de langue. C'est
    // exactement le bug observé : sélectionner "yoruba" puis voir le
    // message partir quand même en "français". `read` calcule la
    // valeur par défaut UNE FOIS à la création, sans jamais écraser
    // un choix explicite fait ensuite via `select()`.
    final authState = ref.read(authControllerProvider);
    return authState is AuthAuthenticated ? authState.user.preferredLanguage : 'fr';
  }

  void select(String languageCode) {
    state = languageCode;
  }
}

final NotifierProviderFamily<MessageLanguageController, String, String>
    messageLanguageControllerProvider =
    NotifierProvider.family<MessageLanguageController, String, String>(
  MessageLanguageController.new,
);
