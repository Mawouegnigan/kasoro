import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/api_config.dart';
import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../models/message_model.dart';

class MessagesRepository {
  MessagesRepository(this._dio);

  final Dio _dio;

  /// Étape 1 du flux audio : upload du fichier, retourne l'URL à
  /// fournir ensuite à `createAudioMessage`.
  Future<String> uploadAudio(String filePath) async {
    try {
      final fileName = filePath.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(filePath, filename: fileName),
      });
      final response = await _dio.post<Map<String, dynamic>>(
        '/upload/audio',
        data: formData,
      );
      return response.data!['audio_url'] as String;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MessageModel> createTextMessage({
    required String conversationId,
    required String senderId,
    required String originalLanguage,
    required String text,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/messages',
        data: {
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message_type': 'text',
          'original_language': originalLanguage,
          'original_text': text,
        },
      );
      return MessageModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<MessageModel> createAudioMessage({
    required String conversationId,
    required String senderId,
    required String originalLanguage,
    required String audioUrl,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/messages',
        data: {
          'conversation_id': conversationId,
          'sender_id': senderId,
          'message_type': 'audio',
          'original_language': originalLanguage,
          'original_audio_url': audioUrl,
        },
        options: Options(receiveTimeout: ApiConfig.translationReceiveTimeout),
      );
      return MessageModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<MessageModel>> fetchMessages(
    String conversationId, {
    int skip = 0,
    int limit = 200,
  }) async {
    try {
      final response = await _dio.get<List<dynamic>>(
        '/messages/conversation/$conversationId',
        queryParameters: {'skip': skip, 'limit': limit},
      );
      return response.data!
          .map((json) => MessageModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// La route clé du produit. Peut être lente (jusqu'à quelques minutes)
  /// la toute première fois qu'une langue est demandée pour ce message
  /// — d'où le timeout dédié, plus long que le reste de l'API.
  Future<MessageInLanguageModel> fetchMessageInLanguage({
    required String messageId,
    required String language,
  }) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/messages/$messageId/in/$language',
        options: Options(receiveTimeout: ApiConfig.translationReceiveTimeout),
      );
      return MessageInLanguageModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<MessagesRepository> messagesRepositoryProvider =
    Provider<MessagesRepository>((ref) {
  return MessagesRepository(ref.read(dioClientProvider));
});
