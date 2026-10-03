import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../notifications/repositories/notification_repository.dart';
import '../../models/hamdard_audit_log.dart';
import '../../providers/hamdard_providers.dart';

class HamdardNotificationDialog extends ConsumerStatefulWidget {
  const HamdardNotificationDialog({super.key});

  @override
  ConsumerState<HamdardNotificationDialog> createState() => _HamdardNotificationDialogState();
}

class _HamdardNotificationDialogState extends ConsumerState<HamdardNotificationDialog> {
  final _titleCtrl = TextEditingController(text: 'Hamdard Laghari Update');
  final _bodyCtrl = TextEditingController(text: 'The latest Hamdard Laghari financial report is now available.');
  bool _isSending = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate(String title, String body) {
    setState(() {
      _titleCtrl.text = title;
      _bodyCtrl.text = body;
    });
  }

  Future<void> _sendNotification() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both title and message.')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() => _isSending = true);

    try {
      final notifRepo = ref.read(notificationRepositoryProvider);
      await notifRepo.sendBroadcastNotification(
        title: title,
        body: body,
        senderName: currentUser.name,
        senderUid: currentUser.uid,
      );

      // Record in Hamdard audit history
      await ref.read(hamdardRepositoryProvider).recordAuditLog(
        HamdardAuditLog(
          id: const Uuid().v4(),
          action: 'sent_hamdard_notification',
          recordType: 'notification',
          recordId: 'broadcast_${DateTime.now().millisecondsSinceEpoch}',
          performedBy: currentUser.uid,
          performedByName: currentUser.name,
          timestamp: DateTime.now(),
          newData: {'title': title, 'body': body},
          details: 'Broadcast notification sent: "$title"',
        ),
      );

      if (!mounted) return;
      setState(() => _isSending = false);
      Navigator.pop(context);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.emerald,
          content: Text('Notification broadcast successfully to all members!'),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSending = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Error sending notification: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          const Icon(Icons.campaign, color: AppColors.emerald, size: 24),
          const SizedBox(width: 10),
          Text(isUrdu ? 'ہمدرد اطلاع بھیجیں' : 'Send Hamdard Notification'),
        ],
      ),
      content: SingleChildScrollView(
        child: SizedBox(
          width: double.maxFinite,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUrdu
                    ? 'تمام رجسٹرڈ اراکین کو اطلاع نشر کی جائے گی۔'
                    : 'Broadcast update to all registered Laghari family app users.',
                style: TextStyle(
                  fontSize: 12,
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
              ),
              const SizedBox(height: 12),

              // Quick templates
              Text(isUrdu ? 'تیار شدہ پیغامات:' : 'Quick Templates:',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    label: const Text('Monthly Report Ready', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyTemplate(
                      'Hamdard Monthly Report',
                      'The monthly collection & spending report is now available in Hamdard section.',
                    ),
                  ),
                  ActionChip(
                    label: const Text('Donation Drive', style: TextStyle(fontSize: 11)),
                    onPressed: () => _applyTemplate(
                      'Hamdard Monthly Contribution',
                      'A friendly reminder for monthly contributions to support our community programs.',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              TextField(
                controller: _titleCtrl,
                decoration: InputDecoration(
                  labelText: isUrdu ? 'عنوان' : 'Notification Title',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bodyCtrl,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: isUrdu ? 'پیغام' : 'Message Body',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(loc.translate('cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
          ),
          onPressed: _isSending ? null : _sendNotification,
          child: _isSending
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : Text(isUrdu ? 'بھیجیں' : 'Broadcast Now'),
        ),
      ],
    );
  }
}
