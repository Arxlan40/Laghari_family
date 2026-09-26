import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/main.dart';

void main() {
  testWidgets('Laghari Family App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: LaghariFamilyApp(),
      ),
    );

    // Initial frame loads and wait for startup checks timer
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.byType(LaghariFamilyApp), findsOneWidget);
  });
}
