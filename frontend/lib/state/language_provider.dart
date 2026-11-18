import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/localization.dart';

/// Keeps the user's language choice in memory and on the device.
class LanguageProvider extends ChangeNotifier {
  LanguageProvider(this._preferences) : _language = _initial(_preferences) {
    AppLocalizations.current = localizations;
  }

  static const String storageKey = 'app_language';

  final SharedPreferences _preferences;
  AppLanguage _language;

  static AppLanguage _initial(SharedPreferences preferences) {
    final saved = preferences.getString(storageKey);
    if (saved == 'hi') return AppLanguage.hindi;
    if (saved == 'en') return AppLanguage.english;
    // First launch: follow the device language when it is Hindi.
    return PlatformDispatcher.instance.locale.languageCode == 'hi'
        ? AppLanguage.hindi
        : AppLanguage.english;
  }

  AppLanguage get language => _language;

  bool get isHindi => _language == AppLanguage.hindi;

  Locale get locale => localizations.locale;

  AppLocalizations get localizations => AppLocalizations(_language);

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    AppLocalizations.current = localizations;
    notifyListeners();
    await _preferences.setString(
      storageKey,
      language == AppLanguage.hindi ? 'hi' : 'en',
    );
  }

  Future<void> toggle() => setLanguage(
        isHindi ? AppLanguage.english : AppLanguage.hindi,
      );
}
