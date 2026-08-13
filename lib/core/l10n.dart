import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Zambian + Zimbabwean language support (starter translations — community can refine).
enum AppLang {
  english('English', 'en'),
  nyanja('Chinyanja', 'ny'),
  bemba('Chibemba', 'bem'),
  tonga('Chitonga', 'toi'),
  ndebele('isiNdebele', 'nd'),
  shona('chiShona', 'sn');

  const AppLang(this.label, this.code);
  final String label;
  final String code;
}

class LanguageController extends Notifier<AppLang> {
  static const _key = 'app_language';

  LanguageController([this._initial = AppLang.english]);
  final AppLang _initial;

  @override
  AppLang build() {
    return _initial;
  }

  Future<void> set(AppLang lang) async {
    state = lang;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, lang.code);
  }

  /// Loads the persisted language once at startup.
  static Future<AppLang> load() async {
    final prefs = await SharedPreferences.getInstance();
    final code = prefs.getString(_key);
    return AppLang.values.firstWhere(
      (l) => l.code == code,
      orElse: () => AppLang.english,
    );
  }
}

final languageProvider =
    NotifierProvider<LanguageController, AppLang>(LanguageController.new);

/// Starter translations for key UI strings. Falls back to English.
const Map<String, Map<String, String>> _strings = {
  'nav.campaigns': {
    'en': 'Campaigns',
    'ny': 'Makampeni',
    'bem': 'Imikampeni',
    'toi': 'Milimo',
    'nd': 'Imikhankaso',
    'sn': 'Mishandirapamwe',
  },
  'nav.events': {
    'en': 'Events',
    'ny': 'Zochitika',
    'bem': 'Ifibulo',
    'toi': 'Mabaala',
    'nd': 'Imicimbi',
    'sn': 'Zviitiko',
  },
  'nav.host': {
    'en': 'Host',
    'ny': 'Mwinimwini',
    'bem': 'Nkanka',
    'toi': 'Nkamuzya',
    'nd': 'Umqambi',
    'sn': 'Muridzi',
  },
  'nav.settings': {
    'en': 'Settings',
    'ny': 'Makonzedwe',
    'bem': 'Ubupapilo',
    'toi': 'Malenkuno',
    'nd': 'Izilungiselelo',
    'sn': 'Marongero',
  },
  'common.search': {
    'en': 'Search',
    'ny': 'Fufuzani',
    'bem': 'Fwaya',
    'toi': 'Langula',
    'nd': 'Funa',
    'sn': 'Tsvaga',
  },
  'common.notifications': {
    'en': 'Notifications',
    'ny': 'Zidziwitso',
    'bem': 'Imyailo',
    'toi': 'Kulaila',
    'nd': 'Izaziso',
    'sn': 'Zviziviso',
  },
  'common.appTitle': {
    'en': 'Kingdom Sponsor',
    'ny': 'Kingdom Sponsor',
    'bem': 'Kingdom Sponsor',
    'toi': 'Kingdom Sponsor',
    'nd': 'Kingdom Sponsor',
    'sn': 'Kingdom Sponsor',
  },
  'common.events': {
    'en': 'Events',
    'ny': 'Zochitika',
    'bem': 'Ifibulo',
    'toi': 'Mabaala',
    'nd': 'Imicimbi',
    'sn': 'Zviitiko',
  },
};

/// Looks up a string for the active language (English fallback).
String tr(AppLang lang, String key) {
  final entry = _strings[key];
  if (entry == null) return key;
  return entry[lang.code] ?? entry['en'] ?? key;
}
