import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contacts/application/contacts_providers.dart' show currentUserIdProvider;
import '../data/models/conversation_model.dart';
import '../data/repositories/conversations_repository.dart';

/// Liste des conversations de l'utilisateur courant.
final FutureProvider<List<ConversationModel>> conversationsListProvider =
    FutureProvider<List<ConversationModel>>((ref) async {
  final String? userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const [];
  final Timer refreshTimer = Timer(const Duration(seconds: 8), ref.invalidateSelf);
  ref.onDispose(refreshTimer.cancel);
  return ref.read(conversationsRepositoryProvider).fetchUserConversations(userId);
});

/// Controller pour la création d'une conversation 1:1 ou de groupe.
class NewConversationController extends Notifier<AsyncValue<ConversationModel?>> {
  @override
  AsyncValue<ConversationModel?> build() => const AsyncData(null);

  /// Démarre une conversation 1:1 avec un contact — en réutilisant une
  /// conversation existante si elle existe déjà, plutôt que d'en créer
  /// une nouvelle à chaque fois. Le backend ne fait pas cette dédup lui
  /// même (`POST /conversations` crée toujours une nouvelle ressource),
  /// donc c'est au client de vérifier avant d'appeler la création.
  /// `memberUserId` est l'id de l'autre utilisateur (voir
  /// `ContactModel.contactUserId`).
  Future<ConversationModel?> startDirectConversation(String memberUserId) async {
    final String? currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return null;

    state = const AsyncLoading();
    try {
      final repository = ref.read(conversationsRepositoryProvider);

      final existing = await _findExistingDirectConversation(
        repository: repository,
        currentUserId: currentUserId,
        otherUserId: memberUserId,
      );

      final ConversationModel conversation = existing ??
          await repository.createConversation(
            memberIds: [currentUserId, memberUserId],
            isGroup: false,
          );

      state = AsyncData(conversation);
      if (existing == null) {
        ref.invalidate(conversationsListProvider);
      }
      return conversation;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }

  /// Parcourt les conversations 1:1 déjà existantes de l'utilisateur et
  /// retourne celle qui a `otherUserId` comme second membre, s'il y en
  /// a une. `null` si aucune ne correspond.
  Future<ConversationModel?> _findExistingDirectConversation({
    required ConversationsRepository repository,
    required String currentUserId,
    required String otherUserId,
  }) async {
    final List<ConversationModel> conversations =
        await repository.fetchUserConversations(currentUserId);

    for (final conversation in conversations.where((c) => !c.isGroup)) {
      final members = await repository.fetchMembers(conversation.id);
      final memberIds = members.map((m) => m.userId).toSet();
      if (memberIds.contains(otherUserId)) {
        return conversation;
      }
    }
    return null;
  }

  Future<ConversationModel?> startGroupConversation({
    required List<String> memberUserIds,
    required String name,
  }) async {
    final String? currentUserId = ref.read(currentUserIdProvider);
    if (currentUserId == null) return null;

    state = const AsyncLoading();
    try {
      final conversation = await ref.read(conversationsRepositoryProvider).createConversation(
            memberIds: [currentUserId, ...memberUserIds],
            name: name,
            isGroup: true,
          );
      state = AsyncData(conversation);
      ref.invalidate(conversationsListProvider);
      return conversation;
    } catch (e, st) {
      state = AsyncError(e, st);
      return null;
    }
  }
}

final NotifierProvider<NewConversationController, AsyncValue<ConversationModel?>>
    newConversationControllerProvider =
    NotifierProvider<NewConversationController, AsyncValue<ConversationModel?>>(
  NewConversationController.new,
);
