import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  @override
  void initState() {
    super.initState();
    // Recharge la liste des messages toutes les 3 secondes tant que l'écran
    // est ouvert, pour voir arriver les nouveaux messages sans quitter l'écran.
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      ref.invalidate(messagesListProvider(widget.conversationId));
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