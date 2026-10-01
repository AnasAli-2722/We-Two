import 'package:flutter/foundation.dart';

class AppErrorReporter {
  static void report(
    Object error, {
    StackTrace? stackTrace,
    required String feature,
    required String operation,
    Map<String, Object?> context = const <String, Object?>{},
  }) {
    final payload = <String, Object?>{
      'feature': feature,
      'operation': operation,
      if (context.isNotEmpty) 'context': context,
      'error': error.toString(),
    };

    debugPrint('APP_ERROR: $payload');
    if (stackTrace != null) {
      debugPrintStack(stackTrace: stackTrace, label: 'APP_ERROR_STACK');
    }
  }
}
