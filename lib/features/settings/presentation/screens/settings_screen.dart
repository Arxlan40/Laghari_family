import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../../auth/providers/auth_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

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
      await ref.read(authRepositoryProvider).signOut();
      if (context.mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentLocale = ref.watch(localeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final user = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'ترتیبات' : 'Settings'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            children: [
              // 1. Appearance Section
              _buildSectionHeader(isUrdu ? 'ظاہری شکل' : 'Appearance', isDark),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: SwitchListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  secondary: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.gold.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      themeMode == ThemeMode.dark
                          ? Icons.dark_mode_outlined
                          : Icons.light_mode_outlined,
                      color: AppColors.gold,
                      size: 22,
                    ),
                  ),
                  title: Text(
                    isUrdu ? 'ڈارک موڈ' : 'Dark Mode',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                  ),
                  subtitle: Text(
                    themeMode == ThemeMode.dark
                        ? (isUrdu ? 'فعال ہے' : 'Currently enabled')
                        : (isUrdu ? 'غیر فعال ہے' : 'Currently disabled'),
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                    ),
                  ),
                  value: themeMode == ThemeMode.dark,
                  activeThumbColor: Colors.white,
                  activeTrackColor: AppColors.gold,
                  onChanged: (val) {
                    ref.read(themeModeProvider.notifier).setTheme(
                          val ? ThemeMode.dark : ThemeMode.light,
                        );
                  },
                ),
              ),

              const SizedBox(height: 24),

              // 2. Language Selection Section
              _buildSectionHeader(isUrdu ? 'زبان' : 'Language', isDark),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: RadioGroup<String>(
                  groupValue: currentLocale.languageCode,
                  onChanged: (val) {
                    if (val != null) {
                      ref.read(localeProvider.notifier).setLocale(Locale(val));
                    }
                  },
                  child: Column(
                    children: [
                      RadioListTile<String>(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(18),
                            topRight: Radius.circular(18),
                          ),
                        ),
                        value: 'en',
                        title: const Text(
                          'English',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.language, color: AppColors.emerald, size: 20),
                        ),
                      ),
                      const Divider(height: 1, indent: 64),
                      RadioListTile<String>(
                        shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.only(
                            bottomLeft: Radius.circular(18),
                            bottomRight: Radius.circular(18),
                          ),
                        ),
                        value: 'ur',
                        title: const Text(
                          'اردو',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            fontFamily: 'NotoNastaliqUrdu',
                          ),
                        ),
                        secondary: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(Icons.translate, color: AppColors.emerald, size: 20),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // 3. Account Section
              _buildSectionHeader(isUrdu ? 'اکاؤنٹ' : 'Account', isDark),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: Column(
                  children: [
                    ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          topLeft: Radius.circular(18),
                          topRight: Radius.circular(18),
                        ),
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.person_outline, color: AppColors.gold, size: 20),
                      ),
                      title: Text(
                        isUrdu ? 'میری پروفائل' : 'My Profile',
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                      ),
                      subtitle: Text(
                        user?.email ?? '',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                        ),
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () => context.push('/my-profile'),
                    ),
                    const Divider(height: 1, indent: 64),
                    ListTile(
                      shape: const RoundedRectangleBorder(
                        borderRadius: BorderRadius.only(
                          bottomLeft: Radius.circular(18),
                          bottomRight: Radius.circular(18),
                        ),
                      ),
                      leading: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.danger.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.logout, color: AppColors.danger, size: 20),
                      ),
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
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // 4. About Application Section
              _buildSectionHeader(isUrdu ? 'ایپ کی معلومات' : 'About Application', isDark),
              const SizedBox(height: 8),
              Card(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                child: ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.emerald.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.info_outline, color: AppColors.emerald, size: 20),
                  ),
                  title: Text(
                    isUrdu ? 'خاندانی شجرہ اور ایپ کی معلومات' : 'About Laghari Family',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14.5),
                  ),
                  subtitle: Text(
                    isUrdu
                        ? 'شجرہ کا تعارف، تیار کنندہ اور خصوصی شکریہ'
                        : 'Family tree details, developer info, and special thanks',
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                    ),
                  ),
                  trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                  onTap: () => context.push('/about'),
                ),
              ),

              const SizedBox(height: 32),

              // Branding Footer
              Center(
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => context.push('/about'),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Column(
                      children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 1.5),
                      ),
                      child: ClipOval(
                        child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Laghari Family',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Version 1.0.0 • Family Tree, Connect & Preserve',
                      style: TextStyle(
                        fontSize: 11,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, right: 4),
      child: Text(
        title.toUpperCase(),
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
          color: isDark ? AppColors.gold : AppColors.emerald,
        ),
      ),
    );
  }
}
