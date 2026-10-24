import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';

enum CorrectionType { transcription, translation }

class CorrectionsRepository {
  CorrectionsRepository(this._dio);

  final Dio _dio;

  /// Envoie une correction (ou une proposition) au backend.
  /// Elle est enregistrée avec le statut « à valider ».
  /// Pour une transcription, `language` est ignorée par le serveur
  /// (il prend la langue d'origine du message).
  Future<void> submitCorrection({
    required String messageId,
    required CorrectionType type,
    required String correctedValue,
    String? language,
  }) async {
    try {
      await _dio.post<Map<String, dynamic>>(
        '/corrections',
        data: {
          'message_id': messageId,
          'correction_type':
              type == CorrectionType.transcription ? 'transcription' : 'translation',
          if (language != null) 'language': language,
          'corrected_value': correctedValue,
        },
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<CorrectionsRepository> correctionsRepositoryProvider =
    Provider<CorrectionsRepository>((ref) {
  return CorrectionsRepository(ref.read(dioClientProvider));
});