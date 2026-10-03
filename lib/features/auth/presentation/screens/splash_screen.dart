import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/presentation/widgets/update_dialog.dart';
import '../../../../core/services/app_version_service.dart';
import '../../../../core/services/device_info_service.dart';
import '../../providers/auth_provider.dart';

final splashCheckDoneProvider = StateProvider<bool>((ref) => false);

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  String _statusText = 'Checking authentication...';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _runStartupChecks();
    });
  }

  Future<void> _runStartupChecks() async {
    final loc = AppLocalizations.of(context);

    // 1. Wait for Firebase Authentication state to fully resolve first
    try {
      if (mounted) {
        setState(() {
          _statusText = loc.isUrdu ? 'صارف کی تصدیق جاری ہے...' : 'Verifying account...';
        });
      }
      await ref.read(authRepositoryProvider).getCurrentUser();
    } catch (e) {
      debugPrint('Auth resolution check note: $e');
    }

    // On Web: Mark splash done immediately once auth state is resolved.
    // Declarative GoRouter redirect handles seamless, flash-free routing.
    if (kIsWeb) {
      if (mounted) {
        ref.read(splashCheckDoneProvider.notifier).state = true;
      }
      return;
    }

    final isAndroid = !kIsWeb && Platform.isAndroid;

    if (isAndroid) {
      if (mounted) {
        setState(() {
          _statusText = loc.isUrdu ? 'تصدیق جاری ہے...' : 'Checking application version...';
        });
      }

      try {
        final versionService = ref.read(appVersionServiceProvider);
        final result = await versionService.checkForUpdate().timeout(const Duration(seconds: 4));

        if (mounted && result.updateAvailable && result.remoteInfo != null) {
          if (!AppVersionService.hasSkippedThisSession) {
            await UpdateDialog.show(
              context,
              currentVersion: result.currentVersion,
              versionInfo: result.remoteInfo!,
            );

            // If force update is enabled, user must update and cannot proceed
            if (result.remoteInfo!.forceUpdate) {
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Startup check error: $e');
      }
    }

    // 2. Fetch device details & location on splash screen
    try {
      if (mounted) {
        setState(() {
          _statusText = loc.isUrdu ? 'مقام اور ڈیوائس کی تصدیق...' : 'Fetching device & location...';
        });
      }
      final devInfo = await DeviceInfoService.fetchDeviceDetailsAndLocationOnSplash();
      if (mounted) {
        final currentUser = ref.read(currentUserProvider);
        if (currentUser != null && currentUser.uid.isNotEmpty) {
          await ref.read(authRepositoryProvider).updateUserDeviceInfo(currentUser.uid, devInfo);
        }
      }
    } catch (e) {
      debugPrint('Splash device/location check: $e');
    }

    if (mounted) {
      ref.read(splashCheckDoneProvider.notifier).state = true;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Official Laghari Family Logo with subtle elevation & golden border
              Container(
                width: 140,
                height: 140,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.gold.withValues(alpha: 0.25),
                      blurRadius: 24,
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
              const SizedBox(height: 28),

              // Application Name
              Text(
                'Laghari Family',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                ),
              ),
              const SizedBox(height: 6),

              // Subtitle / Tagline
              Text(
                loc.isUrdu
                    ? 'شجرہ نسب • رابطہ • نسلی ورثہ'
                    : 'Family Tree • Connect • Preserve',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
              ),

              const Spacer(flex: 2),

              // Polished Loading Spinner
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(
                  strokeWidth: 2.5,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    isDark ? AppColors.gold : AppColors.emerald,
                  ),
                ),
              ),
              const SizedBox(height: 14),

              Text(
                _statusText,
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
              ),

              const Spacer(flex: 1),
            ],
          ),
        ),
      ),
    );
  }
}
