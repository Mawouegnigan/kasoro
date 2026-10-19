import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contacts/application/contacts_providers.dart' show currentUserIdProvider;
import '../data/models/message_model.dart';
import '../data/repositories/messages_repository.dart';
import 'audio_recorder_controller.dart';
import 'message_language_provider.dart';

final FutureProviderFamily<List<MessageModel>, String> messagesListProvider =
    FutureProvider.family<List<MessageModel>, String>((ref, conversationId) {
  return ref.read(messagesRepositoryProvider).fetchMessages(conversationId);
});

/// Traduction + audio d'un message dans une langue donnée, mise en cache
/// côté client pour la durée de la session (évite de re-solliciter le
/// pipeline de traduction à chaque rebuild de widget).
typedef MessageLanguageKey = ({String messageId, String language});

final FutureProviderFamily<MessageInLanguageModel, MessageLanguageKey> messageInLanguageProvider =
    FutureProvider.family<MessageInLanguageModel, MessageLanguageKey>((ref, key) {
  return ref.read(messagesRepositoryProvider).fetchMessageInLanguage(
        messageId: key.messageId,
        language: key.language,
      );
});

class SendMessageController extends Notifier<AsyncValue<void>> {
  @override
  AsyncValue<void> build() => const AsyncData(null);

  Future<bool> sendText({
    required String conversationId,
    required String text,
  }) async {
    final String? senderId = ref.read(currentUserIdProvider);
    final String language = ref.read(messageLanguageControllerProvider(conversationId));

    if (senderId == null || text.trim().isEmpty) return false;

    state = const AsyncLoading();
    try {
      await ref.read(messagesRepositoryProvider).createTextMessage(
            conversationId: conversationId,
            senderId: senderId,
            originalLanguage: language,
            text: text.trim(),
          );
      state = const AsyncData(null);
      ref.invalidate(messagesListProvider(conversationId));
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }

  /// Envoie l'enregistrement actuellement prêt dans
  /// `audioRecorderControllerProvider` (état `RecordingReady`).
  Future<bool> sendRecordedAudio({required String conversationId}) async {
    final recordingState = ref.read(audioRecorderControllerProvider);
    if (recordingState is! RecordingReady) return false;

    final String? senderId = ref.read(currentUserIdProvider);
    final String language = ref.read(messageLanguageControllerProvider(conversationId));
    if (senderId == null) return false;

    state = const AsyncLoading();
    try {
      final repository = ref.read(messagesRepositoryProvider);
      final String audioUrl = await repository.uploadAudio(recordingState.filePath);
      await repository.createAudioMessage(
        conversationId: conversationId,
        senderId: senderId,
        originalLanguage: language,
        audioUrl: audioUrl,
      );
      state = const AsyncData(null);
      ref.read(audioRecorderControllerProvider.notifier).reset();
      ref.invalidate(messagesListProvider(conversationId));
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      return false;
    }
  }
}

final NotifierProvider<SendMessageController, AsyncValue<void>> sendMessageControllerProvider =
    NotifierProvider<SendMessageController, AsyncValue<void>>(SendMessageController.new);
