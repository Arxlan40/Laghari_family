import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/core/localization/app_localizations.dart';
import 'package:laghari_family/features/auth/presentation/screens/signup_screen.dart';

void main() {
  testWidgets('SignupScreen displays required popup when submitted empty', (tester) async {
    tester.view.physicalSize = const Size(800, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

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
          home: SignupScreen(),
        ),
      ),
    );

    await tester.pump();

    // Find and tap Create Account button
    final createAccountBtn = find.byType(ElevatedButton);
    expect(createAccountBtn, findsOneWidget);

    await tester.ensureVisible(createAccountBtn);
    await tester.tap(createAccountBtn);
    await tester.pumpAndSettle();

    // Verify popup dialog appears
    final dialog = find.byType(AlertDialog);
    expect(dialog, findsOneWidget);
    expect(find.text('All Information Required'), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.textContaining('Profile Picture')), findsOneWidget);
    expect(find.descendant(of: dialog, matching: find.text('Full Name')), findsOneWidget);

    // Close popup
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
  });
}
