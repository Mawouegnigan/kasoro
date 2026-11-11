import 'package:dio/dio.dart';

/// Exception normalisée pour toutes les erreurs remontées par l'API Kasoro.
///
/// Traduit les codes HTTP du backend en cas d'usage explicites côté UI :
/// - 401 → session expirée, il faut se reconnecter
/// - 403 → tentative d'accès à une ressource qui n'appartient pas à l'utilisateur
/// - 404 → ressource introuvable
/// - autres → erreur générique avec message serveur si disponible
class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.isUnauthorized = false,
    this.isForbidden = false,
    this.isTranslationUnavailable = false,
  });

  factory ApiException.fromDioException(DioException e) {
    final int? status = e.response?.statusCode;
    final dynamic data = e.response?.data;
    final String? serverMessage =
        (data is Map<String, dynamic>) ? data['detail']?.toString() : null;

    if (status == 401) {
      return ApiException(
        message: serverMessage ?? 'Session expirée, reconnectez-vous.',
        statusCode: status,
        isUnauthorized: true,
      );
    }
    if (status == 403) {
      return ApiException(
        message: serverMessage ?? "Accès non autorisé à cette ressource.",
        statusCode: status,
        isForbidden: true,
      );
    }
    if (status == 422 && data is Map<String, dynamic> && data['detail'] is List) {
      return ApiException(
        message: 'Informations invalides, vérifiez les champs saisis.',
        statusCode: status,
      );
    }
    if (status == 422 && serverMessage == 'translation_unavailable') {
      return ApiException(
        message: 'Traduction indisponible pour cette langue.',
        statusCode: status,
        isTranslationUnavailable: true,
      );
    }
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return ApiException(
        message: 'Impossible de joindre le serveur Kasoro.',
        statusCode: status,
      );
    }

    return ApiException(
      message: serverMessage ?? 'Une erreur est survenue (${status ?? "réseau"}).',
      statusCode: status,
    );
  }

  final String message;
  final int? statusCode;
  final bool isUnauthorized;
  final bool isForbidden;
  final bool isTranslationUnavailable;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
