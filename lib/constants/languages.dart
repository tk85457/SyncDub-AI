class SyncDubLanguage {
  final String code;
  final String name;
  final String flag;
  final String abbr;

  const SyncDubLanguage({
    required this.code,
    required this.name,
    required this.flag,
    required this.abbr,
  });
}

const List<SyncDubLanguage> kSupportedLanguages = [
  // South Asian
  SyncDubLanguage(code: 'hi-IN', name: 'Hindi', flag: '🇮🇳', abbr: 'HI'),
  SyncDubLanguage(code: 'en-US', name: 'English', flag: '🇺🇸', abbr: 'EN'),
  SyncDubLanguage(code: 'bn-IN', name: 'Bengali', flag: '🇮🇳', abbr: 'BN'),
  SyncDubLanguage(code: 'ta-IN', name: 'Tamil', flag: '🇮🇳', abbr: 'TA'),
  SyncDubLanguage(code: 'te-IN', name: 'Telugu', flag: '🇮🇳', abbr: 'TE'),
  SyncDubLanguage(code: 'mr-IN', name: 'Marathi', flag: '🇮🇳', abbr: 'MR'),
  SyncDubLanguage(code: 'gu-IN', name: 'Gujarati', flag: '🇮🇳', abbr: 'GU'),
  SyncDubLanguage(code: 'kn-IN', name: 'Kannada', flag: '🇮🇳', abbr: 'KN'),
  SyncDubLanguage(code: 'ml-IN', name: 'Malayalam', flag: '🇮🇳', abbr: 'ML'),
  SyncDubLanguage(code: 'pa-IN', name: 'Punjabi', flag: '🇮🇳', abbr: 'PA'),
  SyncDubLanguage(code: 'ur-PK', name: 'Urdu', flag: '🇵🇰', abbr: 'UR'),
  SyncDubLanguage(code: 'ne-NP', name: 'Nepali', flag: '🇳🇵', abbr: 'NE'),

  // East & Southeast Asian
  SyncDubLanguage(code: 'ja-JP', name: 'Japanese', flag: '🇯🇵', abbr: 'JA'),
  SyncDubLanguage(code: 'ko-KR', name: 'Korean', flag: '🇰🇷', abbr: 'KO'),
  SyncDubLanguage(code: 'zh-CN', name: 'Chinese (Simplified)', flag: '🇨🇳', abbr: 'ZH'),
  SyncDubLanguage(code: 'zh-TW', name: 'Chinese (Traditional)', flag: '🇹🇼', abbr: 'ZHT'),
  SyncDubLanguage(code: 'vi-VN', name: 'Vietnamese', flag: '🇻🇳', abbr: 'VI'),
  SyncDubLanguage(code: 'th-TH', name: 'Thai', flag: '🇹🇭', abbr: 'TH'),
  SyncDubLanguage(code: 'id-ID', name: 'Indonesian', flag: '🇮🇩', abbr: 'ID'),
  SyncDubLanguage(code: 'ms-MY', name: 'Malay', flag: '🇲🇾', abbr: 'MS'),
  SyncDubLanguage(code: 'fil-PH', name: 'Filipino', flag: '🇵🇭', abbr: 'FIL'),

  // European & Global
  SyncDubLanguage(code: 'es-ES', name: 'Spanish', flag: '🇪🇸', abbr: 'ES'),
  SyncDubLanguage(code: 'fr-FR', name: 'French', flag: '🇫🇷', abbr: 'FR'),
  SyncDubLanguage(code: 'de-DE', name: 'German', flag: '🇩🇪', abbr: 'DE'),
  SyncDubLanguage(code: 'it-IT', name: 'Italian', flag: '🇮🇹', abbr: 'IT'),
  SyncDubLanguage(code: 'pt-BR', name: 'Portuguese (Brazil)', flag: '🇧🇷', abbr: 'PT'),
  SyncDubLanguage(code: 'ru-RU', name: 'Russian', flag: '🇷🇺', abbr: 'RU'),
  SyncDubLanguage(code: 'ar-SA', name: 'Arabic', flag: '🇸🇦', abbr: 'AR'),
  SyncDubLanguage(code: 'tr-TR', name: 'Turkish', flag: '🇹🇷', abbr: 'TR'),
  SyncDubLanguage(code: 'nl-NL', name: 'Dutch', flag: '🇳🇱', abbr: 'NL'),
  SyncDubLanguage(code: 'pl-PL', name: 'Polish', flag: '🇵🇱', abbr: 'PL'),
];
