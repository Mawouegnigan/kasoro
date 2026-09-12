# Kasoro — Modèle de données de la messagerie

Ce document décrit le schéma relationnel de la messagerie Kasoro. Le SQL
prêt à exécuter est dans `schema.sql` (même dossier).

## Principe directeur

**Traduire à la demande, mettre en cache pour tous les lecteurs suivants.**
Un message n'est jamais pré-généré dans toutes les langues à l'envoi — il
est traduit la première fois qu'un destinataire choisit une langue donnée,
puis le résultat est mis en cache et réutilisé instantanément pour tous les
lecteurs suivants demandant la même langue. C'est la contrainte
`UNIQUE (message_id, language)` sur `message_translations` qui garantit ce
cache.

## Les 6 tables

### `users`
Le profil de chaque utilisateur. `voice_tag_url` est l'audio où la
personne dit elle-même son nom (prioritaire) ; `voice_tag_generated_url`
est un repli généré par synthèse vocale si elle ne l'a pas enregistré.
`primary_language` détermine la langue par défaut dans laquelle elle lit
ses messages.

### `contacts`
Ce n'est **pas** un simple annuaire — c'est la relation entre deux
utilisateurs, du point de vue du propriétaire de la liste. `owner_id` et
`contact_user_id` référencent tous les deux `users`, ce qui permet à
chacun d'avoir son propre carnet, avec ses propres labels vocaux
personnalisés (`custom_voice_tag_url`) pour ses contacts — utile si on
préfère entendre un surnom, ou une meilleure prononciation que celle
enregistrée par la personne elle-même.

### `conversations`
Une conversation directe (deux personnes) ou un groupe. `type` distingue
les deux ; `name` et `avatar_url` ne servent que pour les groupes.

### `conversation_members`
La table pivot la plus importante du système : elle dit, pour une
conversation donnée, qui en fait partie — et donc, en la croisant avec
`users.primary_language`, **quelles langues sont réellement représentées**.
C'est elle qui évite de traduire un message vers plus de langues que
nécessaire : un groupe de 20 personnes parlant 4 langues ne génère que 4
traductions par message, pas 20.

### `messages`
Le contenu original, tel qu'envoyé — texte saisi, ou transcription si
message vocal (`original_type = 'audio'`). `original_language` est déclarée
ou détectée à l'envoi.

### `message_translations`
Une ligne par `(message_id, langue)`. Le champ `status` (`pending` /
`ready` / `failed`) permet au client d'afficher "traduction en cours..."
pendant que le pipeline (STT → traduction → TTS) tourne en tâche de fond.

## Flux de lecture d'un message

1. Le destinataire ouvre un message, dans sa `primary_language`.
2. Le backend cherche `message_translations` pour `(message_id, langue)`.
3. **Trouvée et `status = 'ready'`** → sert directement le résultat en cache.
4. **Absente** → crée une ligne `status = 'pending'`, déclenche le pipeline
   de traduction en tâche de fond, notifie le client par WebSocket une fois
   `status = 'ready'`.

## Flux à l'envoi d'un message (optimisation groupes)

Plutôt que d'attendre que chaque membre ouvre le message un par un, le
backend peut interroger `conversation_members` pour connaître d'avance
toutes les langues présentes dans la conversation, et déclencher leurs
traductions en parallèle dès l'envoi — la requête est documentée en bas de
`schema.sql`.

## Ce qui n'est volontairement pas dans ce schéma (pour l'instant)

- **Statuts de lecture** (qui a lu, à quelle heure) : fonctionnalité
  standard que tout concurrent a déjà — pas différenciante, facile à
  ajouter plus tard sans toucher au reste du schéma.
- **Messages vidéo** : mis de côté par choix (voir discussion initiale du
  projet) — `messages.original_type` n'accepte que `'text'` et `'audio'`
  pour l'instant, à étendre plus tard.
- **Réactions, réponses en fil (threads), messages épinglés** : aucune de
  ces fonctionnalités n'est différenciante par rapport à WhatsApp/Messenger
  — à ajouter seulement si un vrai besoin utilisateur émerge.

## Lien avec le pipeline déjà validé

Les valeurs possibles pour `users.primary_language`,
`messages.original_language` et `message_translations.language`
correspondent aux codes déjà testés et documentés dans
`pipeline/README.md` — se référer à ce document pour savoir quelles
langues sont réellement prêtes (traduction + voix) avant de les proposer
dans l'interface de choix de langue.