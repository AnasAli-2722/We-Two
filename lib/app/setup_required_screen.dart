import 'package:flutter/material.dart';

import '../core/theme/app_theme_engine.dart';

class SetupRequiredScreen extends StatelessWidget {
  const SetupRequiredScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: background,
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'Supabase is not configured yet.\nProvide SUPABASE_URL and SUPABASE_ANON_KEY to start We Two.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      ),
    );
  }
}
