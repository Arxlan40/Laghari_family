import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/core/localization/app_localizations.dart';
import 'package:laghari_family/features/family_tree/presentation/screens/family_tree_screen.dart';

void main() {
  testWidgets('FamilyTreeScreen renders without crashing', (tester) async {
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
          home: FamilyTreeScreen(),
        ),
      ),
    );

    await tester.pump();
    expect(find.byType(FamilyTreeScreen), findsOneWidget);
  });
}
