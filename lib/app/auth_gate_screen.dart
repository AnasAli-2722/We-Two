import 'package:flutter/material.dart';

import '../core/theme/app_theme_engine.dart';

class AuthGateScreen extends StatelessWidget {
  const AuthGateScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appColors = theme.extension<WeTwoThemeColors>();
    final background = appColors?.background ?? theme.scaffoldBackgroundColor;
    return Scaffold(
      backgroundColor: background,
      body: const SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 14),
              Text(
                'Checking account status...',
                style: TextStyle(color: Colors.white70),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
