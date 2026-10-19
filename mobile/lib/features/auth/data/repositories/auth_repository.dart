import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../models/auth_response_model.dart';
import '../models/user_model.dart';

/// Accès réseau bruts pour l'authentification.
/// Ne connaît rien de Riverpod côté state — c'est le rôle du controller
/// dans `auth_providers.dart`.
class AuthRepository {
  AuthRepository(this._dio);

  final Dio _dio;

  Future<UserModel> register({
    required String phoneNumber,
    required String displayName,
    required String preferredLanguage,
    required String pin,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/users',
        data: {
          'phone_number': phoneNumber,
          'display_name': displayName,
          'preferred_language': preferredLanguage,
          'pin': pin,
        },
      );
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<AuthResponseModel> login({
    required String phoneNumber,
    required String pin,
  }) async {
    try {
      final Response<dynamic> response = await _dio.post<dynamic>(
        '/auth/login',
        data: {
          'phone_number': phoneNumber,
          'pin': pin,
        },
      );
      return AuthResponseModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<UserModel> fetchUser(String userId) async {
    try {
      final Response<dynamic> response = await _dio.get<dynamic>('/users/$userId');
      return UserModel.fromJson(response.data as Map<String, dynamic>);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<AuthRepository> authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepository(ref.read(dioClientProvider));
});
