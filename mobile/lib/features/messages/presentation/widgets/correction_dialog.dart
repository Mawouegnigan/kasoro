import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/supported_languages.dart';
import '../../../../core/network/api_exception.dart';
import '../../data/repositories/corrections_repository.dart';

String _languageLabel(String code) {
  return supportedLanguages
      .firstWhere((l) => l.$1 == code, orElse: () => (code, code))
      .$2;
}

/// Ouvre la boîte de dialogue permettant de corriger la transcription
/// (messages audio) ou de corriger / proposer la traduction.
Future<void> showCorrectionDialog(
  BuildContext context, {
  required String messageId,
  required String originLanguage,
  required String readingLanguage,
  required bool isAudio,
}) {
  return showDialog<void>(
    context: context,
    builder: (_) => _CorrectionDialog(
      messageId: messageId,
      originLanguage: originLanguage,
      readingLanguage: readingLanguage,
      isAudio: isAudio,
    ),
  );
}

class _CorrectionDialog extends ConsumerStatefulWidget {
  const _CorrectionDialog({
    required this.messageId,
    required this.originLanguage,
    required this.readingLanguage,
    required this.isAudio,
  });

  final String messageId;
  final String originLanguage;
  final String readingLanguage;
  final bool isAudio;

  @override
  ConsumerState<_CorrectionDialog> createState() => _CorrectionDialogState();
}

class _CorrectionDialogState extends ConsumerState<_CorrectionDialog> {
  final TextEditingController _controller = TextEditingController();
  CorrectionType _type = CorrectionType.translation;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Écris ta correction avant d\'envoyer.');
      return;
    }

    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() {
      _sending = true;
      _error = null;
    });

    try {
      await ref.read(correctionsRepositoryProvider).submitCorrection(
            messageId: widget.messageId,
            type: _type,
            correctedValue: text,
            language: _type == CorrectionType.translation ? widget.readingLanguage : null,
          );
      navigator.pop();
      messenger.showSnackBar(
        const SnackBar(content: Text('Merci ! Ta correction sera vérifiée par un autre locuteur.')),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = 'Envoi impossible : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isTranscription = _type == CorrectionType.transcription;
    final String targetLabel = isTranscription
        ? _languageLabel(widget.originLanguage)
        : _languageLabel(widget.readingLanguage);

    return AlertDialog(
      title: const Text('Corriger ce message'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (widget.isAudio) ...[
              SegmentedButton<CorrectionType>(
                segments: const [
                  ButtonSegment(value: CorrectionType.transcription, label: Text('Transcription')),
                  ButtonSegment(value: CorrectionType.translation, label: Text('Traduction')),
                ],
                selected: {_type},
                onSelectionChanged: _sending
                    ? null
                    : (selection) => setState(() => _type = selection.first),
              ),
              const SizedBox(height: 12),
            ],
            Text(
              isTranscription
                  ? 'Écris ce qui a vraiment été dit, en $targetLabel.'
                  : 'Écris la bonne traduction en $targetLabel.',
              style: const TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: !_sending,
              minLines: 2,
              maxLines: 5,
              maxLength: 5000,
              decoration: const InputDecoration(border: OutlineInputBorder()),
            ),
            const SizedBox(height: 4),
            Text(
              'En envoyant, tu acceptes que ta correction soit conservée et utilisée '
              'pour améliorer les traductions de Kasoro. Elle sera vérifiée par un '
              'autre locuteur avant d\'être retenue.',
              style: TextStyle(
                fontSize: 11,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(
                _error!,
                style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _sending ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        FilledButton(
          onPressed: _sending ? null : _submit,
          child: _sending
              ? const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Envoyer'),
        ),
      ],
    );
  }
}