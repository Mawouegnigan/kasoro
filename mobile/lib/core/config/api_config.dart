/// Configuration centrale de l'API Kasoro.
///
/// En développement local (émulateur Android), `localhost` doit être
/// remplacé par `10.0.2.2`. Sur iOS Simulator ou en test physique via
/// Wi-Fi local, utiliser l'IP de la machine hôte.
class ApiConfig {
  ApiConfig._();

  /// Change cette valeur selon l'environnement d'exécution.
  static const String baseUrl = String.fromEnvironment(
    'KASORO_API_BASE_URL',
    defaultValue: 'http://10.207.240.71:8000/api/v1',
  );

  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // La première lecture d'un message dans une nouvelle langue déclenche
  // traduction + synthèse vocale à la volée : ça peut être long.
  static const Duration translationReceiveTimeout = Duration(minutes: 3);
}
