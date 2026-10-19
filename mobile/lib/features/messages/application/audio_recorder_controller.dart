import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

/// État de l'enregistrement en cours. Volontairement simple pour ce
/// premier jet : pas de pause/reprise, pas de ré-écoute avant envoi —
/// on enregistre, on arrête, on envoie. À enrichir plus tard si le
/// besoin s'en fait sentir.
sealed class RecordingState {
  const RecordingState();
}

class RecordingIdle extends RecordingState {
  const RecordingIdle();
}

class RecordingInProgress extends RecordingState {
  const RecordingInProgress();
}

/// Enregistrement terminé, fichier prêt à être envoyé.
class RecordingReady extends RecordingState {
  const RecordingReady(this.filePath);
  final String filePath;
}

class RecordingError extends RecordingState {
  const RecordingError(this.message);
  final String message;
}

class AudioRecorderController extends Notifier<RecordingState> {
  late final AudioRecorder _recorder;

  @override
  RecordingState build() {
    _recorder = AudioRecorder();
    ref.onDispose(() => _recorder.dispose());
    return const RecordingIdle();
  }

  Future<void> startRecording() async {
    try {
      final bool hasPermission = await _recorder.hasPermission();
      if (!hasPermission) {
        state = const RecordingError(
          "Permission microphone refusée. Autorise l'accès au micro dans "
          "les paramètres du téléphone.",
        );
        return;
      }

      final Directory dir = await getTemporaryDirectory();
      final String path =
          '${dir.path}/kasoro_${DateTime.now().millisecondsSinceEpoch}.m4a';

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );
      state = const RecordingInProgress();
    } catch (e) {
      state = RecordingError('Impossible de démarrer l\'enregistrement : $e');
    }
  }

  Future<void> stopRecording() async {
    try {
      final String? path = await _recorder.stop();
      if (path == null) {
        state = const RecordingError('Aucun fichier audio produit.');
        return;
      }
      state = RecordingReady(path);
    } catch (e) {
      state = RecordingError('Erreur en arrêtant l\'enregistrement : $e');
    }
  }

  Future<void> cancelRecording() async {
    try {
      if (await _recorder.isRecording()) {
        await _recorder.cancel();
      }
    } finally {
      state = const RecordingIdle();
    }
  }

  void reset() {
    state = const RecordingIdle();
  }
}

final NotifierProvider<AudioRecorderController, RecordingState> audioRecorderControllerProvider =
    NotifierProvider<AudioRecorderController, RecordingState>(AudioRecorderController.new);
