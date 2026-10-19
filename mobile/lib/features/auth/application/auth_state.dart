import '../data/models/user_model.dart';

/// État global d'authentification, consommé par le router pour décider
/// de rediriger vers /login ou /home.
sealed class AuthState {
  const AuthState();
}

/// État initial, avant que la vérification du token stocké ne soit terminée.
class AuthInitial extends AuthState {
  const AuthInitial();
}

class AuthLoading extends AuthState {
  const AuthLoading();
}

class AuthAuthenticated extends AuthState {
  const AuthAuthenticated(this.user);
  final UserModel user;
}

class AuthUnauthenticated extends AuthState {
  const AuthUnauthenticated();
}

class AuthError extends AuthState {
  const AuthError(this.message);
  final String message;
}
