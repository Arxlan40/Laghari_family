import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../repositories/notification_repository.dart';

class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _markAllAsRead();
    });
  }

  void _markAllAsRead() {
    final currentUser = ref.read(currentUserProvider);
    if (currentUser != null) {
      ref.read(badgeClearedOptimisticallyProvider.notifier).state = true;
      ref.read(notificationRepositoryProvider).markAllAsRead(
            currentUser.uid,
            isAdmin: currentUser.isAdmin,
            isSuperAdmin: currentUser.isSuperAdmin,
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final notifsAsync = ref.watch(userNotificationsStreamProvider);
    final currentUser = ref.watch(currentUserProvider);
    final currentUserId = currentUser?.uid ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('notifications')),
        actions: [
          TextButton(
            onPressed: _markAllAsRead,
            child: Text(loc.translate('mark_all_read'), style: const TextStyle(color: AppColors.emeraldLight)),
          ),
        ],
      ),
      body: notifsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (e, _) => Center(child: Text('Error loading notifications: $e')),
        data: (notifications) {
          if (notifications.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.notifications_none, size: 64, color: AppColors.textLightSecondary),
                  const SizedBox(height: 12),
                  Text(loc.translate('no_notifications'), style: const TextStyle(color: AppColors.textLightSecondary)),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: notifications.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, index) {
              final notif = notifications[index];
              final isRead = notif.isReadFor(currentUserId);

              return Card(
                color: isRead ? AppColors.darkCard : AppColors.darkSurface,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: isRead ? AppColors.darkBorder : AppColors.emerald.withValues(alpha: 0.6),
                    width: isRead ? 1 : 1.5,
                  ),
                ),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: notif.type.contains('approved')
                        ? AppColors.emerald.withValues(alpha: 0.2)
                        : (notif.type.contains('rejected')
                            ? AppColors.danger.withValues(alpha: 0.2)
                            : AppColors.gold.withValues(alpha: 0.2)),
                    child: Icon(
                      notif.type.contains('approved')
                          ? Icons.check
                          : (notif.type.contains('rejected')
                              ? Icons.close
                              : Icons.notifications),
                      color: notif.type.contains('approved')
                          ? AppColors.emerald
                          : (notif.type.contains('rejected')
                              ? AppColors.danger
                              : AppColors.gold),
                    ),
                  ),
                  title: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          notif.title,
                          style: TextStyle(
                            fontWeight: isRead ? FontWeight.normal : FontWeight.bold,
                          ),
                        ),
                      ),
                      if (!isRead)
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppColors.emerald,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(notif.body, style: const TextStyle(fontSize: 13)),
                      const SizedBox(height: 6),
                      Text(
                        '${notif.createdAt.day}/${notif.createdAt.month}/${notif.createdAt.year} ${notif.createdAt.hour}:${notif.createdAt.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 10, color: AppColors.textLightSecondary),
                      ),
                    ],
                  ),
                  onTap: () {
                    ref.read(notificationRepositoryProvider).markAsRead(
                          notif.notificationId,
                          userId: currentUserId,
                        );
                    final memberId = notif.metadata?['member_id'];
                    if (memberId != null && memberId.toString().isNotEmpty) {
                      context.push('/member/$memberId');
                    }
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
