import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../constants/app_colors.dart';
import '../../localization/app_localizations.dart';
import '../../services/app_version_service.dart';

class UpdateDialog extends ConsumerStatefulWidget {
  final String currentVersion;
  final RemoteVersionInfo versionInfo;
  final VoidCallback? onSkipped;

  const UpdateDialog({
    super.key,
    required this.currentVersion,
    required this.versionInfo,
    this.onSkipped,
  });

  /// Static helper to display the update dialog conveniently.
  static Future<bool?> show(
    BuildContext context, {
    required String currentVersion,
    required RemoteVersionInfo versionInfo,
    VoidCallback? onSkipped,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: !versionInfo.forceUpdate,
      builder: (ctx) => PopScope(
        canPop: !versionInfo.forceUpdate,
        child: UpdateDialog(
          currentVersion: currentVersion,
          versionInfo: versionInfo,
          onSkipped: onSkipped,
        ),
      ),
    );
  }

  @override
  ConsumerState<UpdateDialog> createState() => _UpdateDialogState();
}

class _UpdateDialogState extends ConsumerState<UpdateDialog> {
  bool _isDownloading = false;
  double _downloadProgress = 0.0;
  String? _errorMessage;

  Future<void> _startUpdate() async {
    setState(() {
      _isDownloading = true;
      _errorMessage = null;
      _downloadProgress = 0.0;
    });

    final versionService = ref.read(appVersionServiceProvider);

    try {
      await for (final progress in versionService.downloadAndInstall(
        downloadUrl: widget.versionInfo.downloadUrl,
      )) {
        if (!mounted) return;
        setState(() {
          _downloadProgress = progress.progress;
          if (progress.status == DownloadStatus.error) {
            _isDownloading = false;
            _errorMessage = progress.errorMessage ?? 'Download failed. Please try again.';
          } else if (progress.status == DownloadStatus.completed) {
            _isDownloading = false;
            if (!widget.versionInfo.forceUpdate) {
              Navigator.of(context).pop(true);
            }
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isDownloading = false;
          _errorMessage = 'Error downloading update: $e';
        });
      }
    }
  }

  void _handleSkip() {
    AppVersionService.hasSkippedThisSession = true;
    widget.onSkipped?.call();
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final releaseNotes = widget.versionInfo.releaseNotes ??
        (isUrdu
            ? 'نئی خصوصیات، شجرہ نسب میں بہتری اور کارکردگی میں اضافہ شامل کیا گیا ہے۔'
            : 'New features, family tree performance improvements, and bug fixes.');

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // App Icon with glowing circular ring
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.gold, width: 2.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.25),
                        blurRadius: 16,
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
              ),
              const SizedBox(height: 16),

              // Title
              Text(
                isUrdu ? 'نیا اپڈیٹ دستیاب ہے' : 'New Update Available',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                isUrdu
                    ? 'ایک نیا اور بہتر ورژن تیار ہے۔ براہ کرم اپڈیٹ کریں۔'
                    : 'A newer and improved version of Laghari Family is available.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
              ),
              const SizedBox(height: 18),

              // Version comparison cards
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkBackground : const Color(0xFFF3F7F5),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text(
                          isUrdu ? 'موجودہ ورژن' : 'Current Version',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textDarkSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Text(
                            'v${widget.currentVersion}',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                    const Icon(Icons.arrow_forward_rounded, color: AppColors.gold, size: 20),
                    Column(
                      children: [
                        Text(
                          isUrdu ? 'نیا ورژن' : 'New Version',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textDarkSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.emerald, width: 0.8),
                          ),
                          child: Text(
                            'v${widget.versionInfo.latestVersion}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: AppColors.emerald,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Short update message / Release Notes
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : Colors.grey.shade200,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.bolt, color: AppColors.gold, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          isUrdu ? 'اہم تبدیلیاں:' : "What's New:",
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                            color: AppColors.gold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      releaseNotes,
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.35,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ),

              // Progress bar during download
              if (_isDownloading) ...[
                const SizedBox(height: 18),
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: _downloadProgress > 0 ? _downloadProgress : null,
                        minHeight: 8,
                        backgroundColor: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(AppColors.emerald),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isUrdu ? 'ڈاؤنلوڈ جاری ہے...' : 'Downloading update...',
                          style: const TextStyle(fontSize: 11.5),
                        ),
                        Text(
                          '${(_downloadProgress * 100).toInt()}%',
                          style: const TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.bold,
                            color: AppColors.emerald,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],

              // Error banner if any
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(fontSize: 11.5, color: AppColors.danger),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Buttons: Update Now & Skip
              Row(
                children: [
                  // Skip button (Hidden if forceUpdate is true)
                  if (!widget.versionInfo.forceUpdate) ...[
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          side: BorderSide(
                            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                          ),
                        ),
                        onPressed: _isDownloading ? null : _handleSkip,
                        child: Text(
                          isUrdu ? 'بعد میں' : 'Skip',
                          style: TextStyle(
                            fontSize: 14,
                            color: isDark
                                ? AppColors.textLightSecondary
                                : AppColors.textDarkSecondary,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                  ],

                  // Update Now button
                  Expanded(
                    flex: widget.versionInfo.forceUpdate ? 1 : 1,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                      onPressed: _isDownloading ? null : _startUpdate,
                      icon: _isDownloading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.download, size: 18),
                      label: Text(
                        isUrdu ? 'ابھی اپڈیٹ کریں' : 'Update Now',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
