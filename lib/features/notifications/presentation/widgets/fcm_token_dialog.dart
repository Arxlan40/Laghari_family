import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';
import '../../services/fcm_service.dart';

class FcmTokenDialog extends StatefulWidget {
  const FcmTokenDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      builder: (ctx) => const FcmTokenDialog(),
    );
  }

  @override
  State<FcmTokenDialog> createState() => _FcmTokenDialogState();
}

class _FcmTokenDialogState extends State<FcmTokenDialog> {
  String? _token = FcmService.currentToken;
  bool _isRefreshing = false;

  Future<void> _refreshToken() async {
    setState(() => _isRefreshing = true);
    final token = await FcmService.getOrRefreshToken();
    if (mounted) {
      setState(() {
        _token = token;
        _isRefreshing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.emerald,
          content: Text('FCM token refreshed and printed to terminal!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.token, color: AppColors.gold),
          SizedBox(width: 8),
          Text('FCM Device Token'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Use this token in Firebase Console -> Cloud Messaging -> "Send test message" to verify push notification delivery directly on this device.',
              style: TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: _isRefreshing
                  ? const Center(child: Padding(
                      padding: EdgeInsets.all(8.0),
                      child: CircularProgressIndicator(color: AppColors.gold),
                    ))
                  : SelectableText(
                      _token != null && _token!.isNotEmpty
                          ? _token!
                          : 'No FCM token registered yet. Make sure Google Play Services is available and device is Android.',
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 11,
                        color: AppColors.goldLight,
                      ),
                    ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton.icon(
          onPressed: _isRefreshing ? null : _refreshToken,
          icon: const Icon(Icons.refresh, size: 16),
          label: const Text('Refresh'),
        ),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.tealAccent,
            side: const BorderSide(color: Colors.tealAccent),
          ),
          onPressed: () async {
            await FcmService.showLocalNotification(
              title: 'Laghari Family Notification Test',
              body: 'Device notifications, sound, and banners are working properly!',
            );
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.emerald,
                  content: Text('Test notification triggered! Check your status bar & notification panel.'),
                ),
              );
            }
          },
          icon: const Icon(Icons.notifications_active, size: 16),
          label: const Text('Test Alert'),
        ),
        if (_token != null && _token!.isNotEmpty)
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: _token!));
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  backgroundColor: AppColors.emerald,
                  content: Text('FCM Token copied to clipboard!'),
                ),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy Token'),
          ),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Close'),
        ),
      ],
    );
  }
}
