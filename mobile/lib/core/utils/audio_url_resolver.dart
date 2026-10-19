import '../config/api_config.dart';

/// Le backend construit parfois les URLs de fichiers audio avec
/// `localhost` en dur (ex: `http://localhost:8000/audio/xxx.m4a`),
/// ce qui n'a de sens que depuis la machine qui héberge le serveur.
/// Sur un appareil mobile, `localhost` désigne l'appareil lui-même,
/// jamais le serveur — la requête échoue silencieusement ou pointe
/// au mauvais endroit.
///
/// Cette fonction corrige ce cas (et les chemins relatifs comme
/// `/audio/xxx.m4a`) en réécrivant vers l'hôte réel configuré dans
/// `ApiConfig.baseUrl`, pour que la lecture fonctionne quel que soit
/// ce que renvoie le backend.
String resolveAudioUrl(String urlOrPath) {
  final Uri apiUri = Uri.parse(ApiConfig.baseUrl);
  final String realHost = '${apiUri.scheme}://${apiUri.host}:${apiUri.port}';

  if (urlOrPath.startsWith('/')) {
    return '$realHost$urlOrPath';
  }

  final Uri parsed = Uri.tryParse(urlOrPath) ?? Uri();
  final bool pointsToLocalhost = parsed.host == 'localhost' || parsed.host == '127.0.0.1';

  if (pointsToLocalhost) {
    return parsed.replace(scheme: apiUri.scheme, host: apiUri.host, port: apiUri.port).toString();
  }

  return urlOrPath;
}
