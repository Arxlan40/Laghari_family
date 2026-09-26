import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../notifications/presentation/widgets/notification_badge_icon.dart';
import '../widgets/tree_canvas_widget.dart';

class FamilyTreeScreen extends ConsumerWidget {
  final String? focusMemberId;

  const FamilyTreeScreen({
    super.key,
    this.focusMemberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.gold, width: 1.2),
              ),
              child: ClipOval(
                child: Image.asset('assets/images/app_icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              loc.translate('app_name'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
              ),
            ),
          ],
        ),
        actions: [
          const NotificationBadgeIcon(),
          // Search Icon Button
          IconButton(
            icon: const Icon(Icons.search, color: AppColors.gold),
            tooltip: loc.translate('search'),
            onPressed: () => context.push('/search'),
          ),
        ],
      ),
      body: TreeCanvasWidget(
        initialFocusMemberId: focusMemberId,
        isDirectAdmin: ref.watch(currentUserProvider)?.isAdmin ?? false,
      ),
    );
  }
}
