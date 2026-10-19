import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/supported_languages.dart';
import '../../application/audio_recorder_controller.dart';
import '../../application/message_language_provider.dart';
import '../../application/messages_providers.dart';

class MessageInputBar extends ConsumerStatefulWidget {
  const MessageInputBar({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<MessageInputBar> createState() => _MessageInputBarState();
}

class _MessageInputBarState extends ConsumerState<MessageInputBar> {
  final _textController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Pour que le bouton d'envoi s'active/désactive en direct pendant
    // la saisie (TextEditingController ne déclenche pas de rebuild seul).
    _textController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _sendText() async {
    final String text = _textController.text;
    if (text.trim().isEmpty) return;
    _textController.clear();
    await ref
        .read(sendMessageControllerProvider.notifier)
        .sendText(conversationId: widget.conversationId, text: text);
  }

  Future<void> _toggleRecording(RecordingState recordingState) async {
    final recorderNotifier = ref.read(audioRecorderControllerProvider.notifier);

    if (recordingState is RecordingIdle) {
      await recorderNotifier.startRecording();
    } else if (recordingState is RecordingInProgress) {
      await recorderNotifier.stopRecording();
      // Envoi automatique dès que l'enregistrement s'arrête — pas de
      // pré-écoute avant envoi dans cette première version.
      await ref
          .read(sendMessageControllerProvider.notifier)
          .sendRecordedAudio(conversationId: widget.conversationId);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recordingState = ref.watch(audioRecorderControllerProvider);
    final sendState = ref.watch(sendMessageControllerProvider);
    final bool isSending = sendState.isLoading;
    final bool isRecording = recordingState is RecordingInProgress;

    ref.listen(audioRecorderControllerProvider, (previous, next) {
      if (next is RecordingError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.message)),
        );
      }
    });

    ref.listen(sendMessageControllerProvider, (previous, next) {
      if (next.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur : ${next.error}')),
        );
      }
    });

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _LanguageSelectorChip(conversationId: widget.conversationId),
            const SizedBox(height: 4),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _textController,
                    enabled: !isRecording && !isSending,
                    minLines: 1,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Message...',
                      border:
                          OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(24))),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    ),
                    onSubmitted: (_) => _sendText(),
                  ),
                ),
                const SizedBox(width: 8),
                if (isSending)
                  const Padding(
                    padding: EdgeInsets.all(12),
                    child: SizedBox(
                      height: 24,
                      width: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else ...[
                  IconButton.filledTonal(
                    onPressed: () => _toggleRecording(recordingState),
                    icon: Icon(isRecording ? Icons.stop : Icons.mic),
                    style: isRecording
                        ? IconButton.styleFrom(
                            backgroundColor: Theme.of(context).colorScheme.errorContainer,
                          )
                        : null,
                  ),
                  if (!isRecording)
                    IconButton.filled(
                      onPressed: _textController.text.trim().isEmpty ? null : _sendText,
                      icon: const Icon(Icons.send),
                    ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Petit sélecteur discret : langue utilisée pour le PROCHAIN message
/// (texte ou audio) envoyé dans cette conversation. Par défaut la
/// langue du profil, modifiable à la volée sans passer par les
/// paramètres — utile pour quelqu'un de bilingue.
class _LanguageSelectorChip extends ConsumerWidget {
  const _LanguageSelectorChip({required this.conversationId});

  final String conversationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String selected = ref.watch(messageLanguageControllerProvider(conversationId));
    final String label =
        supportedLanguages.firstWhere((l) => l.$1 == selected, orElse: () => (selected, selected)).$2;

    return Align(
      alignment: Alignment.centerLeft,
      child: ActionChip(
        avatar: const Icon(Icons.translate, size: 16),
        label: Text(label, style: const TextStyle(fontSize: 12)),
        visualDensity: VisualDensity.compact,
        onPressed: () => _showLanguagePicker(context, ref),
      ),
    );
  }

  Future<void> _showLanguagePicker(BuildContext context, WidgetRef ref) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Langue de ce message',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              for (final lang in supportedLanguages)
                ListTile(
                  title: Text(lang.$2),
                  onTap: () => Navigator.of(context).pop(lang.$1),
                ),
            ],
          ),
        );
      },
    );

    if (picked != null) {
      ref.read(messageLanguageControllerProvider(conversationId).notifier).select(picked);
    }
  }
}
