import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../constants/app_colors.dart';

class UrlHelper {
  static Future<void> openUrl(
    BuildContext context,
    String urlString, {
    String? fallbackMessageEn,
    String? fallbackMessageUr,
  }) async {
    final uri = Uri.tryParse(urlString);
    if (uri == null) return;

    try {
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (!context.mounted) return;
        await _copyFallback(context, urlString);
      }
    } catch (_) {
      if (!context.mounted) return;
      await _copyFallback(context, urlString);
    }
  }

  static Future<void> _copyFallback(BuildContext context, String urlString) async {
    await Clipboard.setData(ClipboardData(text: urlString));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.gold,
          content: Text('Link copied to clipboard: $urlString'),
        ),
      );
    }
  }
}
