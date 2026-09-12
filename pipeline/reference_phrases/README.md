# Phrases de référence par langue

Ce dossier prépare le terrain pour une amélioration future : demander à de
vrais locuteurs natifs de traduire un petit jeu de phrases du quotidien,
pour guider la traduction vers un registre parlé/familier — plutôt que le
registre soutenu que produisent Google Translate/MyMemory par défaut.

## Pourquoi ce système existe

On a testé une traduction "à la volée" par un modèle de langage (LLM) pour
obtenir un ton plus familier, mais pour des langues peu dotées comme le fon,
le modèle mélange des langues voisines (gun, éwé, adja...) sans prévenir —
un résultat fluide mais faux. La solution qui fonctionne réellement pour ce
genre de problème s'appelle le "few-shot" : montrer au modèle quelques
vrais exemples authentiques AVANT de lui demander de traduire, pour
l'ancrer dans la bonne langue et le bon registre.

Ça suppose d'avoir ces exemples authentiques — d'où ce dossier.

## Comment ça fonctionne

1. Chaque langue a un fichier `<code>.json` (ex: `fon.json`, `yo.json`)
   contenant les mêmes 10 phrases françaises simples, avec un champ
   `translation` vide et `validated_by_native: false`.
2. Tu envoies ces phrases françaises à un vrai locuteur natif de la langue
   (proche, membre de communauté, contact local à Cotonou ou ailleurs).
3. Il te donne sa traduction, dans son fon (ou yoruba, wolof...) parlé de
   tous les jours — pas soutenu, pas littéraire.
4. Tu remplis le champ `translation` dans le fichier JSON correspondant,
   et passes `validated_by_native` à `true`.
5. Le pipeline (`pipeline.py --translator llm`) utilise automatiquement ces
   exemples validés comme repère avant de traduire ta phrase de test — dès
   qu'au moins 3-4 exemples sont validés pour une langue donnée.

Tant qu'aucun exemple n'est validé pour une langue, le pipeline continue
d'utiliser la traduction classique (`mt`, Google/MyMemory) par défaut — le
choix le plus sûr aujourd'hui, même si le registre y est parfois trop
soutenu.

## Suivi des contacts

Voir `CONTACTS.md` dans ce même dossier pour noter qui tu comptes solliciter
pour chaque langue, et où ça en est.

## Ajouter une nouvelle langue

Duplique `_template.json`, renomme-le avec le bon code langue (ex: `wo.json`
pour le wolof), et suis les mêmes étapes.
