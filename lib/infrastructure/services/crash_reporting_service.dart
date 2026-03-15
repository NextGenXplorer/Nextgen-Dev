import 'dart:async';
import 'package:flutter/foundation.dart';

/// A service to handle crash reporting and error logging.
/// In a production environment, this would integrate with Firebase Crashlytics or Sentry.
class CrashReportingService {
  Future<void> initialize() async {
    // Catch Flutter framework errors
    FlutterError.onError = (FlutterErrorDetails details) {
      if (kReleaseMode) {
        // Send to Crashlytics
        _recordError(
          details.exception,
          details.stack,
          reason: details.context?.toString(),
        );
      } else {
        // Log to console in debug mode
        FlutterError.presentError(details);
      }
    };

    // Catch asynchronous errors that aren't caught by the Flutter framework
    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      if (kReleaseMode) {
        _recordError(error, stack, reason: 'Uncaught Platform Error');
        return true;
      }
      return false; // Let the default error handler handle it in debug mode
    };
  }

  void _recordError(Object error, StackTrace? stack, {String? reason}) {
    // MOCK: In production, call FirebaseCrashlytics.instance.recordError(error, stack, reason: reason);
    debugPrint('--- CRASH REPORTED ---');
    debugPrint('Reason: \$reason');
    debugPrint('Error: \$error');
    if (stack != null) debugPrint('Stack: \$stack');
    debugPrint('----------------------');
  }

  void log(String message) {
    // MOCK: In production, call FirebaseCrashlytics.instance.log(message);
    debugPrint('[CrashReportingService Log]: \$message');
  }
}
