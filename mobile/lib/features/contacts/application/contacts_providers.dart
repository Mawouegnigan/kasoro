import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/application/auth_providers.dart';
import '../../auth/application/auth_state.dart';
import '../data/models/contact_model.dart';
import '../data/repositories/contacts_repository.dart';

/// Id de l'utilisateur courant, lu depuis l'état d'auth. `null` si pas
/// authentifié — les écrans consommant ce provider doivent déjà être
/// protégés par le router (redirect vers /login sinon).
final Provider<String?> currentUserIdProvider = Provider<String?>((ref) {
  final AuthState state = ref.watch(authControllerProvider);
  return state is AuthAuthenticated ? state.user.id : null;
});

/// Liste des contacts de l'utilisateur courant. Se recharge automatiquement
/// quand `currentUserIdProvider` change (connexion/déconnexion).
final FutureProvider<List<ContactModel>> contactsListProvider =
    FutureProvider<List<ContactModel>>((ref) async {
  final String? ownerId = ref.watch(currentUserIdProvider);
  if (ownerId == null) return const [];
  return ref.read(contactsRepositoryProvider).fetchContacts(ownerId);
});

/// Controller pour les actions d'écriture (ajout/suppression), séparé de
/// la lecture pour garder `contactsListProvider` simple et cachable.
class ContactsController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> addContactByPhone({
    required String phoneNumber,
    String? alias,
  }) async {
    final String? ownerId = ref.read(currentUserIdProvider);
    if (ownerId == null) return false;

    state = const AsyncLoading();
    try {
      final repository = ref.read(contactsRepositoryProvider);
      final targetUser = await repository.findUserByPhone(phoneNumber);

      if (targetUser == null) {
        state = AsyncError(
          "Aucun utilisateur Kasoro n'est inscrit avec ce numéro.",
          StackTrace.current,
        );
        return false;
      }

      await repository.addContact(
        ownerId: ownerId,
        contactUserId: targetUser.id,
        alias: alias,
      );

      state = const AsyncData(null);
      ref.invalidate(contactsListProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  Future<void> deleteContact(String contactId) async {
    state = const AsyncLoading();
    try {
      await ref.read(contactsRepositoryProvider).deleteContact(contactId);
      state = const AsyncData(null);
      ref.invalidate(contactsListProvider);
    } catch (e, st) {
      state = AsyncError(e, st);
    }
  }
}

final NotifierProvider<ContactsController, AsyncValue<void>> contactsControllerProvider =
    NotifierProvider<ContactsController, AsyncValue<void>>(ContactsController.new);
