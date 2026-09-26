import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../family_tree/presentation/widgets/tree_canvas_widget.dart';
import '../../../notifications/presentation/widgets/notification_badge_icon.dart';

/// Admin Direct Tree Management Screen
/// Allows Admin / Super Admin to directly edit names, member details, add children,
/// and delete members with immediate Firestore synchronization and audit logging.
class AdminTreeScreen extends ConsumerWidget {
  final String? focusMemberId;

  const AdminTreeScreen({
    super.key,
    this.focusMemberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.emerald, width: 1),
              ),
              child: Text(
                isUrdu ? 'ایڈمن پورٹل' : 'ADMIN PORTAL',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: AppColors.emeraldLight,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                loc.translate('direct_management'),
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                  color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                ),
              ),
            ),
          ],
        ),
        actions: [
          const NotificationBadgeIcon(),
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.gold),
            tooltip: loc.translate('search'),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: Column(
        children: [
          // Admin Mode Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.emerald.withValues(alpha: 0.15)
                  : AppColors.emerald.withValues(alpha: 0.08),
              border: Border(
                bottom: BorderSide(
                  color: AppColors.emerald.withValues(alpha: 0.3),
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.security, size: 18, color: AppColors.emerald),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    isUrdu
                        ? 'ایڈمن موڈ: کسی بھی فرد پر ٹیپ کر کے براہ راست نام، تفصیلات تبدیل کریں یا بچے شامل کریں۔'
                        : 'Admin Direct Mode: Tap any member to directly edit names, details, add children, or delete.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? AppColors.emeraldLight : AppColors.emeraldDark,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Tree Canvas in Admin Direct Mode
          Expanded(
            child: TreeCanvasWidget(
              initialFocusMemberId: focusMemberId,
              isDirectAdmin: true,
            ),
          ),
        ],
      ),
    );
  }
}
