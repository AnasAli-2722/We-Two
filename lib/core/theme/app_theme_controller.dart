import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_theme_engine.dart';

const _themePrefsKey = 'we_two.app_theme_preset';

class AppThemePresetNotifier extends StateNotifier<AppThemePreset> {
  AppThemePresetNotifier() : super(AppThemePreset.vibrantMidnight) {
    _loadSavedTheme();
  }

  Future<void> _loadSavedTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_themePrefsKey);
    state = AppThemePresetX.fromStorage(stored);
  }

  Future<void> setTheme(AppThemePreset preset) async {
    if (state == preset) {
      return;
    }
    state = preset;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themePrefsKey, preset.storageKey);
  }
}

final appThemePresetProvider =
    StateNotifierProvider<AppThemePresetNotifier, AppThemePreset>((ref) {
      return AppThemePresetNotifier();
    });
