import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../features/auth/providers/auth_provider.dart';
import '../../constants/app_colors.dart';
import '../../localization/app_localizations.dart';

class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  Future<void> _handleLogout(BuildContext context, WidgetRef ref) async {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.logout, color: AppColors.danger, size: 22),
            ),
            const SizedBox(width: 12),
            Text(
              loc.isUrdu ? 'لاگ آؤٹ' : 'Log Out',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Text(
          loc.isUrdu
              ? 'کیا آپ واقعی لاگ آؤٹ کرنا چاہتے ہیں؟'
              : 'Are you sure you want to log out?',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              loc.translate('cancel'),
              style: TextStyle(
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              loc.translate('logout'),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      Navigator.of(context).pop(); // Close drawer
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final user = ref.watch(currentUserProvider);
    String currentRoute = '';
    try {
      currentRoute = GoRouterState.of(context).matchedLocation;
    } catch (_) {
      currentRoute = '';
    }

    return Drawer(
      backgroundColor: isDark ? AppColors.darkSurface : Colors.white,
      child: Column(
        children: [
          // Drawer Header with Official Logo, User Name & Email
          Container(
            width: double.infinity,
            padding: const EdgeInsets.only(top: 48, bottom: 20, left: 20, right: 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? [const Color(0xFF13221C), AppColors.darkSurface]
                    : [const Color(0xFFE8F5E9), Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              border: Border(
                bottom: BorderSide(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // App Crest / Avatar
                Container(
                  width: 58,
                  height: 58,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.25),
                        blurRadius: 10,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        loc.translate('app_name'),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        user?.name.isNotEmpty == true
                            ? user!.name
                            : (loc.isUrdu ? 'خوش آمدید' : 'Welcome'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (user?.email.isNotEmpty == true)
                        Text(
                          user!.email,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textDarkSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Drawer Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _DrawerItem(
                  icon: Icons.account_tree_outlined,
                  selectedIcon: Icons.account_tree,
                  title: loc.translate('family_tree'),
                  isSelected: currentRoute == '/family-tree',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/family-tree');
                  },
                ),
                _DrawerItem(
                  icon: Icons.people_alt_outlined,
                  selectedIcon: Icons.people_alt,
                  title: loc.translate('family_members'),
                  isSelected: currentRoute == '/family-members',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/family-members');
                  },
                ),
                _DrawerItem(
                  icon: Icons.person_outline,
                  selectedIcon: Icons.person,
                  title: loc.translate('profile'),
                  isSelected: currentRoute == '/my-profile',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/my-profile');
                  },
                ),
                _DrawerItem(
                  icon: Icons.notifications_outlined,
                  selectedIcon: Icons.notifications,
                  title: loc.translate('notifications'),
                  isSelected: currentRoute == '/notifications',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/notifications');
                  },
                ),
                _DrawerItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  title: loc.isUrdu ? 'ترتیبات' : 'Settings',
                  isSelected: currentRoute == '/settings',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/settings');
                  },
                ),
                _DrawerItem(
                  icon: Icons.info_outline,
                  selectedIcon: Icons.info,
                  title: loc.isUrdu ? 'ایپ کے بارے میں' : 'About',
                  isSelected: currentRoute == '/about',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/about');
                  },
                ),
                if (user?.isAdmin == true) ...[
                  const Divider(height: 16),
                  _DrawerItem(
                    icon: Icons.admin_panel_settings_outlined,
                    selectedIcon: Icons.admin_panel_settings,
                    title: loc.translate('admin_panel'),
                    isSelected: currentRoute.startsWith('/admin'),
                    iconColor: AppColors.gold,
                    onTap: () {
                      Navigator.pop(context);
                      context.push('/admin/dashboard');
                    },
                  ),
                ],
              ],
            ),
          ),

          // Bottom Logout Option
          const Divider(height: 1),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                leading: const Icon(Icons.logout, color: AppColors.danger),
                title: Text(
                  loc.translate('logout'),
                  style: const TextStyle(
                    color: AppColors.danger,
                    fontWeight: FontWeight.bold,
                    fontSize: 14.5,
                  ),
                ),
                onTap: () => _handleLogout(context, ref),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DrawerItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final bool isSelected;
  final VoidCallback onTap;
  final Color? iconColor;

  const _DrawerItem({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.isSelected,
    required this.onTap,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final activeColor = iconColor ?? (isDark ? AppColors.goldLight : AppColors.emeraldDark);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: ListTile(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        selected: isSelected,
        selectedTileColor: activeColor.withValues(alpha: 0.12),
        leading: Icon(
          isSelected ? selectedIcon : icon,
          color: isSelected
              ? activeColor
              : (iconColor ?? (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary)),
          size: 22,
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected
                ? activeColor
                : (isDark ? Colors.white : Colors.black87),
          ),
        ),
        onTap: onTap,
      ),
    );
  }
}
