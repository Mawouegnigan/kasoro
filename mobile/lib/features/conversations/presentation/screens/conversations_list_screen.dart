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
                  'Aucune conversation. Démarrez-en une depuis vos contacts.',
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

/// Heure du dernier message : HH:mm si c'est aujourd'hui, sinon jj/mm.
String _formatTime(DateTime date) {
  final DateTime local = date.toLocal();
  final DateTime now = DateTime.now();
  String two(int n) => n.toString().padLeft(2, '0');
  if (local.year == now.year && local.month == now.month && local.day == now.day) {
    return '${two(local.hour)}:${two(local.minute)}';
  }
  return '${two(local.day)}/${two(local.month)}';
}

/// Résout un titre lisible pour la conversation :
/// - si un `name` existe côté backend (toujours le cas pour un groupe,
///   optionnel pour du 1:1), on l'affiche tel quel ;
/// - sinon, pour une conversation 1:1, on va chercher le nom du
///   correspondant (le membre qui n'est pas l'utilisateur courant).
class _ConversationTile extends ConsumerWidget {
  const _ConversationTile({required this.conversation});

  final ConversationModel conversation;

  String? _preview(String? currentUserId) {
    final String? type = conversation.lastMessageType;
    if (type == null) return null;
    final String text = (conversation.lastMessageText ?? '').trim();
    final bool isAudio = type.toLowerCase().contains('audio');
    final String body = (isAudio || text.isEmpty) ? 'Message vocal' : text;
    final bool mine = conversation.lastMessageSenderId != null &&
        conversation.lastMessageSenderId == currentUserId;
    return mine ? 'Vous : $body' : body;
  }

  Widget _tile(BuildContext context, Widget leading, Widget title, String? currentUserId) {
    final String? preview = _preview(currentUserId);
    final DateTime? at = conversation.lastMessageAt;
    return ListTile(
      leading: leading,
      title: title,
      subtitle: preview == null
          ? null
          : Text(preview, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: at == null
          ? null
          : Text(_formatTime(at), style: Theme.of(context).textTheme.bodySmall),
      onTap: () => context.push('/conversations/${conversation.id}'),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? currentUserId = ref.watch(currentUserIdProvider);
    final leading = CircleAvatar(
      child: Icon(conversation.isGroup ? Icons.groups : Icons.person),
    );

    if (conversation.name != null && conversation.name!.isNotEmpty) {
      return _tile(context, leading, Text(conversation.name!), currentUserId);
    }

    if (conversation.isGroup) {
      return _tile(context, leading, const Text('Groupe'), currentUserId);
    }

    final membersAsync = ref.watch(conversationMembersProvider(conversation.id));

    return membersAsync.when(
      loading: () => ListTile(leading: leading, title: const Text('...')),
      error: (_, __) => ListTile(leading: leading, title: const Text('Conversation')),
      data: (members) {
        final otherMemberId = members
            .map((m) => m.userId)
            .firstWhere((id) => id != currentUserId, orElse: () => '');

        if (otherMemberId.isEmpty) {
          return _tile(context, leading, const Text('Conversation'), currentUserId);
        }

        final userAsync = ref.watch(publicUserProvider(otherMemberId));
        return userAsync.when(
          loading: () => ListTile(leading: leading, title: const Text('...')),
          error: (_, __) => ListTile(leading: leading, title: const Text('Conversation')),
          data: (user) => _tile(context, leading, Text(user.displayName), currentUserId),
        );
      },
    );
  }
}