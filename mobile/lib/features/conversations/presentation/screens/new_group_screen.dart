import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../contacts/application/contacts_providers.dart';
import '../../../users/data/repositories/users_repository.dart';
import '../../application/conversations_providers.dart';

class NewGroupScreen extends ConsumerStatefulWidget {
  const NewGroupScreen({super.key});

  @override
  ConsumerState<NewGroupScreen> createState() => _NewGroupScreenState();
}

class _NewGroupScreenState extends ConsumerState<NewGroupScreen> {
  final TextEditingController _nameController = TextEditingController();
  final Set<String> _selected = <String>{};
  bool _creating = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canCreate =>
      !_creating && _nameController.text.trim().isNotEmpty && _selected.length >= 2;

  Future<void> _create() async {
    setState(() => _creating = true);
    final conversation =
        await ref.read(newConversationControllerProvider.notifier).startGroupConversation(
              memberUserIds: _selected.toList(),
              name: _nameController.text.trim(),
            );
    if (!mounted) return;
    if (conversation != null) {
      context.pushReplacement('/conversations/${conversation.id}');
      return;
    }
    setState(() => _creating = false);
    final Object? error = ref.read(newConversationControllerProvider).error;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text("Le groupe n'a pas pu être créé. $error")),
    );
  }

  @override
  Widget build(BuildContext context) {
    final contactsAsync = ref.watch(contactsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau groupe')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: TextField(
              controller: _nameController,
              maxLength: 60,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom du groupe',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Choisissez au moins deux contacts (${_selected.length} choisi(s))',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: contactsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(child: Text('Erreur : $error')),
              data: (contacts) {
                if (contacts.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        "Vous n'avez pas encore de contact. Ajoutez-en depuis « Mes contacts ».",
                        textAlign: TextAlign.center,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  itemCount: contacts.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final contact = contacts[index];
                    final userAsync = ref.watch(publicUserProvider(contact.contactUserId));
                    return userAsync.when(
                      loading: () => const ListTile(title: Text('...')),
                      error: (_, __) => const SizedBox.shrink(),
                      data: (user) => CheckboxListTile(
                        value: _selected.contains(contact.contactUserId),
                        onChanged: _creating
                            ? null
                            : (bool? checked) => setState(() {
                                  if (checked == true) {
                                    _selected.add(contact.contactUserId);
                                  } else {
                                    _selected.remove(contact.contactUserId);
                                  }
                                }),
                        secondary: CircleAvatar(
                          child: Text(
                            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                          ),
                        ),
                        title: Text(
                          contact.alias?.isNotEmpty == true ? contact.alias! : user.displayName,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            minimum: const EdgeInsets.all(16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _canCreate ? _create : null,
                child: _creating
                    ? const SizedBox(
                        height: 18,
                        width: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Créer le groupe'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}