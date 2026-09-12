# Kasoro — Test du pipeline de traduction vocale

Ce dossier valide, en conditions réelles, la brique la plus critique du
projet : la chaîne **audio → transcription → traduction → audio traduit**.
C'est la seule chose qui différencie réellement Kasoro de Lenali ou Ayoba —
donc c'est la première chose à tester, avant tout code d'app.

## Architecture actuelle

| Étape | Techno | Où ça tourne |
|---|---|---|
| STT (transcription) | Groq API, Whisper-large-v3 | Cloud (clé API requise) |
| MT (traduction) | Google Translate + MyMemory (fallback) | Cloud (gratuit, sans clé) |
| TTS (voix) | MMS (Meta), modèle par langue | **Local**, gratuit, sans clé |

## 1. Installer les dépendances

```bash
pip install -r requirements.txt
```

`torch` et `transformers` sont volumineux — l'installation peut prendre
plusieurs minutes.

## 2. Obtenir la clé API Groq (seule clé nécessaire)

- **Groq** (transcription, gratuit en quota d'essai) :
  https://console.groq.com/keys

Copie `.env.example` en `.env` et colle ta clé dedans. La synthèse vocale ne
nécessite plus de clé (MMS tourne en local).

## 3. Préparer un fichier audio de test

Enregistre-toi avec ton téléphone en train de dire une phrase simple en
français (15-20 secondes max). Formats acceptés : `.mp3`, `.wav`, `.ogg`,
`.m4a`, `.flac`, `.webm` (pas `.aac` — Groq le refuse).

## 4. Vérifier la couverture d'une langue AVANT de lancer un test complet

```bash
python check_coverage.py yo fr wo ha sw ig bm am zu so rw
```

Affiche, pour chaque langue, si la traduction et la voix sont réellement
disponibles — évite de découvrir un manque au milieu d'un test.

## 5. Lancer le test complet

```bash
python pipeline.py --audio ton_message.mp3 --target-lang yo
```

Génère `output_yo.wav`. Écoute-le et évalue :

1. **La transcription** correspond-elle fidèlement à ce que tu as dit ?
2. **La traduction** garde-t-elle le bon sens (tons, diacritiques corrects) ?
3. **L'audio généré** est-il compréhensible et naturel pour un vrai locuteur
   natif de la langue cible ? — le juge final, plus fiable que n'importe
   quel test technique.

## Bilan de couverture linguistique (mis à jour sur ~100 langues testées)

On a testé la quasi-totalité des 100 langues les plus parlées d'Afrique
(classement par nombre de locuteurs). Résultat : **31 langues confirmées
prêtes** (traduction + voix), et le reste réparti en trois catégories
selon ce qui manque précisément — utile pour savoir où chercher en
priorité plutôt que de traiter "les langues manquantes" comme un bloc flou.

### ✅ Prêtes (traduction + voix confirmées) — 31 langues

| Code | Langue | Code | Langue | Code | Langue |
|---|---|---|---|---|---|
| `yo` | Yoruba* | `ee` | Éwé | `mos` | Moore |
| `fon` | Fon | `ff` | Peul/Fulfulde | `vmw` | Makua |
| `fr` | Français | `rn` | Kirundi | `ts` | Tsonga |
| `en` | Anglais | `kab` | Kabyle (Berbère) | `dyu` | Dioula |
| `ha` | Haoussa | `pt` | Portugais | `bem` | Bemba |
| `sw` | Swahili | `ar` | Arabe | `taq` | Tamasheq (Tuareg) |
| `bm` | Bambara | `om` | Oromo | `seh` | Sena |
| `am` | Amharique | `sn` | Shona | | |
| `so` | Somali | `ny` | Chichewa | | |
| `rw` | Kinyarwanda | `ak` | Akan/Twi | | |
| `ti` | Tigrinya | `mg` | Malgache | | |
| `lg` | Luganda | `ki` | Kikuyu | | |

*Seul le yoruba a été validé à l'oreille par un locuteur natif. Les
autres ont une couverture technique confirmée, pas encore un jugement de
qualité humain. Le fon fonctionne mais en registre soutenu (voir plus bas).

### 🔊 Il ne manque QUE la voix (traduction déjà bonne) — priorité recherche TTS

`wo` Wolof · `ig` Igbo · `zu` Zoulou · `af` Afrikaans · `xh` Xhosa ·
`ln` Lingala · `st` Sesotho · `tn` Tswana · `kg` Kikongo ·
`nso` Sotho du Nord · `umb` Umbundu · `lua` Tshiluba/Baluba ·
`luo` Luo/Dholuo · `ss` Swazi · `kmb` Kimbundu · `kam` Kamba ·
`guz` Gusii · `kln` Kalenjin · `mer` Meru · `tum` Tumbuka

**20 langues.** Un vrai modèle wolof existe déjà en dehors de MMS
(`galsenai/xTTS-v2-wolof`, XTTS v2 — architecture de clonage vocal,
intégration plus lourde que MMS, à évaluer dans une prochaine session) et
un modèle communautaire couvre l'igbo (`9jaLingo/Spark-TTS-African`).
Piste à suivre pour les 18 autres : chercher des modèles TTS communautaires
équivalents, langue par langue.

### 📝 Il ne manque QUE la traduction (voix déjà prête) — piste LLM/few-shot

`nyn` Nyankore · `sid` Sidamo · `xog` Soga · `teo` Teso · `ngl` Lomwe ·
`laj` Lango · `tem` Temne · `alz` Alur · `myx` Gisu/Masaaba

**9 langues, très concentrées en Afrique de l'Est (Ouganda/Kenya/Éthiopie).**
Ici, MMS peut déjà produire la voix — c'est la traduction automatique
(Google/MyMemory) qui ne couvre pas ces langues. Piste naturelle : le même
système de traduction LLM + phrases de référence natives qu'on construit
pour le fon (voir plus bas) pourrait s'appliquer directement ici, une fois
des exemples validés rassemblés.

### ⛔ Ni traduction ni voix — chantier complet à construire

`ajg` Adja · `kau` Kanouri · `nd` Ndebele · `son` Songhaï-Zarma ·
`ve` Venda · `tiv` Tiv · `bci` Baoulé · `bej` Beja · `cgg` Chiga ·
`snk` Soninké · `wal` Wolaytta · `bum` Bulu · `bin` Edo · `toi` Tonga ·
`dnj` Dan/Yacouba

**15 langues.** Aucune des deux briques n'existe aujourd'hui dans les
outils gratuits utilisés ici. Le sous-groupe le plus notable géographiquement
est ouest-africain profond (Côte d'Ivoire, Nigeria intérieur) et
centre-africain (Angola, Congo) — zones à cibler en priorité si on veut
vraiment élargir la couverture réelle du continent, plutôt que
d'accumuler des langues déjà bien dotées.

### Ce que révèle ce bilan, au global

La couverture technique gratuite s'effondre nettement en dessous d'environ
10-15 millions de locuteurs par langue — pas une surprise en soi, mais
maintenant confirmée par des faits plutôt que supposée. Les 31 langues
prêtes couvrent déjà une large majorité des locuteurs africains en poids
démographique (la plupart des "géants linguistiques" du continent y sont),
mais la longue traîne des langues à 1-10 millions de locuteurs reste
largement à construire, langue par langue.

## Adja — cas particulier documenté

Contrairement au fon (langue Gbe voisine), l'adja n'a aucune ressource
numérique suffisante dans les outils gratuits utilisés ici. Voir
`reference_phrases/ajg.json`, déjà prêt à recevoir des contributions
natives le jour où ça devient une priorité.

## Sur le registre du fon (et bientôt d'autres langues)

Le fon fonctionne techniquement, mais Google Translate/MyMemory produisent
un registre soutenu/littéraire (probablement hérité de corpus religieux
utilisés pour entraîner ces langues peu dotées). Une tentative de
traduction via LLM (`--translator llm`) pour obtenir un ton plus familier
a produit un mélange avec des langues Gbe voisines (gun, éwé) sans
prévenir — donc non fiable en l'état.

La solution retenue : un système de "phrases de référence" validées par de
vrais locuteurs natifs (voir `reference_phrases/README.md`), qui servent
d'exemples pour guider le LLM une fois suffisamment remplies. Tant qu'il
n'y en a pas assez, le pipeline reste sur la traduction classique (`mt`)
par défaut — le choix le plus sûr aujourd'hui. **Prochaine étape concrète,
à faire quand le temps le permet** : identifier de vrais locuteurs natifs
(fon en priorité, puis les autres langues du tableau ci-dessus) et
recueillir leurs traductions via `reference_phrases/`.

## Limites connues de ce prototype (normal à ce stade)

- La traduction utilise Google Translate par défaut, qui est parfois
  instable (erreurs serveur), d'où le fallback automatique vers MyMemory.
  Qualité variable selon les langues africaines, et souvent en registre
  soutenu — à comparer un jour avec Lelapa AI ou NLLB-200 si besoin de
  mieux.
- Pas de cache ni de gestion d'erreurs de niveau production : c'est un
  script de test, pas un service prêt à être déployé.
- La vérification de couverture (`check_coverage.py`) confirme que les
  briques techniques existent, pas que leur qualité est suffisante pour un
  vrai lancement public — toujours faire valider par un locuteur natif
  avant d'annoncer une langue comme supportée.

## Limites connues de ce prototype (normal à ce stade)

- La traduction utilise Google Translate par défaut, qui est parfois
  instable (erreurs serveur), d'où le fallback automatique vers MyMemory.
  Qualité variable selon les langues africaines, et souvent en registre
  soutenu — à comparer un jour avec Lelapa AI ou NLLB-200 si besoin de
  mieux.
- Pas de cache ni de gestion d'erreurs de niveau production : c'est un
  script de test, pas un service prêt à être déployé.
- La vérification de couverture (`check_coverage.py`) confirme que les
  briques techniques existent, pas que leur qualité est suffisante pour un
  vrai lancement public — toujours faire valider par un locuteur natif
  avant d'annoncer une langue comme supportée.