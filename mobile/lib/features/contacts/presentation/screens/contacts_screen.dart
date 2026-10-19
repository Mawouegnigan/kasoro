import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../users/data/repositories/users_repository.dart';
import '../../application/contacts_providers.dart' show contactsListProvider, contactsControllerProvider;
import '../../data/models/contact_model.dart';

class ContactsScreen extends ConsumerWidget {
  const ContactsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contactsAsync = ref.watch(contactsListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Mes contacts')),
      floatingActionButton: FloatingActionButton(
        onPressed: () => context.push('/contacts/add'),
        child: const Icon(Icons.person_add),
      ),
      body: contactsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (contacts) {
          if (contacts.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  "Aucun contact pour l'instant. Ajoute quelqu'un avec le bouton +.",
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: contacts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) => _ContactTile(contact: contacts[index]),
          );
        },
      ),
    );
  }
}

class _ContactTile extends ConsumerWidget {
  const _ContactTile({required this.contact});

  final ContactModel contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(publicUserProvider(contact.contactUserId));

    return userAsync.when(
      loading: () => const ListTile(title: Text('...')),
      error: (_, __) => ListTile(
        leading: const CircleAvatar(child: Icon(Icons.person_off)),
        title: Text(contact.alias ?? 'Contact introuvable'),
      ),
      data: (user) => ListTile(
        leading: CircleAvatar(
          child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?'),
        ),
        title: Text(contact.alias?.isNotEmpty == true ? contact.alias! : user.displayName),
        subtitle: Text('${user.phoneNumber} · ${user.preferredLanguage}'),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline),
          onPressed: () =>
              ref.read(contactsControllerProvider.notifier).deleteContact(contact.id),
        ),
      ),
    );
  }
}
