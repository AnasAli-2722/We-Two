import 'package:flutter/foundation.dart';
import 'dart:async';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/app_error_reporter.dart';

const String _notificationChannelId = 'high_importance_channel';
const String _notificationChannelName = 'High Importance Notifications';
const String _notificationChannelDescription =
    'Partner requests and active chat messages';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  try {
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp();
    }

    debugPrint('Background data message received. id=${message.messageId}');
  } catch (error, stackTrace) {
    debugPrint('FCM background handler error: $error\n$stackTrace');
  }

  debugPrint(
    'FCM background message received: id=${message.messageId}, data=${message.data}',
  );
}

class NotificationService {
  NotificationService({
    required this.client,
    required this.localNotifications,
    required this.onNotificationTap,
  });

  final SupabaseClient client;
  final FlutterLocalNotificationsPlugin localNotifications;
  final void Function(String? payload) onNotificationTap;

  static String? _activeChatId;
  static Future<void> Function()? _clearDisplayedNotifications;
  static final ValueNotifier<int> forceRefreshTrigger = ValueNotifier<int>(0);

  static Future<void> _clearDisplayedNotificationsSafely() async {
    final clear = _clearDisplayedNotifications;
    if (clear == null) {
      return;
    }

    try {
      await clear();
    } catch (error, stackTrace) {
      debugPrint('Failed to clear local notifications: $error\n$stackTrace');
    }
  }

  static void setActiveChatId(String? chatUserId) {
    final normalized = chatUserId?.trim();
    final nextActiveChatId = (normalized == null || normalized.isEmpty)
        ? null
        : normalized;

    if (_activeChatId == nextActiveChatId) {
      return;
    }

    _activeChatId = nextActiveChatId;

    if (_activeChatId != null) {
      unawaited(_clearDisplayedNotificationsSafely());
    }
  }

  static void clearActiveChat() {
    _activeChatId = null;
  }

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    _notificationChannelId,
    _notificationChannelName,
    description: _notificationChannelDescription,
    importance: Importance.max,
  );

  bool _initialized = false;
  String? _activeTokenUserId;
  String? _activeRealtimeUserId;
  String? _activeRealtimePartnerId;
  StreamSubscription<String>? _tokenRefreshSub;
  StreamSubscription<RemoteMessage>? _foregroundMessageSub;
  StreamSubscription<RemoteMessage>? _openedAppMessageSub;
  StreamSubscription<List<Map<String, dynamic>>>? _pendingRequestsSub;

  Future<void> initializeMessagingCore() async {
    if (_initialized) {
      return;
    }

    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }

      FirebaseMessaging.onBackgroundMessage(
        _firebaseMessagingBackgroundHandler,
      );

      const android = AndroidInitializationSettings('@mipmap/ic_launcher');
      const ios = DarwinInitializationSettings(
        requestAlertPermission: true,
        requestBadgePermission: true,
        requestSoundPermission: true,
      );

      await localNotifications.initialize(
        const InitializationSettings(android: android, iOS: ios),
        onDidReceiveNotificationResponse: (response) {
          unawaited(clearAllNotifications());
          onNotificationTap(response.payload);
        },
      );

      _clearDisplayedNotifications = clearAllNotifications;

      final androidPlugin = localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.createNotificationChannel(_channel);

      _foregroundMessageSub = FirebaseMessaging.onMessage.listen((message) {
        final data = Map<String, dynamic>.from(message.data);
        final type = _normalizeType(data['type']);
        final senderId = data['sender_id']?.toString().trim() ?? '';
        final currentActiveId = _activeChatId?.toString().trim() ?? '';
        final title = data['title']?.toString().trim() ?? '';
        final body = data['body']?.toString().trim() ?? '';

        debugPrint(
          '🚨 TRAFFIC CHECK: type=$type sender=$senderId active=$currentActiveId',
        );

        if (type == 'chat_message' && senderId == currentActiveId) {
          forceRefreshTrigger.value = forceRefreshTrigger.value + 1;
          unawaited(clearAllNotifications());
          debugPrint(
            '🔄 FCM KICK: active chat message received, forcing UI stream refresh',
          );
          debugPrint(
            '🔕 TRAFFIC EXIT: active chat already open, skipping local notification',
          );
          return;
        }

        unawaited(
          showForegroundNotification(title: title, body: body, type: type),
        );
      });

      _openedAppMessageSub = FirebaseMessaging.onMessageOpenedApp.listen(
        _handleRemoteNotificationTap,
      );

      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage();
      if (initialMessage != null) {
        _handleRemoteNotificationTap(initialMessage);
      }

      _initialized = true;
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'notifications',
        operation: 'initializeMessagingCore',
      );
    }
  }

  Future<void> requestPermission() async {
    await requestAllPermissions();
  }

  Future<void> clearAllNotifications() async {
    try {
      await localNotifications.cancelAll();
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'notifications',
        operation: 'clearAllNotifications',
      );
    }
  }

  Future<void> requestAllPermissions() async {
    try {
      // Cross-platform FCM-level permission request (iOS/macOS + Android 13+).
      await FirebaseMessaging.instance.requestPermission();

      if (!Platform.isAndroid) {
        return;
      }

      // Android 13+ runtime notifications permission.
      final notificationStatus = await Permission.notification.status;
      if (!notificationStatus.isGranted) {
        final requested = await Permission.notification.request();
        debugPrint('Notification permission status: $requested');
      }

      // Android 12+ exact alarm permission (if app needs precise scheduling).
      final exactAlarmStatus = await Permission.scheduleExactAlarm.status;
      if (!exactAlarmStatus.isGranted) {
        final requested = await Permission.scheduleExactAlarm.request();
        debugPrint('Schedule exact alarm permission status: $requested');
      }

      // Battery optimization check; if enabled, ask user to disable for reliability.
      final batteryOptimizationStatus =
          await Permission.ignoreBatteryOptimizations.status;
      if (!batteryOptimizationStatus.isGranted) {
        debugPrint(
          'Battery optimization is enabled. Suggest user disables it for reliable background notifications.',
        );
        final requested = await Permission.ignoreBatteryOptimizations.request();
        debugPrint(
          'Ignore battery optimizations permission status: $requested',
        );
      }
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'notifications',
        operation: 'requestAllPermissions',
      );
    }
  }

  Future<void> syncTokenForUser(String userId) async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token == null || token.isEmpty) {
        debugPrint('FCM token is null/empty for user: $userId');
        return;
      }

      debugPrint('FCM token for user $userId: $token');

      await client
          .from('profiles')
          .update(<String, dynamic>{'fcm_token': token})
          .eq('id', userId);
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'notifications',
        operation: 'syncTokenForUser',
        context: <String, Object?>{'userId': userId},
      );
    }
  }

  Future<void> startTokenRefreshSync(String userId) async {
    if (_activeTokenUserId == userId && _tokenRefreshSub != null) {
      return;
    }

    await _tokenRefreshSub?.cancel();
    _activeTokenUserId = userId;

    _tokenRefreshSub = FirebaseMessaging.instance.onTokenRefresh.listen((
      token,
    ) {
      debugPrint('FCM token refreshed for user $userId: $token');
      unawaited(_persistToken(userId: userId, token: token));
    });
  }

  Future<void> startRealtimeInAppNotifications({
    required String userId,
    required String? activePartnerId,
  }) async {
    final sameConfig =
        _activeRealtimeUserId == userId &&
        _activeRealtimePartnerId == activePartnerId &&
        _pendingRequestsSub != null;

    if (sameConfig) {
      return;
    }

    await _pendingRequestsSub?.cancel();

    _activeRealtimeUserId = userId;
    _activeRealtimePartnerId = activePartnerId;

    _pendingRequestsSub = client
        .from('partner_requests')
        .stream(primaryKey: ['id'])
        .listen((_) {
          // Intentionally no local popup here.
          // Partner request alerts are delivered by FCM mixed payload to avoid
          // duplicate notifications while app is in foreground/background.
        });
  }

  Future<void> showPartnerRequestNotification({required int count}) async {
    await _show(
      title: 'New partner request',
      body: count > 1
          ? 'You have $count new partner requests.'
          : 'You received a new partner request.',
      payload: '/chat',
    );
  }

  Future<void> showMessageNotification({
    required String senderLabel,
    String? preview,
  }) async {
    await _show(
      title: senderLabel,
      body: (preview == null || preview.isEmpty) ? 'New message' : preview,
      payload: '/chat',
    );
  }

  Future<void> dispose() async {
    _clearDisplayedNotifications = null;
    await _tokenRefreshSub?.cancel();
    await _foregroundMessageSub?.cancel();
    await _openedAppMessageSub?.cancel();
    await _pendingRequestsSub?.cancel();
  }

  Future<void> showForegroundNotification({
    required String title,
    required String body,
    required String type,
  }) async {
    await _show(title: title, body: body, payload: _payloadForType(type));
  }

  void _handleRemoteNotificationTap(RemoteMessage message) {
    final type = _normalizeType(message.data['type']);
    final payload = _payloadForType(type);
    unawaited(clearAllNotifications());
    onNotificationTap(payload);
  }

  String _normalizeType(Object? rawType) {
    return rawType?.toString().trim().toLowerCase() ?? '';
  }

  String _payloadForType(String type) {
    switch (type) {
      case 'chat_message':
      case 'new_request':
      case 'request_accepted':
        return '/chat';
      default:
        return '/chat';
    }
  }

  Future<void> _persistToken({
    required String userId,
    required String token,
  }) async {
    if (token.isEmpty) {
      return;
    }
    try {
      await client
          .from('profiles')
          .update(<String, dynamic>{'fcm_token': token})
          .eq('id', userId);
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'notifications',
        operation: 'persistToken',
        context: <String, Object?>{'userId': userId},
      );
    }
  }

  Future<void> _show({
    required String title,
    required String body,
    String? payload,
  }) async {
    try {
      await localNotifications.show(
        DateTime.now().millisecondsSinceEpoch.remainder(100000),
        title,
        body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            _notificationChannelId,
            _notificationChannelName,
            channelDescription: _notificationChannelDescription,
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            channelShowBadge: true,
          ),
          iOS: DarwinNotificationDetails(
            presentAlert: true,
            presentBanner: true,
            presentSound: true,
          ),
        ),
        payload: payload,
      );
    } catch (error, stackTrace) {
      AppErrorReporter.report(
        error,
        stackTrace: stackTrace,
        feature: 'notifications',
        operation: 'showLocalNotification',
        context: <String, Object?>{'title': title},
      );
    }
  }
}
