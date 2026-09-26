import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../repositories/notification_repository.dart';

class NotificationBadgeIcon extends ConsumerWidget {
  final Color? color;

  const NotificationBadgeIcon({super.key, this.color});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final unreadCount = ref.watch(unreadNotificationsCountProvider);

    return IconButton(
      tooltip: loc.translate('notifications'),
      onPressed: () => context.push('/notifications'),
      icon: Badge.count(
        count: unreadCount,
        isLabelVisible: unreadCount > 0,
        backgroundColor: AppColors.danger,
        textColor: Colors.white,
        child: Icon(
          unreadCount > 0 ? Icons.notifications : Icons.notifications_none_outlined,
          color: color ?? AppColors.gold,
        ),
      ),
    );
  }
}
