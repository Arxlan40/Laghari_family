import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/crashlytics_service.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/family_tree_providers.dart';
import '../../services/descendant_tree_service.dart';
import '../widgets/member_avatar_widget.dart';
import '../widgets/tree_canvas_widget.dart';

/// Dedicated screen that displays the family tree of ONLY the selected person and their descendants.
class PersonFamilyTreeScreen extends ConsumerWidget {
  final String memberId;

  const PersonFamilyTreeScreen({
    super.key,
    required this.memberId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allMembers = ref.watch(familyMembersMapProvider);
    final currentUser = ref.watch(currentUserProvider);

    final member = allMembers[memberId];

    // Crashlytics breadcrumb
    CrashlyticsService.instance.log('Person Family Tree opened: memberId=$memberId');

    if (member == null) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isUrdu ? 'شجرہ نسب' : 'Family Tree'),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.person_off_outlined, size: 48, color: AppColors.gold),
              const SizedBox(height: 12),
              Text(
                isUrdu ? 'رکن کی معلومات دستیاب نہیں ہیں۔' : 'Family member not found.',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => context.pop(),
                child: Text(loc.translate('cancel')),
              ),
            ],
          ),
        ),
      );
    }

    final personName = member.localizedName(loc.locale.languageCode);

    // Compute descendant tree dataset
    final treeResult = DescendantTreeService.getDescendantTree(memberId, allMembers);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              personName,
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
              ),
            ),
            Text(
              isUrdu
                  ? 'شجرہ اولاد و نسل (${treeResult?.totalDescendantsCount ?? 0} ارکان)'
                  : 'Descendant Tree (${treeResult?.totalDescendantsCount ?? 0} descendants)',
              style: TextStyle(
                fontSize: 11.5,
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.badge_outlined, color: AppColors.gold),
            tooltip: loc.translate('profile'),
            onPressed: () => context.push('/member/$memberId'),
          ),
        ],
      ),
      body: (treeResult == null || !treeResult.hasChildren)
          ? _buildEmptyChildrenState(context, ref, member, isUrdu, isDark, loc, currentUser?.isAdmin ?? false)
          : TreeCanvasWidget(
              initialFocusMemberId: member.id,
              isDirectAdmin: currentUser?.isAdmin ?? false,
              customMembersMap: treeResult.membersMap,
              customTitle: isUrdu
                  ? 'شجرہ نسب: $personName اور اولاد'
                  : 'Family Tree: $personName & Descendants',
            ),
    );
  }

  Widget _buildEmptyChildrenState(
    BuildContext context,
    WidgetRef ref,
    dynamic member,
    bool isUrdu,
    bool isDark,
    AppLocalizations loc,
    bool isAdmin,
  ) {
    final personName = member.localizedName(loc.locale.languageCode);

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Avatar
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: AppColors.gold, width: 2),
                ),
                child: MemberAvatarWidget(member: member, radius: 46),
              ),
              const SizedBox(height: 16),

              Text(
                personName,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${isUrdu ? "پشت" : "Generation"} ${member.generation}',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                ),
              ),
              const SizedBox(height: 24),

              // Clean message card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkCard : const Color(0xFFF7FBF9),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.emerald.withValues(alpha: 0.2),
                  ),
                ),
                child: Column(
                  children: [
                    Icon(
                      Icons.account_tree_outlined,
                      size: 40,
                      color: AppColors.gold.withValues(alpha: 0.8),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      isUrdu
                          ? 'اس رکن کے لیے ابھی کوئی اولاد شامل نہیں کی گئی ہے۔'
                          : 'No children have been added for this member yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        height: 1.45,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      isUrdu
                          ? 'جب اس رکن کے بچے شامل کیے جائیں گے، وہ ان کے ذاتی شجرہ نسب میں یہاں نظر آئیں گے۔'
                          : 'When children are recorded for this person, their personal descendant tree will appear here.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Action buttons
              Wrap(
                spacing: 12,
                runSpacing: 12,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => context.pop(),
                    icon: const Icon(Icons.arrow_back, size: 18),
                    label: Text(isUrdu ? 'پروفائل پر واپس جائیں' : 'Back to Profile'),
                  ),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () {
                      if (isAdmin) {
                        context.push('/admin/add-child/${member.id}');
                      } else {
                        context.push('/request-add-child/${member.id}');
                      }
                    },
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(loc.translate('add_child')),
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
