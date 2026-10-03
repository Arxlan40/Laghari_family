import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../localization/app_localizations.dart';
import '../../network/network_service.dart';

class MainNavigationShell extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainNavigationShell({
    super.key,
    required this.navigationShell,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final networkStatusAsync = ref.watch(networkStatusStreamProvider);
    final isOffline = networkStatusAsync.valueOrNull == NetworkStatus.offline;
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser?.isAdmin ?? false;

    // Role-aware navigation destinations & selected index mapping
    final int selectedIndex;
    final List<NavigationDestination> destinations;

    if (isAdmin) {
      // Admin / Super Admin navigation: [ Admin Panel ] [ Family Tree ]
      // Branch 0 = /admin/dashboard, Branch 1 = /family-tree
      selectedIndex = navigationShell.currentIndex == 0 ? 0 : 1;
      destinations = [
        NavigationDestination(
          icon: const Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: const Icon(Icons.admin_panel_settings, color: AppColors.gold),
          label: loc.translate('admin_panel'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.account_tree_outlined),
          selectedIcon: const Icon(Icons.account_tree, color: AppColors.emerald),
          label: loc.translate('family_tree'),
        ),
      ];
    } else {
      // Normal User navigation: [ Family Tree ] [ Members ] [ Profile ]
      // Branch 1 = /family-tree, Branch 2 = /family-members, Branch 3 = /my-profile
      if (navigationShell.currentIndex == 1) {
        selectedIndex = 0;
      } else if (navigationShell.currentIndex == 2) {
        selectedIndex = 1;
      } else if (navigationShell.currentIndex == 3) {
        selectedIndex = 2;
      } else {
        selectedIndex = 0;
      }
      destinations = [
        NavigationDestination(
          icon: const Icon(Icons.account_tree_outlined),
          selectedIcon: const Icon(Icons.account_tree, color: AppColors.gold),
          label: loc.translate('tree'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.people_alt_outlined),
          selectedIcon: const Icon(Icons.people_alt, color: AppColors.emerald),
          label: loc.translate('members'),
        ),
        NavigationDestination(
          icon: const Icon(Icons.person_outline),
          selectedIcon: const Icon(Icons.person, color: AppColors.gold),
          label: loc.translate('profile'),
        ),
      ];
    }

    void onDestinationSelected(int index) {
      if (isAdmin) {
        final targetBranch = index == 0 ? 0 : 1;
        navigationShell.goBranch(
          targetBranch,
          initialLocation: targetBranch == navigationShell.currentIndex,
        );
      } else {
        final targetBranch = index + 1;
        navigationShell.goBranch(
          targetBranch,
          initialLocation: targetBranch == navigationShell.currentIndex,
        );
      }
    }

    return PopScope(
      canPop: selectedIndex == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        onDestinationSelected(0);
      },
      child: Scaffold(
        body: Stack(
        children: [
          // Active branch screen fills the entire available body area
          Positioned.fill(child: navigationShell),

          // Offline network banner
          if (isOffline)
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 16),
                color: AppColors.warning,
                child: SafeArea(
                  bottom: false,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.wifi_off, size: 16, color: Colors.black87),
                      const SizedBox(width: 8),
                      Text(
                        loc.translate('no_internet'),
                        style: const TextStyle(
                          color: Colors.black87,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: LayoutBuilder(
        builder: (context, constraints) {
          final isTablet = constraints.maxWidth >= 700;

          Widget navBar = NavigationBar(
            selectedIndex: selectedIndex,
            onDestinationSelected: onDestinationSelected,
            backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
            indicatorColor: isDark
                ? AppColors.gold.withValues(alpha: 0.25)
                : AppColors.emerald.withValues(alpha: 0.18),
            elevation: 8,
            shadowColor: Colors.black26,
            destinations: destinations,
          );

          if (isTablet) {
            return SafeArea(
              top: false,
              child: Align(
                alignment: Alignment.bottomCenter,
                heightFactor: 1.0,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 600),
                  child: navBar,
                ),
              ),
            );
          }

          return navBar;
        },
      ),
    ));
  }
}
