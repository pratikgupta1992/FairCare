/// FairCare themes: light + dark, both derived from the app's
/// teal brand seed (the same seed the app has always used), so
/// dark mode is FairCare at night — teal-tinted surfaces and the
/// same palette accents — not a generic grey skin.
///
/// The user's choice (System / Light / Dark) is an M3
/// [ThemeMode], persisted by [AppController] in its prefs JSON
/// under `themeMode` as the names produced by [themeModeName].
library;

import 'package:flutter/material.dart';

/// Brand seed: the teal the app launched with (and the family
/// icon's background family of colors).
const Color kBrandSeed = Colors.teal;

ThemeData fairCareLightTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(seedColor: kBrandSeed),
      useMaterial3: true,
    );

ThemeData fairCareDarkTheme() => ThemeData(
      colorScheme: ColorScheme.fromSeed(
        seedColor: kBrandSeed,
        brightness: Brightness.dark,
      ),
      useMaterial3: true,
    );

/// Prefs value for [mode] ('system' | 'light' | 'dark').
String themeModeName(ThemeMode mode) => switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    };

/// Parses a stored prefs value. Anything unrecognized —
/// including null (existing installs predate the setting) —
/// maps to [ThemeMode.system]: follow the device.
ThemeMode themeModeFromName(String? name) => switch (name) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
