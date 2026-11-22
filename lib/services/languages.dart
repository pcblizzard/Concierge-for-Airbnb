class Lang {
  const Lang(this.code, this.endonym, this.stt);
  final String code; // ISO 639-1
  final String endonym; // Name in der eigenen Sprache
  final String stt; // Locale für Sprachein-/ausgabe
}

const languages = <Lang>[
  Lang('de', 'Deutsch', 'de-DE'),
  Lang('en', 'English', 'en-US'),
  Lang('es', 'Español', 'es-ES'),
  Lang('fr', 'Français', 'fr-FR'),
  Lang('tr', 'Türkçe', 'tr-TR'),
  Lang('it', 'Italiano', 'it-IT'),
  Lang('pt', 'Português', 'pt-PT'),
  Lang('ar', 'العربية', 'ar-SA'),
  Lang('zh', '中文', 'zh-CN'),
  Lang('hi', 'हिन्दी', 'hi-IN'),
  Lang('ja', '日本語', 'ja-JP'),
  Lang('ko', '한국어', 'ko-KR'),
  Lang('ru', 'Русский', 'ru-RU'),
  Lang('pl', 'Polski', 'pl-PL'),
  Lang('nl', 'Nederlands', 'nl-NL'),
  Lang('uk', 'Українська', 'uk-UA'),
];

Lang langByCode(String c) =>
    languages.firstWhere((l) => l.code == c, orElse: () => languages.first);
