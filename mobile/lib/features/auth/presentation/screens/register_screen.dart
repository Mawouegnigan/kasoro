import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/supported_languages.dart';
import '../../application/auth_providers.dart';
import '../../application/auth_state.dart';
import '../widgets/pin_input_field.dart';

class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _phoneController = TextEditingController();
  final _nameController = TextEditingController();
  final _pinController = TextEditingController();
  String _selectedLanguage = supportedLanguages.first.$1;

  @override
  void dispose() {
    _phoneController.dispose();
    _nameController.dispose();
    _pinController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    ref.read(authControllerProvider.notifier).register(
          phoneNumber: _phoneController.text.trim(),
          displayName: _nameController.text.trim(),
          preferredLanguage: _selectedLanguage,
          pin: _pinController.text.trim(),
        );
  }

  @override
  Widget build(BuildContext context) {
    final AuthState state = ref.watch(authControllerProvider);
    final bool isLoading = state is AuthLoading;

    ref.listen<AuthState>(authControllerProvider, (previous, next) {
      if (next is AuthError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Créer un compte')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Nom affiché'),
                  validator: (value) =>
                      (value == null || value.trim().isEmpty) ? 'Requis' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Numéro de téléphone',
                    hintText: '+229...',
                  ),
                  validator: (value) => (value == null || value.trim().length < 8)
                      ? 'Numéro invalide'
                      : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  initialValue: _selectedLanguage,
                  decoration: const InputDecoration(labelText: 'Langue préférée'),
                  items: supportedLanguages
                      .map((lang) => DropdownMenuItem(
                            value: lang.$1,
                            child: Text(lang.$2),
                          ))
                      .toList(),
                  onChanged: (value) {
                    if (value != null) setState(() => _selectedLanguage = value);
                  },
                ),
                const SizedBox(height: 16),
                PinInputField(controller: _pinController, label: 'Choisis un PIN'),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: isLoading ? null : _submit,
                  child: isLoading
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text("S'inscrire"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
