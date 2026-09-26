import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/features/auth/models/user_model.dart';
import 'package:laghari_family/features/auth/presentation/screens/splash_screen.dart';
import 'package:laghari_family/features/auth/providers/auth_provider.dart';
import 'package:laghari_family/features/family_tree/presentation/screens/family_tree_screen.dart';
import 'package:laghari_family/main.dart';

void main() {
  testWidgets('App renders FamilyTree under MainNavigationShell', (tester) async {
    final fakeUser = UserModel(
      uid: 'test_user',
      email: 'test@example.com',
      name: 'Test User',
      fatherName: 'Father Laghari',
      address: 'Hyderabad, Sindh',
      role: UserRole.user,
      createdAt: DateTime.now(),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          currentUserStreamProvider.overrideWith((ref) => Stream.value(fakeUser)),
          splashCheckDoneProvider.overrideWith((ref) => true),
        ],
        child: const LaghariFamilyApp(),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.pump(const Duration(milliseconds: 100));

    final treeRect = tester.getRect(find.byType(FamilyTreeScreen));
    final navBarRect = tester.getRect(find.byType(NavigationBar));
    print('FamilyTreeScreen rect: $treeRect');
    print('NavigationBar rect: $navBarRect');
  });
}
