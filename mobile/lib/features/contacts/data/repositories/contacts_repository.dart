import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/network/api_exception.dart';
import '../../../../core/network/dio_client.dart';
import '../../../users/data/models/public_user_model.dart';
import '../models/contact_model.dart';

class ContactsRepository {
  ContactsRepository(this._dio);

  final Dio _dio;

  Future<List<ContactModel>> fetchContacts(String ownerId) async {
    try {
      final response = await _dio.get<List<dynamic>>('/contacts/owner/$ownerId');
      return response.data!
          .map((json) => ContactModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<ContactModel> addContact({
    required String ownerId,
    required String contactUserId,
    String? alias,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/contacts',
        data: {
          'owner_id': ownerId,
          'contact_user_id': contactUserId,
          if (alias != null && alias.isNotEmpty) 'alias': alias,
        },
      );
      return ContactModel.fromJson(response.data!);
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<void> deleteContact(String contactId) async {
    try {
      await _dio.delete<void>('/contacts/$contactId');
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  /// Le backend n'expose pas (encore) de recherche par numéro de
  /// téléphone. En attendant une route dédiée type
  /// `GET /users/search?phone=...`, on récupère la liste complète des
  /// utilisateurs et on filtre côté client. Acceptable pour le volume
  /// d'utilisateurs actuel (MVP/solo), à revoir avant une mise à l'échelle
  /// — c'est une recherche O(n) qui ne doit pas rester telle quelle en
  /// production avec des milliers d'utilisateurs.
  Future<PublicUserModel?> findUserByPhone(String phoneNumber) async {
    try {
      final response = await _dio.get<List<dynamic>>('/users');
      final users = response.data!
          .map((json) => PublicUserModel.fromJson(json as Map<String, dynamic>))
          .toList();
      final String normalized = phoneNumber.trim();
      for (final user in users) {
        if (user.phoneNumber == normalized) return user;
      }
      return null;
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

final Provider<ContactsRepository> contactsRepositoryProvider =
    Provider<ContactsRepository>((ref) {
  return ContactsRepository(ref.read(dioClientProvider));
});
