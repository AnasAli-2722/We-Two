import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/router.dart';
import '../../../core/providers.dart';
import '../../auth/application/auth_state_provider.dart';
import '../../chat/application/duo_state_notifier.dart';
import '../notification_service.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  final service = NotificationService(
    client: ref.watch(supabaseClientProvider),
    localNotifications: FlutterLocalNotificationsPlugin(),
    onNotificationTap: (payload) {
      if (payload == '/chat') {
        ref.read(routerProvider).go('/chat');
      }
    },
  );

  ref.onDispose(() {
    unawaited(service.dispose());
  });

  return service;
});

final inAppNotificationsBootstrapProvider = Provider.autoDispose<void>((ref) {
  final userId = ref.watch(authUserIdProvider);
  final activePartnerId = ref
      .watch(duoStateProvider)
      .valueOrNull
      ?.activePartnerId;

  if (userId == null) {
    return;
  }

  final service = ref.watch(notificationServiceProvider);

  unawaited(() async {
    await service.initializeMessagingCore();
    await service.requestAllPermissions();
    await service.syncTokenForUser(userId);
    await service.startTokenRefreshSync(userId);
    await service.startRealtimeInAppNotifications(
      userId: userId,
      activePartnerId: activePartnerId,
    );
  }());
});
