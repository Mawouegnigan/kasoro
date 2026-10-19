import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/messages_providers.dart';
import '../widgets/message_bubble.dart';
import '../widgets/message_input_bar.dart';

class ConversationScreen extends ConsumerWidget {
  const ConversationScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final messagesAsync = ref.watch(messagesListProvider(conversationId));

    return Scaffold(
      appBar: AppBar(title: const Text('Conversation')),
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
                        'Aucun message. Écris ou enregistre le premier.',
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
                  itemBuilder: (context, index) => MessageBubble(message: reversed[index]),
                );
              },
            ),
          ),
          const Divider(height: 1),
          MessageInputBar(conversationId: conversationId),
        ],
      ),
    );
  }
}
