import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../core/utils/jwt_decoder.dart';
import '../data/models/user_model.dart';
import '../data/repositories/auth_repository.dart';
import 'auth_state.dart';

/// Source de vérité unique pour l'état de session. Le router (`app_router.dart`)
/// observe ce provider pour décider des redirections.
class AuthController extends Notifier<AuthState> {
  @override
  AuthState build() {
    // Vérifie s'il existe déjà un token valide au démarrage de l'app.
    Future.microtask(_restoreSession);
    return const AuthInitial();
  }

  AuthRepository get _repository => ref.read(authRepositoryProvider);
  SecureStorageService get _storage => ref.read(secureStorageServiceProvider);

  Future<void> _restoreSession() async {
    state = const AuthLoading();
    final String? token = await _storage.readAccessToken();
    final String? userId = await _storage.readCurrentUserId();

    if (token == null || userId == null) {
      state = const AuthUnauthenticated();
      return;
    }

    try {
      final user = await _repository.fetchUser(userId);
      state = AuthAuthenticated(user);
    } on ApiException {
      // Token invalide/expiré : on nettoie et on repart de zéro.
      await _storage.clearAll();
      state = const AuthUnauthenticated();
    }
  }

  Future<void> register({
    required String phoneNumber,
    required String displayName,
    required String preferredLanguage,
    required String pin,
  }) async {
    state = const AuthLoading();
    try {
      await _repository.register(
        phoneNumber: phoneNumber,
        displayName: displayName,
        preferredLanguage: preferredLanguage,
        pin: pin,
      );
      // Inscription réussie → on enchaîne automatiquement sur la connexion.
      await login(phoneNumber: phoneNumber, pin: pin);
    } on ApiException catch (e) {
      state = AuthError(e.message);
    }
  }

  Future<void> login({
    required String phoneNumber,
    required String pin,
  }) async {
    state = const AuthLoading();
    try {
      final auth = await _repository.login(phoneNumber: phoneNumber, pin: pin);
      await _storage.saveAccessToken(auth.accessToken);

      // L'id utilisateur n'est jamais mis en cache "à l'aveugle" : on le
      // relit systématiquement depuis le token lui-même (claim `sub`).
      // C'est la seule source fiable après un redémarrage de l'app sur
      // un compte déjà connecté auparavant — voir jwt_decoder.dart pour
      // la convention attendue côté backend.
      final String? userId = JwtDecoder.extractUserId(auth.accessToken);
      if (userId == null) {
        state = const AuthError(
          "Connexion impossible : réponse du serveur invalide. "
          "Réessayez dans un instant. "
          "Si le problème continue, contactez le support.",
        );
        return;
      }

      await _storage.saveCurrentUserId(userId);
      final user = await _repository.fetchUser(userId);
      state = AuthAuthenticated(user);
    } on ApiException catch (e) {
      state = AuthError(e.message);
    }
  }

  /// Met a jour l utilisateur connecte apres une modification reussie du profil.
  void setUser(UserModel user) {
    state = AuthAuthenticated(user);
  }

  Future<void> logout() async {
    await _storage.clearAll();
    state = const AuthUnauthenticated();
  }
}

final NotifierProvider<AuthController, AuthState> authControllerProvider =
    NotifierProvider<AuthController, AuthState>(AuthController.new);
