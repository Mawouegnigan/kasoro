import 'dart:convert';

/// Décode le payload d'un JWT côté client pour en extraire des claims,
/// notamment `sub` (l'id utilisateur). Ne vérifie PAS la signature —
/// ce n'est pas son rôle : la vérification appartient au serveur, qui
/// rejette déjà tout token invalide/expiré avec un 401.
///
/// Convention adoptée ici : le backend FastAPI encode l'id utilisateur
/// dans le claim standard `sub` du JWT (pratique la plus commune avec
/// python-jose / PyJWT). Si ce n'est pas le cas côté backend actuel,
/// il suffit d'aligner l'émission du token sur cette convention plutôt
/// que d'ajouter une route réseau supplémentaire.
class JwtDecoder {
  JwtDecoder._();

  static Map<String, dynamic> decodePayload(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      throw const FormatException('Token JWT malformé.');
    }

    final String normalized = base64Url.normalize(parts[1]);
    final String decoded = utf8.decode(base64Url.decode(normalized));
    return jsonDecode(decoded) as Map<String, dynamic>;
  }

  /// Extrait l'id utilisateur (claim `sub`). Retourne `null` si absent
  /// ou si le token ne peut pas être décodé.
  static String? extractUserId(String token) {
    try {
      final payload = decodePayload(token);
      final dynamic sub = payload['sub'];
      return sub?.toString();
    } catch (_) {
      return null;
    }
  }

  static DateTime? extractExpiry(String token) {
    try {
      final payload = decodePayload(token);
      final dynamic exp = payload['exp'];
      if (exp == null) return null;
      return DateTime.fromMillisecondsSinceEpoch((exp as int) * 1000);
    } catch (_) {
      return null;
    }
  }
}
