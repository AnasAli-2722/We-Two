import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/theme/app_theme_controller.dart';
import '../core/theme/app_theme_engine.dart';
import '../features/notifications/application/in_app_notifications_provider.dart';
import 'router.dart';

class WeTwoApp extends ConsumerWidget {
  const WeTwoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(inAppNotificationsBootstrapProvider);
    final router = ref.watch(routerProvider);
    final selectedPreset = ref.watch(appThemePresetProvider);

    return MaterialApp.router(
      title: 'We Two',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(selectedPreset),
      routerConfig: router,
    );
  }
}
