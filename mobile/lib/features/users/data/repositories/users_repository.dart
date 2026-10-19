import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../models/public_user_model.dart';

class UsersRepository {
  UsersRepository(this._dio);

  final Dio _dio;

  Future<PublicUserModel> fetchUser(String userId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>('/users/$userId');
      return PublicUserModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<UsersRepository> usersRepositoryProvider = Provider<UsersRepository>((ref) {
  return UsersRepository(ref.read(dioClientProvider));
});

/// Cache simple des profils déjà résolus dans la session, pour éviter de
/// re-fetcher le même utilisateur à chaque écran (liste de contacts,
/// membres de conversation, expéditeur de message...).
final FutureProviderFamily<PublicUserModel, String> publicUserProvider =
    FutureProvider.family<PublicUserModel, String>((ref, userId) {
  return ref.read(usersRepositoryProvider).fetchUser(userId);
});
