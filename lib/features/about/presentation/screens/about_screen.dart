import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/config/app_config.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/presentation/widgets/update_dialog.dart';
import '../../../../core/services/app_version_service.dart';

class AboutScreen extends ConsumerStatefulWidget {
  const AboutScreen({super.key});

  @override
  ConsumerState<AboutScreen> createState() => _AboutScreenState();
}

class _AboutScreenState extends ConsumerState<AboutScreen> {
  bool _isCheckingUpdate = false;

  Future<void> _launchDeveloperWebsite(BuildContext context) async {
    final loc = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final uri = Uri.parse(AppConfig.developerWebsite);

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback: copy to clipboard
        await Clipboard.setData(const ClipboardData(text: AppConfig.developerWebsite));
        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.gold,
            content: Text(
              loc.isUrdu
                  ? 'ویب سائٹ لنک کاپی کر لیا گیا ہے: ${AppConfig.developerWebsite}'
                  : 'Link copied to clipboard: ${AppConfig.developerWebsite}',
            ),
          ),
        );
      }
    } catch (e) {
      await Clipboard.setData(const ClipboardData(text: AppConfig.developerWebsite));
      scaffoldMessenger.showSnackBar(
        SnackBar(
          backgroundColor: AppColors.gold,
          content: Text(
            loc.isUrdu
                ? 'ویب سائٹ لنک کاپی ہو گیا: ${AppConfig.developerWebsite}'
                : 'Link copied to clipboard: ${AppConfig.developerWebsite}',
          ),
        ),
      );
    }
  }

  Future<void> _checkForUpdateManual() async {
    setState(() => _isCheckingUpdate = true);
    final loc = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final versionService = ref.read(appVersionServiceProvider);
      final result = await versionService.checkForUpdate();

      if (mounted) {
        if (result.updateAvailable && result.remoteInfo != null) {
          await UpdateDialog.show(
            context,
            currentVersion: result.currentVersion,
            versionInfo: result.remoteInfo!,
          );
        } else {
          scaffoldMessenger.showSnackBar(
            SnackBar(
              backgroundColor: AppColors.emerald,
              behavior: SnackBarBehavior.floating,
              content: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      loc.isUrdu
                          ? 'آپ کا لگھاری فیملی ایپ پہلے سے تازہ ترین ورژن (v${result.currentVersion}) پر موجود ہے۔'
                          : 'Your application is already on the latest version (v${result.currentVersion}).',
                    ),
                  ),
                ],
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Failed to check for updates: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isCheckingUpdate = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final appVersionAsync = ref.watch(currentAppVersionProvider);
    final localVersion = appVersionAsync.valueOrNull ?? AppConfig.appVersion;

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'متعلقہ معلومات (About)' : 'About Laghari Family'),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
            children: [
              // ==========================================
              // SECTION 1: Laghari Family Tree Header
              // ==========================================
              Center(
                child: Column(
                  children: [
                    Container(
                      width: 90,
                      height: 90,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: AppColors.gold, width: 2.5),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.gold.withValues(alpha: 0.25),
                            blurRadius: 18,
                            spreadRadius: 2,
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
                    const SizedBox(height: 14),
                    Text(
                      isUrdu ? 'لغاری فیملی ٹری' : 'Laghari Family Tree',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                      ),
                      child: Text(
                        'v$localVersion • Official Digital Archive',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.gold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ==========================================
              // SECTION 2: About the Family Tree
              // ==========================================
              Card(
                elevation: isDark ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.account_tree_outlined, color: AppColors.emerald, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isUrdu ? 'خاندانی شجرہ نسب کا تعارف' : 'About the Family Tree',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isUrdu
                            ? 'یہ ایپلیکیشن ضلع جھنگ، پاکستان میں مقیم لغاری خاندان کے باوقار شجرہ نسب پر مشتمل ہے۔ اس کا مقصد موجودہ اور آئندہ آنے والی نسلوں کے لیے خاندانی معلومات، تاریخی رشتے اور آبائی ورثے کو ایک منظم، مستند اور ڈیجیٹل شجرہ نسب کی صورت میں محفوظ اور پیش کرنا ہے۔'
                            : 'This application contains the family tree of the Laghari family residing in District Jhang, Pakistan. It is intended to preserve and present family information in an organized digital family-tree format for current and future generations.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // SECTION 3: Developed By
              // ==========================================
              Card(
                elevation: isDark ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.code_rounded, color: AppColors.gold, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isUrdu ? 'تیار کردہ (Developed by)' : 'Developed by',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: isDark ? AppColors.darkBackground : const Color(0xFFF7FBF9),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: isDark ? AppColors.darkBorder : AppColors.emerald.withValues(alpha: 0.15),
                          ),
                        ),
                        child: Row(
                          children: [
                            CircleAvatar(
                              radius: 26,
                              backgroundColor: AppColors.emerald.withValues(alpha: 0.2),
                              child: const Icon(Icons.person, color: AppColors.emerald, size: 30),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Arsalan Umar Laghari',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    'Software Engineer',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // ==========================================
                      // SECTION 4: Developer Website
                      // ==========================================
                      Text(
                        isUrdu ? 'ڈویلپر کی ویب سائٹ:' : 'Developer Website:',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: AppColors.gold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      InkWell(
                        borderRadius: BorderRadius.circular(14),
                        onTap: () => _launchDeveloperWebsite(context),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: isDark ? 0.12 : 0.08),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.35)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.language, color: AppColors.emerald, size: 22),
                              const SizedBox(width: 12),
                              const Expanded(
                                child: Text(
                                  AppConfig.developerWebsite,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.emerald,
                                    decoration: TextDecoration.underline,
                                    decorationColor: AppColors.emerald,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.open_in_new, size: 18, color: AppColors.emerald),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // ==========================================
              // SECTION 5: Special Thanks
              // ==========================================
              Card(
                elevation: isDark ? 0 : 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: AppColors.gold.withValues(alpha: 0.5),
                    width: 1.3,
                  ),
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    gradient: LinearGradient(
                      colors: isDark
                          ? [
                              const Color(0xFF1B241F),
                              AppColors.darkCard,
                            ]
                          : [
                              const Color(0xFFFBF8EE),
                              Colors.white,
                            ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.gold.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.favorite_rounded, color: AppColors.gold, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              isUrdu ? 'خصوصی شکریہ (Special Thanks)' : 'Special Thanks',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.gold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Text(
                        isUrdu
                            ? 'خاندان کے تمام کوائف اور تاریخی ڈیٹا اکٹھا کرنے اور اسے منظم شجرہ نسب کی صورت میں یکجا کرنے پر ڈاکٹر جعفر خان لغاری کا تہہ دل سے خصوصی شکریہ۔'
                            : 'Special thanks to Dr. Jaffer Khan Laghari for collecting the family data and assembling it into the family-tree form.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.5,
                          fontWeight: FontWeight.w600,
                          color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),

                      // Reverent Dua Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: AppColors.gold.withValues(alpha: isDark ? 0.12 : 0.08),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.gold.withValues(alpha: 0.4)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              isUrdu
                                  ? 'اللہ تعالیٰ انہیں جنت الفردوس میں اعلیٰ مقام عطا فرمائے اور ان کی ان مخلصانہ کوششوں کا بہترین اجر عطا فرمائے۔ آمین۔'
                                  : 'May Allah grant him a high place in Jannat and reward him abundantly for his efforts. Ameen.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 13.5,
                                height: 1.45,
                                fontStyle: FontStyle.italic,
                                fontWeight: FontWeight.bold,
                                color: isDark ? AppColors.goldLight : AppColors.goldDark,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ==========================================
              // Check for Updates Button
              // ==========================================
              Center(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    side: const BorderSide(color: AppColors.emerald, width: 1.2),
                  ),
                  onPressed: _isCheckingUpdate ? null : _checkForUpdateManual,
                  icon: _isCheckingUpdate
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
                        )
                      : const Icon(Icons.system_update_alt_rounded, color: AppColors.emerald, size: 18),
                  label: Text(
                    isUrdu ? 'نئی اپڈیٹ چیک کریں' : 'Check for Updates',
                    style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Footer copyright
              Center(
                child: Text(
                  '© ${DateTime.now().year} Laghari Family. All rights reserved.',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }
}
