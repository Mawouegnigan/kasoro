import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../models/conversation_model.dart';

class ConversationsRepository {
  ConversationsRepository(this._dio);

  final Dio _dio;

  Future<List<ConversationModel>> fetchUserConversations(String userId) async {
    try {
      final response = await _dio.get<List<dynamic>>('/conversations/user/$userId');
      return response.data!
          .map((json) => ConversationModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ConversationModel> fetchConversation(String conversationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/conversations/$conversationId');
      return ConversationModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ConversationModel> createConversation({
    required List<String> memberIds,
    String? name,
    bool isGroup = false,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/conversations',
        data: {
          if (name != null && name.isNotEmpty) 'name': name,
          'is_group': isGroup,
          'member_ids': memberIds,
        },
      );
      return ConversationModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> markRead(String conversationId) async {
    try {
      await _dio.post<void>('/conversations/$conversationId/read');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<List<ConversationMemberModel>> fetchMembers(String conversationId) async {
    try {
      final response = await _dio.get<List<dynamic>>('/conversations/$conversationId/members');
      return response.data!
          .map((json) => ConversationMemberModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> leaveConversation(String conversationId) async {
    try {
      await _dio.delete<void>('/conversations/$conversationId/members/me');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> addMember({
    required String conversationId,
    required String userId,
    required String language,
  }) async {
    try {
      await _dio.post<void>(
        '/conversations/$conversationId/members',
        data: {'user_id': userId, 'language': language},
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<ConversationsRepository> conversationsRepositoryProvider =
    Provider<ConversationsRepository>((ref) {
  return ConversationsRepository(ref.read(dioClientProvider));
});
