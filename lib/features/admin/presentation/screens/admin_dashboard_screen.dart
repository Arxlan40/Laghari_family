import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../edit_requests/repositories/edit_request_repository.dart';
import '../../../family_tree/providers/family_tree_providers.dart';
import '../../../notifications/presentation/widgets/notification_badge_icon.dart';
import '../../../notifications/repositories/notification_repository.dart';

class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final currentUser = ref.watch(currentUserProvider);
    final membersMap = ref.watch(familyMembersMapProvider);
    final pendingRequestsAsync = ref.watch(pendingRequestsStreamProvider);
    final pendingCount = pendingRequestsAsync.valueOrNull?.length ?? 0;

    final isSuperAdmin = currentUser?.isSuperAdmin ?? false;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('admin_panel')),
        actions: [
          const NotificationBadgeIcon(),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: loc.translate('logout'),
            onPressed: () async {
              await ref.read(authRepositoryProvider).signOut();
              if (context.mounted) context.go('/login');
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Admin Profile Header Card
          Card(
            color: AppColors.darkSurface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: isSuperAdmin ? AppColors.gold : AppColors.emerald,
                    child: Icon(
                      isSuperAdmin ? Icons.shield : Icons.security,
                      size: 32,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentUser?.name ?? 'Administrator',
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          currentUser?.email ?? '',
                          style: const TextStyle(fontSize: 13, color: AppColors.textLightSecondary),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: isSuperAdmin
                                ? AppColors.gold.withValues(alpha: 0.2)
                                : AppColors.emerald.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isUrdu ? (currentUser?.role.labelUr ?? '') : (currentUser?.role.labelEn ?? ''),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: isSuperAdmin ? AppColors.goldLight : AppColors.emeraldLight,
                            ),
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

          // Overview Metrics Row
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: isUrdu ? 'کل اراکین' : 'Total Members',
                  value: '${membersMap.length}',
                  icon: Icons.people,
                  color: AppColors.emerald,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildMetricTile(
                  title: isUrdu ? 'زیر التواء درخواستیں' : 'Pending Requests',
                  value: '$pendingCount',
                  icon: Icons.pending_actions,
                  color: pendingCount > 0 ? AppColors.gold : AppColors.textLightSecondary,
                  badge: pendingCount > 0 ? (isUrdu ? 'کارروائی درکار' : 'Action Needed') : null,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // ---------------------------------------------------------
          // Section: General Admin Actions (Admin & Super Admin)
          // ---------------------------------------------------------
          Text(
            isUrdu ? 'انتظامی اختیارات' : 'Administrative Actions',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gold),
          ),
          const SizedBox(height: 12),

          // 1. Pending Requests
          _buildActionCard(
            context: context,
            title: loc.translate('pending_requests'),
            subtitle: isUrdu
                ? '$pendingCount درخواستیں جائزے کی منتظر ہیں'
                : '$pendingCount submissions awaiting review',
            icon: Icons.rate_review,
            iconColor: AppColors.gold,
            badgeCount: pendingCount,
            onTap: () => context.push('/admin/requests'),
          ),

          // 2. Direct Family Tree Management
          _buildActionCard(
            context: context,
            title: loc.translate('direct_management'),
            subtitle: loc.translate('direct_management_desc'),
            icon: Icons.account_tree,
            iconColor: AppColors.emerald,
            onTap: () => context.push('/admin/tree'),
          ),

          // 3. Notifications Screen
          _buildActionCard(
            context: context,
            title: loc.translate('notifications'),
            subtitle: isUrdu ? 'تمام نوٹیفکیشنز دیکھیں اور ان کا انتظام کریں' : 'View and manage all notifications',
            icon: Icons.notifications,
            iconColor: Colors.amber,
            onTap: () => context.push('/notifications'),
          ),

          // ---------------------------------------------------------
          // Section: Super Admin Only Controls
          // ---------------------------------------------------------
          if (isSuperAdmin) ...[
            const SizedBox(height: 24),
            Row(
              children: [
                const Icon(Icons.shield, color: AppColors.gold, size: 20),
                const SizedBox(width: 8),
                Text(
                  isUrdu ? 'سپر ایڈمن اختیارات' : 'Super Admin Controls',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gold),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // 1. History / Audit Log (Super Admin Only)
            _buildActionCard(
              context: context,
              title: loc.translate('audit_log'),
              subtitle: loc.translate('audit_log_desc'),
              icon: Icons.history,
              iconColor: Colors.cyan,
              onTap: () => context.push('/admin/audit-logs'),
            ),

            // 2. Send Broadcast Notification to All Users
            _buildActionCard(
              context: context,
              title: loc.translate('send_notification'),
              subtitle: loc.translate('send_notification_desc'),
              icon: Icons.campaign,
              iconColor: Colors.deepOrangeAccent,
              onTap: () => _showBroadcastNotificationDialog(context, ref, loc),
            ),

            // 2b. Sent Notifications History (Super Admin Only)
            _buildActionCard(
              context: context,
              title: loc.translate('sent_notifications_history'),
              subtitle: isUrdu
                  ? 'ارسال کردہ تمام اعلانات اور نوٹیفکیشنز کا ریکارڈ دیکھیں'
                  : 'View history of all previously sent broadcast notifications',
              icon: Icons.mark_email_read,
              iconColor: Colors.tealAccent,
              onTap: () => _showSentNotificationsHistory(context, ref, loc),
            ),

            // 3. User Management (Super Admin Only)
            _buildActionCard(
              context: context,
              title: loc.translate('user_management'),
              subtitle: isUrdu
                  ? 'صارفین، ان کے کردار اور اجازتوں کا انتظام کریں'
                  : 'View members, manage roles, block/unblock accounts',
              icon: Icons.manage_accounts,
              iconColor: AppColors.emerald,
              onTap: () => context.push('/admin/users'),
            ),

            // 4. Export & Import JSON (Super Admin Only)
            _buildActionCard(
              context: context,
              title: isUrdu ? 'شجرہ ایکسپورٹ / امپورٹ JSON' : 'Export / Import Family Tree JSON',
              subtitle: isUrdu
                  ? 'ڈیٹا بیس کا بیک اپ لیں یا نئی فائل امپورٹ کریں'
                  : 'Backup Firestore genealogy or import new JSON datasets',
              icon: Icons.import_export,
              iconColor: AppColors.info,
              onTap: () => context.push('/admin/export-import'),
            ),
          ],
        ],
      ),
    );
  }

  /// Dialog allowing Super Admin to broadcast notification to all users
  void _showBroadcastNotificationDialog(BuildContext context, WidgetRef ref, AppLocalizations loc) {
    final titleCtrl = TextEditingController();
    final messageCtrl = TextEditingController();
    final isUrdu = loc.isUrdu;
    final currentUser = ref.read(currentUserProvider);

    showDialog(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Row(
          children: [
            const Icon(Icons.campaign, color: Colors.deepOrangeAccent),
            const SizedBox(width: 8),
            Expanded(child: Text(loc.translate('send_notification'))),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isUrdu
                    ? 'یہ نوٹیفکیشن تمام رجسٹرڈ صارفین کے ایپ میں اور اینڈرائیڈ فونز پر پہنچے گا۔'
                    : 'This notification will be delivered to all registered users in-app and on Android devices.',
                style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleCtrl,
                decoration: InputDecoration(
                  labelText: loc.translate('notification_title'),
                  hintText: isUrdu ? 'مثلاً: شجرہ کی اہم معلومات' : 'e.g. Important Tree Update',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: messageCtrl,
                maxLines: 4,
                decoration: InputDecoration(
                  labelText: loc.translate('notification_message'),
                  hintText: isUrdu ? 'نوٹیفکیشن کا پیغام درج کریں...' : 'Enter message content...',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogCtx),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
            onPressed: () async {
              final title = titleCtrl.text.trim();
              final body = messageCtrl.text.trim();

              if (title.isEmpty || body.isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: AppColors.danger,
                    content: Text(isUrdu ? 'عنوان اور پیغام دونوں ضروری ہیں۔' : 'Please provide both title and message.'),
                  ),
                );
                return;
              }

              // Confirmation Dialog
              final confirm = await showDialog<bool>(
                context: context,
                builder: (confCtx) => AlertDialog(
                  title: Text(loc.translate('send_notification')),
                  content: Text(
                    isUrdu
                        ? 'کیا آپ واقعی یہ نوٹیفکیشن تمام صارفین کو بھیجنا چاہتے ہیں؟'
                        : 'Are you sure you want to send this notification to all users?',
                  ),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(confCtx, false), child: Text(loc.translate('cancel'))),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black),
                      onPressed: () => Navigator.pop(confCtx, true),
                      child: Text(isUrdu ? 'بھیجیں' : 'Send'),
                    ),
                  ],
                ),
              );

              if (confirm == true) {
                if (dialogCtx.mounted) Navigator.pop(dialogCtx);
                await ref.read(notificationRepositoryProvider).sendBroadcastNotification(
                  title: title,
                  body: body,
                  senderName: currentUser?.name ?? 'Super Admin',
                );

                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.emerald,
                      content: Text(isUrdu ? 'نوٹیفکیشن تمام صارفین کو بھیج دیا گیا۔' : 'Notification sent to all users successfully!'),
                    ),
                  );
                }
              }
            },
            child: Text(loc.translate('send_notification')),
          ),
        ],
      ),
    );
  }

  /// Bottom sheet showing history of all broadcast notifications sent by admins
  void _showSentNotificationsHistory(BuildContext context, WidgetRef ref, AppLocalizations loc) {
    final isUrdu = loc.isUrdu;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) => DraggableScrollableSheet(
        initialChildSize: 0.75,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        builder: (_, scrollController) => Container(
          decoration: const BoxDecoration(
            color: AppColors.darkSurface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Sheet Grabber handle
              Container(
                margin: const EdgeInsets.only(top: 12, bottom: 8),
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.textLightSecondary.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              // Sheet Header
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    const Icon(Icons.mark_email_read, color: Colors.tealAccent, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        loc.translate('sent_notifications_history'),
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(sheetCtx),
                    ),
                  ],
                ),
              ),
              const Divider(color: AppColors.darkBorder, height: 1),
              // Notifications Stream List
              Expanded(
                child: Consumer(
                  builder: (ctx, refConsumer, _) {
                    final sentAsync = refConsumer.watch(sentNotificationsStreamProvider);

                    return sentAsync.when(
                      loading: () => const Center(
                        child: CircularProgressIndicator(color: AppColors.gold),
                      ),
                      error: (err, _) => Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'Error: $err',
                            style: const TextStyle(color: AppColors.danger),
                          ),
                        ),
                      ),
                      data: (records) {
                        if (records.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.mark_email_unread_outlined, size: 54, color: AppColors.textLightSecondary),
                                const SizedBox(height: 12),
                                Text(
                                  isUrdu ? 'کوئی نوٹیفکیشن ارسال نہیں کیا گیا۔' : 'No broadcast notifications sent yet.',
                                  style: const TextStyle(color: AppColors.textLightSecondary, fontSize: 14),
                                ),
                              ],
                            ),
                          );
                        }

                        return ListView.separated(
                          controller: scrollController,
                          padding: const EdgeInsets.all(16),
                          itemCount: records.length,
                          separatorBuilder: (context, index) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final item = records[index];
                            final timeStr =
                                '${item.createdAt.day}/${item.createdAt.month}/${item.createdAt.year} • ${item.createdAt.hour.toString().padLeft(2, '0')}:${item.createdAt.minute.toString().padLeft(2, '0')}';
                            final sender = item.metadata?['sender']?.toString() ?? 'Super Admin';

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: AppColors.darkBackground,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(color: AppColors.darkBorder, width: 0.8),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.tealAccent.withValues(alpha: 0.15),
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(Icons.campaign, color: Colors.tealAccent, size: 20),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              item.title,
                                              style: const TextStyle(
                                                fontSize: 15,
                                                fontWeight: FontWeight.bold,
                                                color: Colors.white,
                                              ),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              timeStr,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.textLightSecondary,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          color: AppColors.emerald.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
                                        ),
                                        child: Text(
                                          isUrdu ? 'ارسال شدہ' : 'Broadcasted',
                                          style: const TextStyle(
                                            color: AppColors.emeraldLight,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.body,
                                    style: const TextStyle(fontSize: 13, color: AppColors.textLightPrimary, height: 1.4),
                                  ),
                                  const SizedBox(height: 8),
                                  Row(
                                    children: [
                                      const Icon(Icons.person_pin, size: 14, color: AppColors.gold),
                                      const SizedBox(width: 4),
                                      Text(
                                        '${isUrdu ? "ارسال کنندہ" : "Sent By"}: $sender',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textLightSecondary),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? badge,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Icon(icon, color: color, size: 24),
                if (badge != null)
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        badge,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: color),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(value, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            Text(title, style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary)),
          ],
        ),
      ),
    );
  }

  Widget _buildActionCard({
    required BuildContext context,
    required String title,
    required String subtitle,
    required IconData icon,
    required Color iconColor,
    required VoidCallback onTap,
    int? badgeCount,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withValues(alpha: 0.15),
          child: Icon(icon, color: iconColor),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary)),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (badgeCount != null && badgeCount > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: AppColors.danger,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$badgeCount',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                ),
              ),
            const Icon(Icons.arrow_forward_ios, size: 14),
          ],
        ),
        onTap: onTap,
      ),
    );
  }
}
