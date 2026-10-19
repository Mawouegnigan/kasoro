import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../auth/application/auth_providers.dart';
import '../../../contacts/application/contacts_providers.dart' show currentUserIdProvider;
import '../../../users/data/repositories/users_repository.dart';
import '../../application/conversation_members_provider.dart';
import '../../application/conversations_providers.dart';
import '../../data/models/conversation_model.dart';

class ConversationsListScreen extends ConsumerWidget {
  const ConversationsListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final conversationsAsync = ref.watch(conversationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kasoro'),
        actions: [
          IconButton(
            icon: const Icon(Icons.contacts_outlined),
            tooltip: 'Contacts',
            onPressed: () => context.push('/contacts'),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Se déconnecter',
            onPressed: () => ref.read(authControllerProvider.notifier).logout(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/conversations/new'),
        child: const Icon(Icons.add_comment_outlined),
      ),
      body: conversationsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (conversations) {
          if (conversations.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Aucune conversation. Démarre-en une depuis tes contacts.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: conversations.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _ConversationTile(conversation: conversations[index]),
          );
        },
      ),
    );
  }
}

/// Résout un titre lisible pour la conversation :
/// - si un `name` existe côté backend (toujours le cas pour un groupe,
///   optionnel pour du 1:1), on l'affiche tel quel ;
/// - sinon, pour une conversation 1:1, on va chercher le nom du
///   correspondant (le membre qui n'est pas l'utilisateur courant).
class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final ConversationModel conversation;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final leading = CircleAvatar(
      child: Icon(conversation.isGroup ? Icons.groups : Icons.person),
    );

    if (conversation.name != null && conversation.name!.isNotEmpty) {
      return ListTile(
        leading: leading,
        title: Text(conversation.name!),
        onTap: () => context.push('/conversations/${conversation.id}'),
      );
    }

    if (conversation.isGroup) {
      return ListTile(
        leading: leading,
        title: const Text('Groupe'),
        onTap: () => context.push('/conversations/${conversation.id}'),
      );
    }

    final String? currentUserId = ref.watch(currentUserIdProvider);
    final membersAsync = ref.watch(conversationMembersProvider(conversation.id));

    return membersAsync.when(
      loading: () => ListTile(leading: leading, title: const Text('...')),
      error: (_, __) => ListTile(leading: leading, title: const Text('Conversation')),
      data: (members) {
        final otherMemberId = members
            .map((m) => m.userId)
            .firstWhere((id) => id != currentUserId, orElse: () => '');

        if (otherMemberId.isEmpty) {
          return ListTile(
            leading: leading,
            title: const Text('Conversation'),
            onTap: () => context.push('/conversations/${conversation.id}'),
          );
        }

        final userAsync = ref.watch(publicUserProvider(otherMemberId));
        return userAsync.when(
          loading: () => ListTile(leading: leading, title: const Text('...')),
          error: (_, __) => ListTile(leading: leading, title: const Text('Conversation')),
          data: (user) => ListTile(
            leading: leading,
            title: Text(user.displayName),
            onTap: () => context.push('/conversations/${conversation.id}'),
          ),
        );
      },
    );
  }
}
