import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/api_config.dart';
import '../storage/secure_storage_service.dart';

/// Provider exposant une instance Dio unique, configurée avec :
/// - le base URL de l'API Kasoro
/// - un intercepteur qui injecte automatiquement `Authorization: Bearer <token>`
/// - un intercepteur qui traduit les 401 en événement "session expirée"
///
/// Toutes les features (auth, contacts, conversations, messages) doivent
/// consommer ce provider plutôt que d'instancier Dio elles-mêmes.
final Provider<Dio> dioClientProvider = Provider<Dio>((ref) {
  final Dio dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: ApiConfig.connectTimeout,
      receiveTimeout: ApiConfig.receiveTimeout,
      contentType: 'application/json',
    ),
  );

  final SecureStorageService storage = ref.read(secureStorageServiceProvider);

  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) async {
        // Les routes publiques n'ont pas besoin de token.
        final bool isPublic = options.path.contains('/auth/login') ||
            (options.path.endsWith('/users') && options.method == 'POST');

        if (!isPublic) {
          final String? token = await storage.readAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
        }
        handler.next(options);
      },
      onError: (DioException e, handler) async {
        if (e.response?.statusCode == 401) {
          // Le token a expiré ou est invalide : on le purge.
          // L'écran d'accueil du router redirigera vers /login
          // en observant authStateProvider.
          await storage.deleteAccessToken();
        }
        handler.next(e);
      },
    ),
  );

  return dio;
});
