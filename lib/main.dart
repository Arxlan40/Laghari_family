import 'package:firebase_core/firebase_core.dart';
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

  // Initialize Firebase Core
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    debugPrint('Firebase initialized successfully.');
  } catch (e, stack) {
    debugPrint('Firebase initialization error: $e\n$stack');
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
