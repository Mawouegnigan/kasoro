import 'package:flutter/material.dart';

/// Champ de mot de passe avec bouton afficher/masquer.
/// checkLength : 8 caracteres minimum (inscription et changement seulement).
/// mustMatch : champ de confirmation, doit etre identique au premier.
class PasswordInputField extends StatefulWidget {
  const PasswordInputField({
    super.key,
    required this.controller,
    this.label = 'Mot de passe',
    this.checkLength = false,
    this.mustMatch,
  });

  final TextEditingController controller;
  final String label;
  final bool checkLength;
  final TextEditingController? mustMatch;

  @override
  State<PasswordInputField> createState() => _PasswordInputFieldState();
}

class _PasswordInputFieldState extends State<PasswordInputField> {
  bool _hidden = true;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: widget.controller,
      obscureText: _hidden,
      keyboardType: TextInputType.visiblePassword,
      autocorrect: false,
      enableSuggestions: false,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          icon: Icon(_hidden ? Icons.visibility : Icons.visibility_off),
          onPressed: () => setState(() => _hidden = !_hidden),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Saisissez votre mot de passe';
        }
        if (widget.checkLength && value.length < 8) {
          return 'Le mot de passe doit contenir au moins 8 caractères';
        }
        if (widget.checkLength && value.length > 72) {
          return 'Le mot de passe doit contenir au plus 72 caractères';
        }
        if (widget.mustMatch != null && value != widget.mustMatch!.text) {
          return 'Les deux mots de passe ne sont pas identiques';
        }
        return null;
      },
    );
  }
}
