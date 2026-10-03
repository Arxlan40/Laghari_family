import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/config/app_config.dart';
import 'core/config/firebase_options.dart';
import 'core/config/supabase_config.dart';
import 'core/localization/app_localizations.dart';
import 'core/localization/locale_provider.dart';
import 'core/router/app_router.dart';
import 'core/services/crashlytics_service.dart';
import 'core/theme/app_theme.dart';
import 'core/theme/theme_provider.dart';
import 'features/notifications/services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  String? firebaseError;

  // Initialize Firebase Core
  try {
    if (Firebase.apps.isEmpty) {
      if (kIsWeb) {
        FirebaseOptions? opts;
        try {
          opts = DefaultFirebaseOptions.currentPlatform;
        } catch (e) {
          throw Exception('Failed to get DefaultFirebaseOptions: $e');
        }
        await Firebase.initializeApp(options: opts);
      } else {
        try {
          await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform,
          );
        } catch (e) {
          debugPrint('Firebase.initializeApp with options failed on mobile: $e. Falling back to native init...');
          if (Firebase.apps.isEmpty) {
            await Firebase.initializeApp();
          }
        }
      }
    }
    debugPrint('Firebase initialized successfully.');
  } catch (e, stack) {
    debugPrint('Firebase initialization error: $e\n$stack');
    firebaseError = '$e\n\nStackTrace:\n$stack';
  }


  // If Firebase completely failed to load, show a fallback error screen.
  if (firebaseError != null || Firebase.apps.isEmpty) {
    runApp(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.error_outline, color: Colors.red, size: 64),
                  const SizedBox(height: 16),
                  const Text(
                    'Application Error',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Firebase failed to initialize. Please check your internet connection or update the app.\n\nDetails: ${firebaseError ?? "Unknown"}',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: Colors.red),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    return;
  }

  // Initialize Crashlytics
  try {
    await CrashlyticsService.instance.initialize();
  } catch (e, stack) {
    debugPrint('Crashlytics initialization error: $e\n$stack');
  }

  // Initialize Firebase Cloud Messaging
  try {
    await FcmService.initialize();
  } catch (e, stack) {
    debugPrint('FCM initialization error: $e\n$stack');
  }

  // Initialize Supabase Storage client
  try {
    await SupabaseConfig.initialize();
  } catch (e) {
    debugPrint('Supabase initialization note: $e');
  }

  runApp(
    const ProviderScope(
      child: LaghariFamilyApp(),
    ),
  );
}

class LaghariFamilyApp extends ConsumerWidget {
  const LaghariFamilyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: AppConfig.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeMode,
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) {
        final textDir = locale.languageCode == 'ur'
            ? TextDirection.rtl
            : TextDirection.ltr;
        return Directionality(
          textDirection: textDir,
          child: child ?? const SizedBox.shrink(),
        );
      },
      routerConfig: router,
    );
  }
}
