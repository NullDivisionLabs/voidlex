import 'package:flutter/material.dart';

/// User-selected UI language. [system] follows the device primary locale:
/// Russian → Russian UI; any other language → English UI.
enum AppLocalePreference {
  system,
  english,
  russian;

  static AppLocalePreference parse(String? raw) {
    switch (raw?.trim()) {
      case 'en':
        return AppLocalePreference.english;
      case 'ru':
        return AppLocalePreference.russian;
      case 'system':
      default:
        return AppLocalePreference.system;
    }
  }

  String get wireName => switch (this) {
    AppLocalePreference.system => 'system',
    AppLocalePreference.english => 'en',
    AppLocalePreference.russian => 'ru',
  };
}

/// Resolves the [Locale] applied to [MaterialApp] for the given preference.
Locale resolveEffectiveLocale({
  required AppLocalePreference preference,
  required Locale systemLocale,
}) {
  switch (preference) {
    case AppLocalePreference.english:
      return const Locale('en');
    case AppLocalePreference.russian:
      return const Locale('ru');
    case AppLocalePreference.system:
      return systemLocale.languageCode == 'ru'
          ? const Locale('ru')
          : const Locale('en');
  }
}

class AppLocaleScope extends InheritedWidget {
  const AppLocaleScope({
    super.key,
    required this.preference,
    required this.onPreferenceChanged,
    required super.child,
  });

  final AppLocalePreference preference;
  final ValueChanged<AppLocalePreference> onPreferenceChanged;

  static AppLocaleScope? maybeOf(BuildContext context) {
    return context.dependOnInheritedWidgetOfExactType<AppLocaleScope>();
  }

  static AppLocaleScope of(BuildContext context) {
    final scope = maybeOf(context);
    if (scope == null) {
      throw FlutterError('AppLocaleScope was not found in the widget tree.');
    }
    return scope;
  }

  @override
  bool updateShouldNotify(AppLocaleScope oldWidget) {
    return preference != oldWidget.preference ||
        onPreferenceChanged != oldWidget.onPreferenceChanged;
  }
}
