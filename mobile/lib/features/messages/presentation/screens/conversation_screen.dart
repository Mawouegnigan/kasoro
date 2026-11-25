import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../contacts/application/contacts_providers.dart';
import '../../../conversations/application/conversation_members_provider.dart';
import '../../../conversations/application/conversations_providers.dart';
import '../../../users/data/models/public_user_model.dart';
import '../../../users/data/repositories/users_repository.dart';
import '../../../conversations/data/models/conversation_model.dart';
import '../../../conversations/data/repositories/conversations_repository.dart';
import '../../application/messages_providers.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';

class ConversationScreen extends ConsumerStatefulWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ConversationScreen> createState() => _ConversationScreenState();
}

class _ConversationScreenState extends ConsumerState<ConversationScreen> {
  Timer? _refreshTimer;

  void _showContactSheet(PublicUserModel user) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.displayName,
                style: Theme.of(sheetContext).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Text('Numéro : ${user.phoneNumber}'),
              const SizedBox(height: 8),
              Text('Langue préférée : ${user.preferredLanguage}'),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.copy),
                  label: const Text('Copier le numéro'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: user.phoneNumber));
                    if (!sheetContext.mounted) return;
                    Navigator.of(sheetContext).pop();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Numéro copié')),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _markRead({bool refreshList = false}) async {
    try {
      await ref.read(conversationsRepositoryProvider).markRead(widget.conversationId);
      if (refreshList && mounted) ref.invalidate(conversationsListProvider);
    } catch (_) {
      // Sans importance : le prochain passage du minuteur reessaiera.
    }
  }

  @override
  void initState() {
    super.initState();
    _markRead(refreshList: true);
    // Recharge la liste des messages toutes les 3 secondes tant que l'écran
    // est ouvert, pour voir arriver les nouveaux messages sans quitter l'écran.
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      ref.invalidate(messagesListProvider(widget.conversationId));
      _markRead();
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final messagesAsync = ref.watch(messagesListProvider(widget.conversationId));
    final String? me = ref.watch(currentUserIdProvider);
    final conversations = ref.watch(conversationsListProvider).valueOrNull;
    ConversationModel? thisConversation;
    if (conversations != null) {
      for (final c in conversations) {
        if (c.id == widget.conversationId) thisConversation = c;
      }
    }
    final bool isGroup = thisConversation?.isGroup ?? false;
    String title = isGroup ? (thisConversation?.name ?? 'Groupe') : 'Conversation';
    PublicUserModel? otherUser;
    final members = ref.watch(conversationMembersProvider(widget.conversationId)).valueOrNull;
    if (!isGroup && members != null && me != null && members.length == 2) {
      final String other = members.map((m) => m.userId).firstWhere((id) => id != me, orElse: () => '');
      if (other.isNotEmpty) {
        otherUser = ref.watch(publicUserProvider(other)).valueOrNull;
        title = otherUser?.displayName ?? 'Conversation';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: InkWell(
          onTap: isGroup
              ? () => context.push('/conversations/${widget.conversationId}/members')
              : (otherUser == null ? null : () => _showContactSheet(otherUser!)),
          child: Text(title),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erreur : $error')),
              data: (messages) {
                if (messages.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Aucun message. Écrivez ou enregistrez le premier.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                // Les messages arrivent du plus ancien au plus récent ;
                // on affiche en liste inversée (le plus récent en bas,
                // visible immédiatement à l'ouverture).
                final reversed = messages.reversed.toList();
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  itemCount: reversed.length,
                  itemBuilder: (context, index) => MessageBubble(
                    key: ValueKey(reversed[index].id),
                    message: reversed[index],
                  ),
                );
              },
            ),
          ),
          const Divider(height: 1),
          MessageInputBar(conversationId: widget.conversationId),
        ],
      ),
    );
  }
}