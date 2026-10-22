// Appearance: theme-mode name mapping, controller default
// (System), persistence round-trip, pre-setting installs
// defaulting to System, and the dark-mode calendar tint blend.
import 'dart:convert';

import 'package:faircare/app_controller.dart';
import 'package:faircare/calendar_logic.dart' as cal;
import 'package:faircare/repository.dart';
import 'package:faircare/theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('themeMode name mapping', () {
    test('stored names parse to their modes', () {
      expect(themeModeFromName('system'), ThemeMode.system);
      expect(themeModeFromName('light'), ThemeMode.light);
      expect(themeModeFromName('dark'), ThemeMode.dark);
    });

    test('missing or unrecognized values default to System', () {
      expect(themeModeFromName(null), ThemeMode.system);
      expect(themeModeFromName(''), ThemeMode.system);
      expect(themeModeFromName('midnight'), ThemeMode.system);
    });

    test('names round-trip through the mapping', () {
      for (final mode in ThemeMode.values) {
        expect(themeModeFromName(themeModeName(mode)), mode);
      }
    });
  });

  group('AppController theme mode', () {
    test('defaults to System on a fresh install', () async {
      final controller =
          AppController(LocalFairCareRepository.memory(), MemoryKeyValueStore());
      await controller.init();
      expect(controller.themeMode, ThemeMode.system);
    });

    test('defaults to System when stored prefs predate the setting',
        () async {
      final store = MemoryKeyValueStore();
      // A prefs blob exactly as an older build would have written
      // it: no themeMode key at all.
      await store.write(
        'faircare_user_v1',
        jsonEncode({
          'userName': 'Pratik',
          'joinedBabyIds': <int>[],
          'defaultCaregiverByBaby': <String, int>{},
          'selectedBabyId': null,
          'remindersEnabled': false,
          'quietStartMin': 1320,
          'quietEndMin': 420,
        }),
      );
      final controller =
          AppController(LocalFairCareRepository.memory(), store);
      await controller.init();
      expect(controller.themeMode, ThemeMode.system);
    });

    test('setThemeMode persists across controller instances', () async {
      final store = MemoryKeyValueStore();
      final first =
          AppController(LocalFairCareRepository.memory(), store);
      await first.init();
      await first.setThemeMode(ThemeMode.dark);
      expect(first.themeMode, ThemeMode.dark);

      final second =
          AppController(LocalFairCareRepository.memory(), store);
      await second.init();
      expect(second.themeMode, ThemeMode.dark);

      await second.setThemeMode(ThemeMode.light);
      final third =
          AppController(LocalFairCareRepository.memory(), store);
      await third.init();
      expect(third.themeMode, ThemeMode.light);
    });
  });

  group('score tint in dark mode', () {
    const surface = 0xFF121212; // typical M3 dark surface

    test('light mode returns the pastel unchanged', () {
      for (final score in [95.0, 70.0, 50.0, 10.0]) {
        expect(
          cal.scoreTintArgb(score, surfaceArgb: surface, dark: false),
          cal.scoreTint(score),
        );
      }
    });

    test('dark mode blends toward the surface but keeps the band hue', () {
      final green = cal.scoreTintArgb(95, surfaceArgb: surface, dark: true);
      final red = cal.scoreTintArgb(10, surfaceArgb: surface, dark: true);
      int ch(int argb, int shift) => (argb >> shift) & 0xFF;
      // Opaque, and strictly between surface and the full pastel.
      expect(ch(green, 24), 0xFF);
      for (final shift in [16, 8, 0]) {
        expect(ch(green, shift),
            greaterThan(ch(surface, shift)));
        expect(ch(green, shift),
            lessThanOrEqualTo(ch(cal.scoreTint(95), shift)));
      }
      // The green band stays green-dominant; the red band stays
      // red-dominant — hue survived the blend.
      expect(ch(green, 8), greaterThan(ch(green, 16)));
      expect(ch(red, 16), greaterThan(ch(red, 8)));
      // And the result is dark: every channel well below the
      // pastel's, so near-white text stays readable on it.
      expect(ch(green, 16), lessThan(0x80));
    });
  });

  group('themes', () {
    test('light and dark schemes come from the same brand seed', () {
      final light = fairCareLightTheme();
      final dark = fairCareDarkTheme();
      expect(light.colorScheme.brightness, Brightness.light);
      expect(dark.colorScheme.brightness, Brightness.dark);
      expect(light.useMaterial3, isTrue);
      expect(dark.useMaterial3, isTrue);
      // Same seed lineage: the dark primary is the teal family's
      // dark-scheme counterpart, not an unrelated grey.
      expect(dark.colorScheme.primary, isNot(light.colorScheme.primary));
    });
  });
}
