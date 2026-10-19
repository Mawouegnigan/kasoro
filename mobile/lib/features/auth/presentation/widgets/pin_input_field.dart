import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Champ de saisie de PIN numérique (4-6 chiffres), gros et lisible.
/// Le public cible étant potentiellement peu alphabétisé, on privilégie
/// de gros chiffres plutôt qu'un clavier texte classique.
class PinInputField extends StatelessWidget {
  const PinInputField({
    super.key,
    required this.controller,
    this.label = 'Code PIN',
  });

  final TextEditingController controller;
  final String label;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      keyboardType: TextInputType.number,
      obscureText: true,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: const TextStyle(fontSize: 28, letterSpacing: 12),
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(
        labelText: label,
        counterText: '',
      ),
      validator: (value) {
        if (value == null || value.length < 4) {
          return 'Le PIN doit contenir 4 à 6 chiffres';
        }
        return null;
      },
    );
  }
}
