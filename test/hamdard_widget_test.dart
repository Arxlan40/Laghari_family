import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/core/localization/app_localizations.dart';
import 'package:laghari_family/features/auth/models/user_model.dart';
import 'package:laghari_family/features/auth/providers/auth_provider.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_donation.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_payment_method.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_person.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_spending.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_spending_category.dart';
import 'package:laghari_family/features/hamdard/presentation/screens/hamdard_dashboard_screen.dart';
import 'package:laghari_family/features/hamdard/presentation/screens/hamdard_receipt_screen.dart';
import 'package:laghari_family/features/hamdard/presentation/widgets/hamdard_spending_pie_chart.dart';
import 'package:laghari_family/features/hamdard/providers/hamdard_providers.dart';
import 'package:laghari_family/features/hamdard/repositories/hamdard_repository.dart';

void main() {
  group('Hamdard Widget Tests', () {
    testWidgets('HamdardReceiptScreen renders complete donation receipt details', (tester) async {
      final donation = HamdardDonation(
        id: 'don-rec-1',
        personId: 'p-1',
        personNameSnapshot: 'Ghulam Qadir',
        fatherNameSnapshot: 'Nabi Bux',
        phoneNumberSnapshot: '03001234567',
        amount: 7500,
        paymentMethod: HamdardPaymentMethod.jazzCash,
        date: DateTime(2026, 10, 3),
        description: 'Monthly contribution',
        note: 'Audited receipt',
        createdAt: DateTime(2026, 10, 3),
        createdBy: 'admin-1',
      );

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: HamdardReceiptScreen(donation: donation),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Donation Receipt'), findsWidgets);
      expect(find.text('Ghulam Qadir'), findsOneWidget);
      expect(find.text('Nabi Bux'), findsOneWidget);
      expect(find.text('03001234567'), findsOneWidget);
      expect(find.text('Rs. 7,500'), findsOneWidget);
      expect(find.text('JazzCash'), findsOneWidget);
      expect(find.text('Monthly contribution'), findsOneWidget);
    });

    testWidgets('HamdardSpendingPieChart renders slices and legend items', (tester) async {
      final categoryTotals = {
        HamdardSpendingCategory.medical: 50000,
        HamdardSpendingCategory.education: 30000,
        HamdardSpendingCategory.emergency: 20000,
      };

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HamdardSpendingPieChart(
              categorySpending: categoryTotals,
              totalSpending: 100000,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.byType(HamdardSpendingPieChart), findsOneWidget);
      expect(find.byType(CustomPaint), findsWidgets);
      expect(find.textContaining('Medical'), findsWidgets);
      expect(find.textContaining('Education'), findsWidgets);
      expect(find.textContaining('Emergency'), findsWidgets);
    });

    testWidgets('HamdardDashboardScreen displays balance banner and KPI cards', (tester) async {
      final fakeRepo = HamdardRepository();

      // Seed repo with data
      final p1 = HamdardPerson(
        id: 'p-1',
        name: 'Ali Nawaz',
        fatherName: 'Allah Dino',
        phoneNumber: '03009998877',
        createdAt: DateTime.now(),
      );
      await fakeRepo.savePerson(p1, performedBy: 'admin-1', performedByName: 'Admin');

      await fakeRepo.addDonation(
        HamdardDonation(
          id: 'don-dash-1',
          personId: p1.id,
          personNameSnapshot: p1.name,
          fatherNameSnapshot: p1.fatherName,
          phoneNumberSnapshot: p1.phoneNumber,
          amount: 25000,
          paymentMethod: HamdardPaymentMethod.cash,
          date: DateTime.now(),
          createdAt: DateTime.now(),
          createdBy: 'admin-1',
        ),
        performedBy: 'admin-1',
        performedByName: 'Admin',
      );

      await fakeRepo.addSpending(
        HamdardSpending(
          id: 'sp-dash-1',
          recipientName: 'Wali Khan',
          recipientFatherName: 'Jan Khan',
          recipientPhoneNumber: '03112223344',
          amount: 10000,
          date: DateTime.now(),
          paymentMethod: HamdardPaymentMethod.easypaisa,
          category: HamdardSpendingCategory.medical,
          description: 'Medicine aid',
          createdAt: DateTime.now(),
          createdBy: 'admin-1',
        ),
        performedBy: 'admin-1',
        performedByName: 'Admin',
      );

      const superAdminUser = UserModel(
        uid: 'super-admin-uid',
        name: 'Super Admin',
        fatherName: 'Admin Father',
        email: 'super@laghari.test',
        address: 'Sindh, Pakistan',
        role: UserRole.superAdmin,
        isHamdardAdmin: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            hamdardRepositoryProvider.overrideWithValue(fakeRepo),
            currentUserProvider.overrideWith((ref) => superAdminUser),
          ],
          child: const MaterialApp(
            localizationsDelegates: [
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: HamdardDashboardScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Check title and metrics
      expect(find.text('Hamdard Laghari'), findsOneWidget);
      expect(find.text('CURRENT COMBINED BALANCE'), findsOneWidget);
      expect(find.text('This Month Collection'), findsOneWidget);
      expect(find.text('This Month Spending'), findsOneWidget);
      // Net is 25000 - 10000 = 15000
      expect(find.text('Rs. 15,000'), findsOneWidget);
      expect(find.text('Rs. 25,000'), findsWidgets);
      expect(find.text('Rs. 10,000'), findsWidgets);
    });
  });
}
