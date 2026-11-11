import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/application/auth_providers.dart';
import '../../features/auth/application/auth_state.dart';
import '../../features/auth/presentation/screens/login_screen.dart';
import '../../features/auth/presentation/screens/profile_screen.dart';
import '../../features/corrections/presentation/screens/validation_screen.dart';
import '../../features/auth/presentation/screens/register_screen.dart';
import '../../features/contacts/presentation/screens/add_contact_screen.dart';
import '../../features/contacts/presentation/screens/contacts_screen.dart';
import '../../features/conversations/presentation/screens/conversations_list_screen.dart';
import '../../features/conversations/presentation/screens/new_conversation_screen.dart';
import '../../features/messages/presentation/screens/conversation_screen.dart';

final Provider<GoRouter> appRouterProvider = Provider<GoRouter>((ref) {
  // IMPORTANT : on ne fait PAS `ref.watch(authControllerProvider)` ici.
  // Ce provider ne doit construire le GoRouter qu'UNE SEULE FOIS pour
  // toute la durée de vie de l'app — sinon chaque changement d'état
  // d'auth (login, logout, inscription réussie) recrée entièrement le
  // router, ce qui jette la navigation en cours et rend les boutons
  // "silencieux" juste après un changement d'état. Le rafraîchissement
  // du redirect se fait via `refreshListenable`, qui redemande au MÊME
  // router de ré-évaluer `redirect` sans le reconstruire.
  return GoRouter(
    initialLocation: '/',
    refreshListenable: _AuthStateListenable(ref),
    redirect: (context, state) {
      // Lu à chaque navigation, donc toujours à jour — contrairement à
      // une valeur capturée une fois au moment de la création du router.
      final AuthState authState = ref.read(authControllerProvider);

      final bool isAuthenticated = authState is AuthAuthenticated;
      final bool isLoadingOrInitial =
          authState is AuthInitial || authState is AuthLoading;
      final bool goingToAuthScreens =
          state.matchedLocation == '/login' || state.matchedLocation == '/register';

      if (isLoadingOrInitial) return null; // ne redirige pas pendant le check initial

      if (!isAuthenticated && !goingToAuthScreens) return '/login';
      if (isAuthenticated && goingToAuthScreens) return '/';

      return null;
    },
    routes: [
      GoRoute(path: '/', builder: (context, state) => const ConversationsListScreen()),
      GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
      GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
      GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
      GoRoute(path: '/corrections', builder: (context, state) => const ValidationScreen()),
      GoRoute(path: '/contacts', builder: (context, state) => const ContactsScreen()),
      GoRoute(path: '/contacts/add', builder: (context, state) => const AddContactScreen()),
      GoRoute(
        path: '/conversations/new',
        builder: (context, state) => const NewConversationScreen(),
      ),
      GoRoute(
        path: '/conversations/:id',
        builder: (context, state) => ConversationScreen(
          conversationId: state.pathParameters['id']!,
        ),
      ),
    ],
  );
});

/// Permet à go_router de se rafraîchir quand authControllerProvider change,
/// sans dépendre directement de Riverpod dans GoRouter.
class _AuthStateListenable extends ChangeNotifier {
  _AuthStateListenable(this._ref) {
    _ref.listen<AuthState>(authControllerProvider, (previous, next) {
      notifyListeners();
    });
  }

  // ignore: unused_field
  final Ref _ref;
}
