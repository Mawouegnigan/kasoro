# Kasoro Mobile

App Flutter pour Kasoro — messagerie vocale multilingue pour l'Afrique de l'Ouest
(fon, adja, yoruba en priorité), avec traduction automatique texte + audio.

## État actuel

- ✅ Architecture "feature-first" (core/ + features/)
- ✅ Client Dio configuré, intercepteur JWT automatique
- ✅ Stockage sécurisé du token (`flutter_secure_storage`)
- ✅ State management : Riverpod (Notifier, sans codegen)
- ✅ Routing déclaratif avec redirection auto selon l'état d'auth (go_router)
- ✅ Feature auth complète : inscription + connexion + PIN numérique, id
  utilisateur résolu depuis le JWT (claim `sub`)
- ✅ Feature contacts complète : liste, ajout par numéro de téléphone,
  suppression
- ✅ Feature conversations : liste (avec résolution du nom du
  correspondant pour le 1:1), création à partir d'un contact
- ⏳ Feature messages (texte + audio + lecture traduite via
  `GET /messages/{id}/in/{language}`) : écran placeholder en place,
  logique à construire — c'est la prochaine étape
- ⏳ Enregistrement/lecture audio (`record`, `just_audio`) : dépendances
  posées, pas encore intégrées

## Points à vérifier côté backend avant la démo

1. **Claim `sub` du JWT** — voir section dédiée ci-dessous.
2. **Langue du membre à la création d'une conversation** — `POST /conversations`
   prend `member_ids` mais pas de langue par membre. `POST /conversations/{id}/members`
   prend `{ user_id, language }` pour ajouter un membre après coup. Il faut
   confirmer si la langue de lecture du créateur est déduite automatiquement
   de son `preferred_language`, ou s'il faut appeler explicitement
   `/members` juste après la création pour la fixer. Le mobile ne fait pas
   cet appel supplémentaire pour l'instant — à ajouter si le backend
   l'exige.
3. **Recherche de contact par téléphone** — pas de route dédiée
   aujourd'hui ; le mobile filtre `GET /users` côté client
   (`contacts_repository.dart`). Fonctionne pour un volume réduit
   d'utilisateurs, pas pour la production à grande échelle. Une route
   `GET /users/search?phone=...` réglerait ça proprement.

## Point d'attention backend (résolu côté mobile, à vérifier côté serveur)

Le flux de connexion a besoin de l'id utilisateur, que le backend ne renvoie
pas explicitement dans `/auth/login` (seulement `access_token` +
`token_type`). Plutôt que d'ajouter une route réseau supplémentaire,
le mobile décode le JWT côté client (`core/utils/jwt_decoder.dart`) et lit
l'id dans le claim standard `sub`.

**À vérifier côté FastAPI** : le token émis lors du login doit bien encoder
l'id utilisateur dans `sub` (convention standard avec python-jose/PyJWT,
généralement déjà le cas par défaut). Si ce n'est pas encore aligné, c'est
une ligne à corriger dans la fonction de création du JWT, pas une nouvelle
route à construire.

## Lancer le projet

```bash
flutter pub get
flutter run --dart-define=KASORO_API_BASE_URL=http://10.0.2.2:8000/api/v1
```

- Émulateur Android : `10.0.2.2` pointe vers `localhost` de la machine hôte.
- iOS Simulator : `localhost` fonctionne directement.
- Appareil physique : utiliser l'IP locale de la machine (ex. `192.168.x.x`),
  device et backend doivent être sur le même réseau Wi-Fi.

## Structure

```
lib/
  core/
    config/       # configuration API
    network/      # client Dio + gestion des erreurs
    storage/      # stockage sécurisé (token JWT)
    theme/        # thème visuel
    routing/      # go_router
  features/
    auth/
      data/           # modèles + repository (appels réseau bruts)
      application/    # state + controller Riverpod
      presentation/   # écrans + widgets
```

Chaque nouvelle feature (contacts, conversations, messages) doit suivre
cette même structure à trois couches.
