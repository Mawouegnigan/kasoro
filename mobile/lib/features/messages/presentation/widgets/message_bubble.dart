import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import '../../../../core/constants/supported_languages.dart';
import '../../../../core/network/api_exception.dart';
import 'correction_dialog.dart';
import '../../../../core/utils/audio_url_resolver.dart';
import '../../../contacts/application/contacts_providers.dart' show currentUserIdProvider;
import '../../application/messages_providers.dart';
import '../../application/reading_language_provider.dart';
import '../../data/models/message_model.dart';

class MessageBubble extends ConsumerStatefulWidget {
  const MessageBubble({super.key, required this.message});

  final MessageModel message;

  @override
  ConsumerState<MessageBubble> createState() => _MessageBubbleState();
}

class _MessageBubbleState extends ConsumerState<MessageBubble> {
  AudioPlayer? _player;
  bool _isPlaying = false;
  bool _isBuffering = false;
  String? _playbackError;
  String? _loadedAudioUrl;

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  Future<void> _togglePlay(String audioUrl) async {
    setState(() => _playbackError = null);

    if (_player == null) {
      _player = AudioPlayer();
      _player!.playerStateStream.listen((playerState) {
        if (!mounted) return;
        setState(() {
          _isPlaying = playerState.playing;
          _isBuffering = playerState.processingState == ProcessingState.buffering ||
              playerState.processingState == ProcessingState.loading;
        });
        if (playerState.processingState == ProcessingState.completed) {
          _player!.seek(Duration.zero);
          _player!.pause();
        }
      });
    }

    if (_isPlaying) {
      await _player!.pause();
      return;
    }

    try {
      if (_player!.audioSource == null || _loadedAudioUrl != audioUrl) {
        setState(() => _isBuffering = true);
        final Uri uri = Uri.parse(resolveAudioUrl(audioUrl));
        await _player!.setAudioSource(AudioSource.uri(uri));
      }
      await _player!.play();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isBuffering = false;
        _playbackError = 'Lecture impossible : $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final String? currentUserId = ref.watch(currentUserIdProvider);
    final bool isMine = widget.message.senderId == currentUserId;

    final Widget content;

    if (isMine) {
      // On affiche son propre message tel qu'envoyé, sans repasser par
      // le pipeline de traduction (qui traduit vers les AUTRES langues,
      // pas besoin de se traduire soi-même vers sa propre langue).
      content = widget.message.type == MessageType.text
          ? Text(widget.message.originalText ?? '')
          : _OwnAudioMessage(audioUrl: widget.message.originalAudioUrl);
    } else {
      final String? readingLanguage =
          ref.watch(readingLanguageControllerProvider(widget.message.id));

      if (readingLanguage == null) {
        // Rien n'est téléchargé tant que le destinataire n'a pas choisi
        // explicitement une langue — comme le bouton de téléchargement
        // d'un vocal WhatsApp.
        content = _ChooseLanguagePrompt(
          messageId: widget.message.id,
          originLanguage: widget.message.originalLanguage,
        );
      } else {
        final translationAsync = ref.watch(
          messageInLanguageProvider((messageId: widget.message.id, language: readingLanguage)),
        );

        content = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _ReadingLanguageChip(
              messageId: widget.message.id,
              originLanguage: widget.message.originalLanguage,
            ),
            const SizedBox(height: 4),
            translationAsync.when(
              loading: () => const _TranslationLoadingIndicator(),
              error: (error, _) => (error is ApiException && error.isTranslationUnavailable)
                  ? Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _TranslationUnavailableNotice(language: readingLanguage),
                        _CorrectionLink(
                          messageId: widget.message.id,
                          originLanguage: widget.message.originalLanguage,
                          readingLanguage: readingLanguage,
                          isAudio: widget.message.type == MessageType.audio,
                        ),
                      ],
                    )
                  : Text('Erreur de traduction : $error'),
              data: (translation) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(translation.text),
                  if (translation.audioUrl != null) ...[
                    const SizedBox(height: 4),
                    InkWell(
                      onTap: () => _togglePlay(translation.audioUrl!),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_isBuffering)
                            const SizedBox(
                              height: 16,
                              width: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          else
                            Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, size: 20),
                          const SizedBox(width: 4),
                          const Text('Écouter', style: TextStyle(fontSize: 12)),
                        ],
                      ),
                    ),
                    if (_playbackError != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _playbackError!,
                        style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ],
        );
      }
    }

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Column(
        crossAxisAlignment: isMine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              isMine ? 'Vous' : 'Reçu',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.bold,
                color: isMine
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.secondary,
              ),
            ),
          ),
          Container(
            margin: const EdgeInsets.symmetric(vertical: 2, horizontal: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
            decoration: BoxDecoration(
              // Couleurs volontairement très distinctes (pas deux nuances
              // proches de gris) pour qu'on ne confonde jamais "envoyé"
              // et "reçu" au premier coup d'œil.
              color: isMine
                  ? Theme.of(context).colorScheme.primary.withOpacity(0.15)
                  : Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.only(
                topLeft: const Radius.circular(16),
                topRight: const Radius.circular(16),
                bottomLeft: Radius.circular(isMine ? 16 : 4),
                bottomRight: Radius.circular(isMine ? 4 : 16),
              ),
            ),
            child: content,
          ),
        ],
      ),
    );
  }
}

/// Message audio qu'on a soi-même envoyé : on le joue tel quel, sans
/// passer par la traduction (qui n'a de sens que pour les destinataires).
class _OwnAudioMessage extends StatefulWidget {
  const _OwnAudioMessage({required this.audioUrl});
  final String? audioUrl;

  @override
  State<_OwnAudioMessage> createState() => _OwnAudioMessageState();
}

class _OwnAudioMessageState extends State<_OwnAudioMessage> {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _player.playerStateStream.listen((s) {
      if (!mounted) return;
      setState(() => _isPlaying = s.playing);
    });
  }

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  Future<void> _toggle() async {
    setState(() => _error = null);
    try {
      if (_isPlaying) {
        await _player.pause();
      } else {
        if (_player.audioSource == null) {
          await _player.setUrl(resolveAudioUrl(widget.audioUrl!));
        }
        await _player.play();
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = 'Lecture impossible : $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.audioUrl == null) return const Text('Message vocal');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: _toggle,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_isPlaying ? Icons.pause_circle : Icons.play_circle, size: 20),
              const SizedBox(width: 6),
              const Text('Message vocal'),
            ],
          ),
        ),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.error),
          ),
      ],
    );
  }
}

/// Affiché tant que le destinataire n'a pas choisi de langue pour ce
/// message — rien n'est téléchargé avant ce choix explicite, comme le
/// bouton de téléchargement d'un vocal WhatsApp.
class _ChooseLanguagePrompt extends ConsumerWidget {
  const _ChooseLanguagePrompt({required this.messageId, required this.originLanguage});

  final String messageId;
  final String originLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String originLabel = supportedLanguages
        .firstWhere((l) => l.$1 == originLanguage, orElse: () => (originLanguage, originLanguage))
        .$2;

    return InkWell(
      onTap: () => _pickLanguage(context, ref),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.download_rounded, size: 18, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              'Envoyé en $originLabel — choisir une langue',
              style: const TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Lire/écouter ce message en', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ref.read(readingLanguageControllerProvider(messageId).notifier).select(picked);
    }
  }
}

/// Affiché une fois qu'une langue a été choisie : montre la langue
/// active et permet d'en changer (relance une nouvelle traduction).
class _ReadingLanguageChip extends ConsumerWidget {
  const _ReadingLanguageChip({required this.messageId, required this.originLanguage});

  final String messageId;
  final String originLanguage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String? selected = ref.watch(readingLanguageControllerProvider(messageId));
    final String selectedLabel = supportedLanguages
        .firstWhere((l) => l.$1 == selected, orElse: () => (selected ?? '', selected ?? ''))
        .$2;
    final String originLabel = supportedLanguages
        .firstWhere((l) => l.$1 == originLanguage, orElse: () => (originLanguage, originLanguage))
        .$2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Envoyé en $originLabel',
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(width: 6),
        ActionChip(
          avatar: const Icon(Icons.translate, size: 14),
          label: Text(selectedLabel, style: const TextStyle(fontSize: 11)),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          onPressed: () => _pickLanguage(context, ref),
        ),
      ],
    );
  }

  Future<void> _pickLanguage(BuildContext context, WidgetRef ref) async {
    final String? picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.all(16),
                child: Text('Lire/écouter ce message en', style: TextStyle(fontWeight: FontWeight.bold)),
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
      ref.read(readingLanguageControllerProvider(messageId).notifier).select(picked);
    }
  }
}

/// Petit lien « Corriger » sous une traduction (ou sous « traduction
/// indisponible ») : ouvre la boîte de dialogue de correction.
class _CorrectionLink extends StatelessWidget {
  const _CorrectionLink({
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
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => showCorrectionDialog(
        context,
        messageId: messageId,
        originLanguage: originLanguage,
        readingLanguage: readingLanguage,
        isAudio: isAudio,
      ),
      child: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.edit_outlined, size: 14, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 4),
            const Text('Corriger', style: TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

/// Affiché quand le backend répond 422 « translation_unavailable » :
/// la traduction vers cette langue n'est pas fiable (ex. adja).
class _TranslationUnavailableNotice extends StatelessWidget {
  const _TranslationUnavailableNotice({required this.language});

  final String language;

  @override
  Widget build(BuildContext context) {
    final String label = supportedLanguages
        .firstWhere((l) => l.$1 == language, orElse: () => (language, language))
        .$2;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.info_outline, size: 16, color: Theme.of(context).colorScheme.onSurfaceVariant),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            'Traduction indisponible en $label pour ce message.',
            style: const TextStyle(fontSize: 12),
          ),
        ),
      ],
    );
  }
}

/// Indicateur de chargement pendant une traduction. Le pipeline actuel
/// traite chaque traduction de façon synchrone (pas de file d'attente
/// asynchrone côté backend) — la première lecture d'un message dans
/// une langue jamais utilisée, ou un audio long, peut prendre de
/// quelques secondes à plusieurs minutes.
class _TranslationLoadingIndicator extends StatefulWidget {
  const _TranslationLoadingIndicator();

  @override
  State<_TranslationLoadingIndicator> createState() => _TranslationLoadingIndicatorState();
}

class _TranslationLoadingIndicatorState extends State<_TranslationLoadingIndicator> {
  int _elapsedSeconds = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsedSeconds++);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final String label = _elapsedSeconds < 8
        ? 'Traduction en cours...'
        : 'Traduction en cours... (${_elapsedSeconds}s — un audio long ou '
            'une nouvelle langue peuvent prendre jusqu\'à quelques minutes)';

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          height: 14,
          width: 14,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const SizedBox(width: 8),
        Flexible(child: Text(label, style: const TextStyle(fontSize: 12))),
      ],
    );
  }
}