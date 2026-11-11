/// Langues actuellement les plus fiables côté pipeline de traduction
/// (voir decisions-and-learnings du projet backend). D'autres langues
/// seront ajoutées à mesure que le pipeline STT/MT/TTS est enrichi.
const List<(String code, String label)> supportedLanguages = [
  ('fr', 'Français'),
  ('fon', 'Fon'),
  ('yo', 'Yoruba'),
  ('en', 'English'),
  ('wo', 'Wolof'),
];
