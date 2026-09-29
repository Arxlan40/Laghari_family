import 'package:firebase_crashlytics/firebase_crashlytics.dart';
import 'package:flutter/foundation.dart';

/// Centralized Firebase Crashlytics Service.
///
/// Follows official FlutterFire recommendations:
/// - Captures fatal Flutter framework errors
/// - Captures unhandled asynchronous errors
/// - Manages non-sensitive user & device context
/// - Breadcrumb logging for key application workflows
/// - Respects privacy: strictly prohibits logging passwords, auth tokens,
///   FCM tokens, precise location, or private messages.
class CrashlyticsService {
  CrashlyticsService._();
  static final CrashlyticsService instance = CrashlyticsService._();

  bool _initialized = false;

  /// Initializes Crashlytics error handlers.
  /// Automatically no-ops on Flutter Web where Crashlytics is unsupported.
  Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[Crashlytics] Running on web; Crashlytics is disabled.');
      return;
    }

    try {
      // Pass all uncaught "fatal" errors from the framework to Crashlytics
      FlutterError.onError = FirebaseCrashlytics.instance.recordFlutterFatalError;

      // Pass all uncaught asynchronous errors to Crashlytics
      PlatformDispatcher.instance.onError = (error, stack) {
        FirebaseCrashlytics.instance.recordError(error, stack, fatal: true);
        return true;
      };

      // In production, ensure data collection is active
      await FirebaseCrashlytics.instance.setCrashlyticsCollectionEnabled(true);

      // Set initial platform key
      await FirebaseCrashlytics.instance.setCustomKey('platform', defaultTargetPlatform.name);

      _initialized = true;
      debugPrint('[Crashlytics] Initialized successfully.');
    } catch (e) {
      debugPrint('[Crashlytics] Initialization error: $e');
    }
  }

  /// Sets non-sensitive crash context for the current user.
  /// Never accepts passwords, private tokens, or full addresses.
  Future<void> setUserContext({
    required String? uid,
    required String? role,
    String? appVersion,
  }) async {
    if (kIsWeb || !_initialized) return;

    try {
      if (uid != null && uid.isNotEmpty) {
        await FirebaseCrashlytics.instance.setUserIdentifier(uid);
      } else {
        await FirebaseCrashlytics.instance.setUserIdentifier('anonymous');
      }

      if (role != null) {
        await FirebaseCrashlytics.instance.setCustomKey('user_role', role);
      }

      if (appVersion != null && appVersion.isNotEmpty) {
        await FirebaseCrashlytics.instance.setCustomKey('app_version', appVersion);
      }
    } catch (e) {
      debugPrint('[Crashlytics] setUserContext error: $e');
    }
  }

  /// Sets the currently active screen or feature for debugging context
  Future<void> setCurrentScreen(String screenName) async {
    if (kIsWeb || !_initialized) return;
    try {
      await FirebaseCrashlytics.instance.setCustomKey('current_screen', screenName);
      await FirebaseCrashlytics.instance.log('Screen viewed: $screenName');
    } catch (_) {}
  }

  /// Logs a non-sensitive breadcrumb event.
  /// (e.g. "Family Tree Loading", "Admin Approval", "Password Change", etc.)
  Future<void> log(String message) async {
    debugPrint('[Crashlytics Log] $message');
    if (kIsWeb || !_initialized) return;

    try {
      await FirebaseCrashlytics.instance.log(message);
    } catch (_) {}
  }

  /// Records unexpected non-fatal exceptions without crashing the app.
  Future<void> recordNonFatalError(
    dynamic error,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, dynamic>? customKeys,
  }) async {
    debugPrint('[Crashlytics Non-Fatal] Reason: $reason | Error: $error');
    if (kIsWeb || !_initialized) return;

    try {
      if (customKeys != null) {
        for (final entry in customKeys.entries) {
          if (entry.value is String) {
            await FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value as String);
          } else if (entry.value is int) {
            await FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value as int);
          } else if (entry.value is double) {
            await FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value as double);
          } else if (entry.value is bool) {
            await FirebaseCrashlytics.instance.setCustomKey(entry.key, entry.value as bool);
          }
        }
      }

      await FirebaseCrashlytics.instance.recordError(
        error,
        stackTrace,
        reason: reason,
        fatal: false,
      );
    } catch (_) {}
  }

  /// Development only test crash generator.
  /// Strictly prohibited in release UI.
  void generateTestCrash() {
    if (kIsWeb || !_initialized) return;
    debugPrint('[Crashlytics] Triggering simulated test crash...');
    FirebaseCrashlytics.instance.crash();
  }
}
