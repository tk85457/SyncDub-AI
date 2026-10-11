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
  // South Asian (15)
  SyncDubLanguage(code: 'hi', name: 'Hindi', flag: '🇮🇳', abbr: 'HI'),
  SyncDubLanguage(code: 'en', name: 'English', flag: '🇺🇸', abbr: 'EN'),
  SyncDubLanguage(code: 'bn', name: 'Bengali', flag: '🇮🇳', abbr: 'BN'),
  SyncDubLanguage(code: 'ta', name: 'Tamil', flag: '🇮🇳', abbr: 'TA'),
  SyncDubLanguage(code: 'te', name: 'Telugu', flag: '🇮🇳', abbr: 'TE'),
  SyncDubLanguage(code: 'mr', name: 'Marathi', flag: '🇮🇳', abbr: 'MR'),
  SyncDubLanguage(code: 'gu', name: 'Gujarati', flag: '🇮🇳', abbr: 'GU'),
  SyncDubLanguage(code: 'kn', name: 'Kannada', flag: '🇮🇳', abbr: 'KN'),
  SyncDubLanguage(code: 'ml', name: 'Malayalam', flag: '🇮🇳', abbr: 'ML'),
  SyncDubLanguage(code: 'pa', name: 'Punjabi', flag: '🇮🇳', abbr: 'PA'),
  SyncDubLanguage(code: 'or', name: 'Odia', flag: '🇮🇳', abbr: 'OR'),
  SyncDubLanguage(code: 'as', name: 'Assamese', flag: '🇮🇳', abbr: 'AS'),
  SyncDubLanguage(code: 'ur', name: 'Urdu', flag: '🇵🇰', abbr: 'UR'),
  SyncDubLanguage(code: 'ne', name: 'Nepali', flag: '🇳🇵', abbr: 'NE'),
  SyncDubLanguage(code: 'si', name: 'Sinhala', flag: '🇱🇰', abbr: 'SI'),

  // East Asian (5)
  SyncDubLanguage(code: 'ja', name: 'Japanese', flag: '🇯🇵', abbr: 'JA'),
  SyncDubLanguage(code: 'zh-CN', name: 'Chinese (Simplified)', flag: '🇨🇳', abbr: 'ZH'),
  SyncDubLanguage(code: 'zh-TW', name: 'Chinese (Traditional)', flag: '🇹🇼', abbr: 'ZHT'),
  SyncDubLanguage(code: 'ko', name: 'Korean', flag: '🇰🇷', abbr: 'KO'),
  SyncDubLanguage(code: 'mn', name: 'Mongolian', flag: '🇲🇳', abbr: 'MN'),

  // Southeast Asian (8)
  SyncDubLanguage(code: 'vi', name: 'Vietnamese', flag: '🇻🇳', abbr: 'VI'),
  SyncDubLanguage(code: 'th', name: 'Thai', flag: '🇹🇭', abbr: 'TH'),
  SyncDubLanguage(code: 'id', name: 'Indonesian', flag: '🇮🇩', abbr: 'ID'),
  SyncDubLanguage(code: 'ms', name: 'Malay', flag: '🇲🇾', abbr: 'MS'),
  SyncDubLanguage(code: 'fil', name: 'Filipino', flag: '🇵🇭', abbr: 'FIL'),
  SyncDubLanguage(code: 'km', name: 'Khmer', flag: '🇰🇭', abbr: 'KM'),
  SyncDubLanguage(code: 'my', name: 'Burmese', flag: '🇲🇲', abbr: 'MY'),
  SyncDubLanguage(code: 'lo', name: 'Lao', flag: '🇱🇦', abbr: 'LO'),

  // European - Romance (7)
  SyncDubLanguage(code: 'es', name: 'Spanish', flag: '🇪🇸', abbr: 'ES'),
  SyncDubLanguage(code: 'fr', name: 'French', flag: '🇫🇷', abbr: 'FR'),
  SyncDubLanguage(code: 'pt', name: 'Portuguese', flag: '🇧🇷', abbr: 'PT'),
  SyncDubLanguage(code: 'it', name: 'Italian', flag: '🇮🇹', abbr: 'IT'),
  SyncDubLanguage(code: 'ro', name: 'Romanian', flag: '🇷🇴', abbr: 'RO'),
  SyncDubLanguage(code: 'ca', name: 'Catalan', flag: '🇪🇸', abbr: 'CA'),
  SyncDubLanguage(code: 'gl', name: 'Galician', flag: '🇪🇸', abbr: 'GL'),

  // European - Germanic (6)
  SyncDubLanguage(code: 'de', name: 'German', flag: '🇩🇪', abbr: 'DE'),
  SyncDubLanguage(code: 'nl', name: 'Dutch', flag: '🇳🇱', abbr: 'NL'),
  SyncDubLanguage(code: 'sv', name: 'Swedish', flag: '🇸🇪', abbr: 'SV'),
  SyncDubLanguage(code: 'no', name: 'Norwegian', flag: '🇳🇴', abbr: 'NO'),
  SyncDubLanguage(code: 'da', name: 'Danish', flag: '🇩🇰', abbr: 'DA'),
  SyncDubLanguage(code: 'is', name: 'Icelandic', flag: '🇮🇸', abbr: 'IS'),

  // Slavic (11)
  SyncDubLanguage(code: 'ru', name: 'Russian', flag: '🇷🇺', abbr: 'RU'),
  SyncDubLanguage(code: 'uk', name: 'Ukrainian', flag: '🇺🇦', abbr: 'UK'),
  SyncDubLanguage(code: 'pl', name: 'Polish', flag: '🇵🇱', abbr: 'PL'),
  SyncDubLanguage(code: 'cs', name: 'Czech', flag: '🇨🇿', abbr: 'CS'),
  SyncDubLanguage(code: 'sk', name: 'Slovak', flag: '🇸🇰', abbr: 'SK'),
  SyncDubLanguage(code: 'hr', name: 'Croatian', flag: '🇭🇷', abbr: 'HR'),
  SyncDubLanguage(code: 'sr', name: 'Serbian', flag: '🇷🇸', abbr: 'SR'),
  SyncDubLanguage(code: 'bg', name: 'Bulgarian', flag: '🇧🇬', abbr: 'BG'),
  SyncDubLanguage(code: 'sl', name: 'Slovenian', flag: '🇸🇮', abbr: 'SL'),
  SyncDubLanguage(code: 'bs', name: 'Bosnian', flag: '🇧🇦', abbr: 'BS'),
  SyncDubLanguage(code: 'mk', name: 'Macedonian', flag: '🇲🇰', abbr: 'MK'),

  // European - Other (8)
  SyncDubLanguage(code: 'fi', name: 'Finnish', flag: '🇫🇮', abbr: 'FI'),
  SyncDubLanguage(code: 'hu', name: 'Hungarian', flag: '🇭🇺', abbr: 'HU'),
  SyncDubLanguage(code: 'el', name: 'Greek', flag: '🇬🇷', abbr: 'EL'),
  SyncDubLanguage(code: 'et', name: 'Estonian', flag: '🇪🇪', abbr: 'ET'),
  SyncDubLanguage(code: 'lv', name: 'Latvian', flag: '🇱🇻', abbr: 'LV'),
  SyncDubLanguage(code: 'lt', name: 'Lithuanian', flag: '🇱🇹', abbr: 'LT'),
  SyncDubLanguage(code: 'sq', name: 'Albanian', flag: '🇦🇱', abbr: 'SQ'),
  SyncDubLanguage(code: 'mt', name: 'Maltese', flag: '🇲🇹', abbr: 'MT'),

  // Celtic (2)
  SyncDubLanguage(code: 'cy', name: 'Welsh', flag: '🏴󠁧󠁢󠁷󠁬󠁳󠁿', abbr: 'CY'),
  SyncDubLanguage(code: 'ga', name: 'Irish', flag: '🇮🇪', abbr: 'GA'),

  // Turkic (4)
  SyncDubLanguage(code: 'tr', name: 'Turkish', flag: '🇹🇷', abbr: 'TR'),
  SyncDubLanguage(code: 'az', name: 'Azerbaijani', flag: '🇦🇿', abbr: 'AZ'),
  SyncDubLanguage(code: 'kk', name: 'Kazakh', flag: '🇰🇿', abbr: 'KK'),
  SyncDubLanguage(code: 'uz', name: 'Uzbek', flag: '🇺🇿', abbr: 'UZ'),

  // Middle East (3)
  SyncDubLanguage(code: 'ar', name: 'Arabic', flag: '🇸🇦', abbr: 'AR'),
  SyncDubLanguage(code: 'he', name: 'Hebrew', flag: '🇮🇱', abbr: 'HE'),
  SyncDubLanguage(code: 'fa', name: 'Persian', flag: '🇮🇷', abbr: 'FA'),

  // Caucasus (2)
  SyncDubLanguage(code: 'ka', name: 'Georgian', flag: '🇬🇪', abbr: 'KA'),
  SyncDubLanguage(code: 'hy', name: 'Armenian', flag: '🇦🇲', abbr: 'HY'),

  // African (8)
  SyncDubLanguage(code: 'sw', name: 'Swahili', flag: '🇰🇪', abbr: 'SW'),
  SyncDubLanguage(code: 'af', name: 'Afrikaans', flag: '🇿🇦', abbr: 'AF'),
  SyncDubLanguage(code: 'am', name: 'Amharic', flag: '🇪🇹', abbr: 'AM'),
  SyncDubLanguage(code: 'yo', name: 'Yoruba', flag: '🇳🇬', abbr: 'YO'),
  SyncDubLanguage(code: 'ig', name: 'Igbo', flag: '🇳🇬', abbr: 'IG'),
  SyncDubLanguage(code: 'ha', name: 'Hausa', flag: '🇳🇬', abbr: 'HA'),
  SyncDubLanguage(code: 'zu', name: 'Zulu', flag: '🇿🇦', abbr: 'ZU'),
  SyncDubLanguage(code: 'xh', name: 'Xhosa', flag: '🇿🇦', abbr: 'XH'),

  // Basque (1)
  SyncDubLanguage(code: 'eu', name: 'Basque', flag: '🇪🇸', abbr: 'EU'),
];
