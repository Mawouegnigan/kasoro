import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/supported_languages.dart';
import '../../../../core/network/api_exception.dart';
import '../../application/auth_providers.dart';
import '../../application/auth_state.dart';
import '../../data/repositories/auth_repository.dart';
import '../widgets/password_input_field.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _profileKey = GlobalKey<FormState>();
  final _passwordKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _oldController = TextEditingController();
  final _newController = TextEditingController();
  final _confirmController = TextEditingController();
  String _language = supportedLanguages.first.$1;
  bool _savingProfile = false;
  bool _savingPassword = false;

  @override
  void initState() {
    super.initState();
    final AuthState state = ref.read(authControllerProvider);
    if (state is AuthAuthenticated) {
      _nameController.text = state.user.displayName;
      final String code = state.user.preferredLanguage;
      if (supportedLanguages.any((l) => l.$1 == code)) _language = code;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _oldController.dispose();
    _newController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  void _say(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _saveProfile() async {
    final AuthState state = ref.read(authControllerProvider);
    if (state is! AuthAuthenticated) return;
    if (!_profileKey.currentState!.validate()) return;
    setState(() => _savingProfile = true);
    try {
      final user = await ref.read(authRepositoryProvider).updateProfile(
            userId: state.user.id,
            displayName: _nameController.text.trim(),
            preferredLanguage: _language,
          );
      ref.read(authControllerProvider.notifier).setUser(user);
      if (mounted) _say('Profil enregistré.');
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _savingProfile = false);
    }
  }

  Future<void> _changePassword() async {
    final AuthState state = ref.read(authControllerProvider);
    if (state is! AuthAuthenticated) return;
    if (!_passwordKey.currentState!.validate()) return;
    setState(() => _savingPassword = true);
    try {
      await ref.read(authRepositoryProvider).changePassword(
            userId: state.user.id,
            oldPassword: _oldController.text,
            newPassword: _newController.text,
          );
      _oldController.clear();
      _newController.clear();
      _confirmController.clear();
      if (mounted) _say('Mot de passe modifié.');
    } on ApiException catch (e) {
      if (mounted) _say(e.message);
    } finally {
      if (mounted) setState(() => _savingPassword = false);
    }
  }

  Future<void> _confirmLogout() async {
    final bool? yes = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Se déconnecter ?'),
        content: const Text('Voulez-vous vraiment vous déconnecter ?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Se déconnecter'),
          ),
        ],
      ),
    );
    if (yes == true) {
      await ref.read(authControllerProvider.notifier).logout();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AuthState state = ref.watch(authControllerProvider);
    if (state is! AuthAuthenticated) {
      return const Scaffold(body: SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Mon profil')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.phone_outlined),
                title: Text(state.user.phoneNumber),
                subtitle: const Text('Numéro de téléphone'),
              ),
              const SizedBox(height: 8),
              Form(
                key: _profileKey,
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
                    DropdownButtonFormField<String>(
                      initialValue: _language,
                      decoration: const InputDecoration(labelText: 'Langue préférée'),
                      items: supportedLanguages
                          .map((lang) => DropdownMenuItem(
                                value: lang.$1,
                                child: Text(lang.$2),
                              ))
                          .toList(),
                      onChanged: (value) {
                        if (value != null) setState(() => _language = value);
                      },
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _savingProfile ? null : _saveProfile,
                      child: _savingProfile
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enregistrer'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                'Changer le mot de passe',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 16),
              Form(
                key: _passwordKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    PasswordInputField(
                      controller: _oldController,
                      label: 'Ancien mot de passe',
                    ),
                    const SizedBox(height: 16),
                    PasswordInputField(
                      controller: _newController,
                      label: 'Nouveau mot de passe',
                      checkLength: true,
                    ),
                    const SizedBox(height: 16),
                    PasswordInputField(
                      controller: _confirmController,
                      label: 'Confirmez le nouveau mot de passe',
                      mustMatch: _newController,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _savingPassword ? null : _changePassword,
                      child: _savingPassword
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Modifier le mot de passe'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              OutlinedButton.icon(
                onPressed: _confirmLogout,
                icon: const Icon(Icons.logout),
                label: const Text('Se déconnecter'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
