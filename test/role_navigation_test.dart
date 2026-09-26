import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/core/localization/app_localizations.dart';
import 'package:laghari_family/core/router/app_router.dart';
import 'package:laghari_family/features/auth/models/user_model.dart';
import 'package:laghari_family/features/auth/presentation/screens/splash_screen.dart';
import 'package:laghari_family/features/auth/providers/auth_provider.dart';

void main() {
  group('Role-Aware Navigation & Route Guard Tests', () {
    testWidgets('Admin user redirects to /admin/dashboard on login and sees Admin Panel & Family Tree tabs',
        (tester) async {
      final adminUser = UserModel(
        uid: 'admin_test_uid',
        name: 'Test Admin',
        fatherName: 'Father Laghari',
        email: 'admin@laghari.family',
        address: 'Lahore',
        role: UserRole.admin,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            splashCheckDoneProvider.overrideWith((ref) => true),
            currentUserStreamProvider.overrideWith((ref) => Stream.value(adminUser)),
            currentUserProvider.overrideWith((ref) => adminUser),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
                localizationsDelegates: const [AppLocalizations.delegate],
                supportedLocales: AppLocalizations.supportedLocales,
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Verify Admin navigation bar contains Admin Panel and Family Tree destinations
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Admin Panel'), findsWidgets);
      expect(find.text('Family Tree'), findsWidgets);
      // Members and Profile tabs are not in Admin bottom navigation
      expect(find.text('Members'), findsNothing);
    });

    testWidgets('Normal user redirects to /family-tree and sees Tree, Members, Profile tabs without Admin Panel',
        (tester) async {
      final normalUser = UserModel(
        uid: 'user_test_uid',
        name: 'Normal User',
        fatherName: 'Father Laghari',
        email: 'user@laghari.family',
        address: 'Rahim Yar Khan',
        role: UserRole.user,
        status: AccountStatus.active,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            splashCheckDoneProvider.overrideWith((ref) => true),
            currentUserStreamProvider.overrideWith((ref) => Stream.value(normalUser)),
            currentUserProvider.overrideWith((ref) => normalUser),
          ],
          child: Consumer(
            builder: (context, ref, child) {
              final router = ref.watch(appRouterProvider);
              return MaterialApp.router(
                routerConfig: router,
                localizationsDelegates: const [AppLocalizations.delegate],
                supportedLocales: AppLocalizations.supportedLocales,
              );
            },
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Normal user sees Tree, Members, Profile tabs
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(find.text('Tree'), findsOneWidget);
      expect(find.text('Members'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
      // Normal user does NOT see Admin Panel in bottom bar
      expect(find.text('Admin Panel'), findsNothing);
    });
  });
}
