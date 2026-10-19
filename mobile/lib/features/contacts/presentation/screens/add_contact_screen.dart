import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../application/contacts_providers.dart';

class AddContactScreen extends ConsumerStatefulWidget {
  const AddContactScreen({super.key});

  @override
  ConsumerState<AddContactScreen> createState() => _AddContactScreenState();
}

class _AddContactScreenState extends ConsumerState<AddContactScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _aliasController = TextEditingController();

  @override
  void dispose() {
    _phoneController.dispose();
    _aliasController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final bool success = await ref.read(contactsControllerProvider.notifier).addContactByPhone(
          phoneNumber: _phoneController.text.trim(),
          alias: _aliasController.text.trim(),
        );

    if (!mounted) return;
    if (success) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controllerState = ref.watch(contactsControllerProvider);
    final bool isLoading = controllerState.isLoading;

    ref.listen(contactsControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.error.toString())),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Ajouter un contact')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                "Entre le numéro de téléphone de la personne. "
                "Elle doit déjà avoir un compte Kasoro.",
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Numéro de téléphone',
                  hintText: '+229...',
                ),
                validator: (value) =>
                    (value == null || value.trim().length < 8) ? 'Numéro invalide' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _aliasController,
                decoration: const InputDecoration(
                  labelText: 'Surnom (optionnel)',
                ),
              ),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: isLoading ? null : _submit,
                child: isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Ajouter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
