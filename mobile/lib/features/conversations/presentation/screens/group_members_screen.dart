import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/network/api_exception.dart';
import '../../../contacts/application/contacts_providers.dart';
import '../../../contacts/data/models/contact_model.dart';
import '../../../users/data/repositories/users_repository.dart';
import '../../application/conversation_members_provider.dart';
import '../../application/conversations_providers.dart';
import '../../data/repositories/conversations_repository.dart';

class GroupMembersScreen extends ConsumerWidget {
  const GroupMembersScreen({super.key, required this.conversationId});

  final String conversationId;

  String _message(Object e) => e is ApiException ? e.message : '$e';

  Future<void> _addMember(BuildContext context, WidgetRef ref, Set<String> currentIds) async {
    final (String, String)? picked = await showModalBottomSheet<(String, String)>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => Consumer(
        builder: (sheetContext, sheetRef, _) {
          final contacts = sheetRef.watch(contactsListProvider).valueOrNull ?? const [];
          final available =
              contacts.where((c) => !currentIds.contains(c.contactUserId)).toList();
          if (available.isEmpty) {
            return const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                "Tous vos contacts font déjà partie du groupe, ou vous n'avez pas encore de contact.",
                textAlign: TextAlign.center,
              ),
            );
          }
          return SafeArea(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: available.length,
              itemBuilder: (context, index) => _PickTile(contact: available[index]),
            ),
          );
        },
      ),
    );
    if (picked == null || !context.mounted) return;

    try {
      await ref.read(conversationsRepositoryProvider).addMember(
            conversationId: conversationId,
            userId: picked.$1,
            language: picked.$2,
          );
      ref.invalidate(conversationMembersProvider(conversationId));
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e))));
    }
  }

  Future<void> _leave(BuildContext context, WidgetRef ref) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Quitter le groupe ?'),
        content: const Text(
          'Vous ne recevrez plus les messages de ce groupe. '
          'Un autre membre pourra vous y ajouter de nouveau.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitter'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;

    try {
      await ref.read(conversationsRepositoryProvider).leaveConversation(conversationId);
      ref.invalidate(conversationsListProvider);
      if (!context.mounted) return;
      context.go('/');
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_message(e))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final membersAsync = ref.watch(conversationMembersProvider(conversationId));
    final String? me = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Membres du groupe')),
      body: membersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, _) => Center(child: Text('Erreur : $error')),
        data: (members) {
          final Set<String> ids = members.map((m) => m.userId).toSet();
          return ListView(
            children: [
              ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person_add)),
                title: const Text('Ajouter un membre'),
                onTap: () => _addMember(context, ref, ids),
              ),
              const Divider(height: 1),
              for (final member in members)
                _MemberTile(userId: member.userId, isMe: member.userId == me),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.logout, color: Theme.of(context).colorScheme.error),
                title: Text(
                  'Quitter le groupe',
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                onTap: () => _leave(context, ref),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MemberTile extends ConsumerWidget {
  const _MemberTile({required this.userId, required this.isMe});

  final String userId;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(publicUserProvider(userId));
    return userAsync.when(
      loading: () => const ListTile(title: Text('...')),
      error: (_, __) => const ListTile(title: Text('Membre')),
      data: (user) => ListTile(
        leading: CircleAvatar(
          child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?'),
        ),
        title: Text(isMe ? '${user.displayName} (vous)' : user.displayName),
      ),
    );
  }
}

class _PickTile extends ConsumerWidget {
  const _PickTile({required this.contact});

  final ContactModel contact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(publicUserProvider(contact.contactUserId));
    return userAsync.when(
      loading: () => const ListTile(title: Text('...')),
      error: (_, __) => const SizedBox.shrink(),
      data: (user) => ListTile(
        leading: CircleAvatar(
          child: Text(user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?'),
        ),
        title: Text(contact.alias?.isNotEmpty == true ? contact.alias! : user.displayName),
        onTap: () => Navigator.of(context).pop((contact.contactUserId, user.preferredLanguage)),
      ),
    );
  }
}