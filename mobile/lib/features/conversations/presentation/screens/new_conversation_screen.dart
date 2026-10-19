import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../contacts/application/contacts_providers.dart';
import '../../../users/data/repositories/users_repository.dart';
import '../../application/conversations_providers.dart';

class NewConversationScreen extends ConsumerWidget {
  const NewConversationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsListProvider);
    final creationState = ref.watch(newConversationControllerProvider);

    ref.listen(newConversationControllerProvider, (previous, next) {
      next.whenOrNull(
        data: (conversation) {
          if (conversation != null) {
            context.pushReplacement('/conversations/${conversation.id}');
          }
        },
        error: (error, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : $error')),
        ),
      );
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Nouvelle conversation')),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Tu n'as pas encore de contact.",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.push('/contacts/add'),
                      child: const Text('Ajouter un contact'),
                    ),
                  ],
                ),
              ),
            );
          }

          final bool isCreating = creationState.isLoading;

          return Stack(
            children: [
              ListView.separated(
                itemCount: contacts.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final contact = contacts[index];
                  final userAsync = ref.watch(publicUserProvider(contact.contactUserId));

                  return userAsync.when(
                    loading: () => const ListTile(title: Text('...')),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (user) => ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                        ),
                      ),
                      title: Text(contact.alias?.isNotEmpty == true ? contact.alias! : user.displayName),
                      subtitle: Text(user.phoneNumber),
                      enabled: !isCreating,
                      onTap: isCreating
                          ? null
                          : () => ref
                              .read(newConversationControllerProvider.notifier)
                              .startDirectConversation(contact.contactUserId),
                    ),
                  );
                },
              ),
              if (isCreating)
                const Positioned.fill(
                  child: ColoredBox(
                    color: Colors.black12,
                    child: Center(child: CircularProgressIndicator()),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }
}
