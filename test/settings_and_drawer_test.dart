import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/core/localization/app_localizations.dart';
import 'package:laghari_family/core/presentation/widgets/app_drawer.dart';
import 'package:laghari_family/core/theme/theme_provider.dart';
import 'package:laghari_family/features/settings/presentation/screens/settings_screen.dart';

void main() {
  group('SettingsScreen Tests', () {
    testWidgets('Renders settings screen with theme and language options', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Settings'), findsOneWidget);
      expect(find.text('Dark Mode'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(find.text('اردو'), findsOneWidget);
      await tester.scrollUntilVisible(find.text('Laghari Family'), 100);
      expect(find.text('Laghari Family'), findsOneWidget);
    });

    testWidgets('Toggling dark mode switches themeModeProvider', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find switch
      final switchFinder = find.byType(Switch);
      expect(switchFinder, findsOneWidget);

      final initialTheme = container.read(themeModeProvider);
      expect(initialTheme, equals(ThemeMode.dark));

      // Tap switch to toggle to light
      await tester.tap(switchFinder);
      await tester.pumpAndSettle();

      expect(container.read(themeModeProvider), equals(ThemeMode.light));
    });
  });

  group('AppDrawer Tests', () {
    testWidgets('Renders AppDrawer with navigation items and official branding', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: AppDrawer(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(AppDrawer), findsOneWidget);
      expect(find.text('Laghari Family'), findsWidgets);
      expect(find.text('Family Tree'), findsOneWidget);
      expect(find.text('Family Members'), findsOneWidget);
      expect(find.text('Settings'), findsOneWidget);
    });
  });
}
