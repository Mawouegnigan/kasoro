# Suivi des contacts natifs

Une ligne par langue. Statuts possibles : `à identifier` / `contacté` /
`phrases reçues` / `validées et intégrées`.

| Langue | Code | Contact envisagé | Moyen de contact | Statut | Notes |
|---|---|---|---|---|---|
| Fon | `fon` | | | à identifier | Prioritaire (langue principale visée à Cotonou) |
| Yoruba | `yo` | | | à identifier | Déjà testé en registre soutenu, à améliorer |
| Adja | `ajg` | | | à identifier | Pas encore couverte par traduction/voix automatiques — voir README pipeline |
| Wolof | `wo` | | | à identifier | Traduction OK, voix (MMS) manquante |
| Haoussa | `ha` | | | à identifier | |
| Swahili | `sw` | | | à identifier | |
| Igbo | `ig` | | | à identifier | Traduction OK, voix (MMS) manquante |
| Bambara | `bm` | | | à identifier | |

## Comment utiliser ce tableau

1. Remplis "Contact envisagé" dès que tu identifies quelqu'un (famille,
   église, communauté, réseau professionnel).
2. Passe le statut à "contacté" une fois le message envoyé avec les 10
   phrases du fichier `<code>.json` correspondant.
3. Passe à "phrases reçues" quand il t'a répondu.
4. Remplis les traductions dans le fichier JSON, passe
   `validated_by_native` à `true` pour chaque phrase confirmée, puis
   marque la ligne "validées et intégrées" ici.
