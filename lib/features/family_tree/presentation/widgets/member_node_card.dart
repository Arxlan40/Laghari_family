import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../models/family_member.dart';
import 'member_avatar_widget.dart';
import 'member_preview_sheet.dart';

/// Clean MyHeritage & Pedigree style member card.
/// Features:
/// - Compact orthogonal layout with gender-specific color accents
/// - Top circular avatar with gender rim
/// - Primary name, secondary name, life years/generation
/// - 3-Dot action menu for profile, details, edit, add child
/// - Bottom +/- expander pill for children branch
class MemberNodeCard extends StatelessWidget {
  final FamilyMember member;
  final bool isSelected;
  final bool isExpanded;
  final VoidCallback? onTap;
  final VoidCallback? onExpandToggle;
  final VoidCallback? onLongPress;

  const MemberNodeCard({
    super.key,
    required this.member,
    this.isSelected = false,
    this.isExpanded = false,
    this.onTap,
    this.onExpandToggle,
    this.onLongPress,
  });

  String _formatLifeYears(FamilyMember m, AppLocalizations loc) {
    final birth = m.birthDate?.trim();
    final death = m.deathDate?.trim();

    String extractYear(String val) {
      final match = RegExp(r'\b(1\d{3}|20\d{2})\b').firstMatch(val);
      return match != null ? match.group(0)! : val;
    }

    if (birth != null && birth.isNotEmpty && death != null && death.isNotEmpty) {
      return '${extractYear(birth)} – ${extractYear(death)}';
    } else if (birth != null && birth.isNotEmpty) {
      if (m.aliveStatus == AliveStatus.alive) {
        return loc.isUrdu ? '${extractYear(birth)} – حیات' : '${extractYear(birth)} – Pres.';
      }
      return extractYear(birth);
    } else if (death != null && death.isNotEmpty) {
      return loc.isUrdu ? 'وفات ${extractYear(death)}' : 'd. ${extractYear(death)}';
    }

    // Default to status label if no dates
    switch (m.aliveStatus) {
      case AliveStatus.alive:
        return loc.isUrdu ? 'حیات' : 'Living';
      case AliveStatus.deceased:
        return loc.isUrdu ? 'مرحوم' : 'Deceased';
      case AliveStatus.unknown:
        return '${loc.isUrdu ? "پشت" : "Gen"} ${m.generation}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final primaryName = member.localizedName(loc.locale.languageCode);
    final secondaryName = member.secondaryName(loc.locale.languageCode);

    // Gender accent colors inspired by MyHeritage / Pedigree reference
    final genderColor = member.isFemale
        ? (isDark ? const Color(0xFFF48FB1) : const Color(0xFFE91E63))
        : (isDark ? const Color(0xFF90CAF9) : const Color(0xFF1976D2));

    final genderBg = member.isFemale
        ? (isDark ? const Color(0xFF2A1520) : const Color(0xFFFFF0F5))
        : (isDark ? const Color(0xFF132235) : const Color(0xFFF0F7FF));

    final lifeYears = _formatLifeYears(member, loc);
    final hasChildren = member.childrenIds.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          width: 174,
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected
                  ? AppColors.gold
                  : (isDark ? genderColor.withValues(alpha: 0.6) : genderColor.withValues(alpha: 0.7)),
              width: isSelected ? 2.5 : 1.3,
            ),
            boxShadow: [
              if (isSelected)
                BoxShadow(
                  color: AppColors.gold.withValues(alpha: isDark ? 0.45 : 0.35),
                  blurRadius: 18,
                  spreadRadius: 2,
                  offset: const Offset(0, 3),
                )
              else
                BoxShadow(
                  color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Top Gender Bar Strip with Generation & 3-Dot Action Menu
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: genderBg,
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(12),
                    topRight: Radius.circular(12),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Gen Tag
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                      decoration: BoxDecoration(
                        color: isDark ? Colors.black38 : Colors.white,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: genderColor.withValues(alpha: 0.5), width: 0.6),
                      ),
                      child: Text(
                        '${isUrdu ? "پشت" : "Gen"} ${member.generation}',
                        style: TextStyle(
                          fontSize: 9.5,
                          fontWeight: FontWeight.bold,
                          color: genderColor,
                        ),
                      ),
                    ),

                    // 3-Dot Action Menu (Requirement: "give 3 dot menu button to open further details")
                    PopupMenuButton<String>(
                      tooltip: 'Member Options',
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      icon: Icon(
                        Icons.more_vert,
                        size: 17,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                      onSelected: (action) {
                        switch (action) {
                          case 'profile':
                            context.push('/member/${member.id}');
                            break;
                          case 'sheet':
                            MemberPreviewSheet.show(context, member);
                            break;
                          case 'suggest_edit':
                            context.push('/submit-edit-request/${member.id}');
                            break;
                          case 'add_child':
                            context.push('/request-add-child/${member.id}');
                            break;
                        }
                      },
                      itemBuilder: (ctx) => [
                        PopupMenuItem(
                          value: 'profile',
                          child: Row(
                            children: [
                              const Icon(Icons.account_circle, size: 18, color: AppColors.emerald),
                              const SizedBox(width: 10),
                              Text(isUrdu ? 'مکمل پروفائل' : 'View Profile'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'sheet',
                          child: Row(
                            children: [
                              const Icon(Icons.info_outline, size: 18, color: AppColors.gold),
                              const SizedBox(width: 10),
                              Text(isUrdu ? 'مختصر تفصیلات' : 'Quick Details'),
                            ],
                          ),
                        ),
                        const PopupMenuDivider(),
                        PopupMenuItem(
                          value: 'suggest_edit',
                          child: Row(
                            children: [
                              const Icon(Icons.edit_note, size: 18, color: Colors.blueAccent),
                              const SizedBox(width: 10),
                              Text(isUrdu ? 'معلومات کی درستگی' : 'Suggest Edit'),
                            ],
                          ),
                        ),
                        PopupMenuItem(
                          value: 'add_child',
                          child: Row(
                            children: [
                              const Icon(Icons.person_add_alt_1, size: 18, color: Colors.teal),
                              const SizedBox(width: 10),
                              Text(isUrdu ? 'اولاد شامل کریں' : 'Add Child'),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Card Body: Avatar, Names, Life Years
              Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Centered Circular Avatar
                    Container(
                      padding: const EdgeInsets.all(1.5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: genderColor, width: 1.5),
                      ),
                      child: MemberAvatarWidget(
                        member: member,
                        radius: 24,
                        showStatusIndicator: false,
                      ),
                    ),
                    const SizedBox(height: 6),

                    // Primary Name
                    Text(
                      primaryName,
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.bold,
                        color: isSelected
                            ? (isDark ? AppColors.goldLight : AppColors.emeraldDark)
                            : (isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary),
                      ),
                    ),

                    // Secondary Name if Urdu is active or English is secondary
                    if (secondaryName.isNotEmpty && secondaryName != primaryName) ...[
                      const SizedBox(height: 1.5),
                      Text(
                        secondaryName,
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10.5,
                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                        ),
                      ),
                    ],
                    const SizedBox(height: 3),

                    // Life Years / Status
                    Text(
                      lifeYears,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w500,
                        color: member.aliveStatus == AliveStatus.alive
                            ? AppColors.aliveColor
                            : (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                      ),
                    ),
                  ],
                ),
              ),

              // Bottom Branch Expander Pill (Requirement: "on click open its childeren tree")
              if (hasChildren) ...[
                const Divider(height: 1, thickness: 0.8),
                InkWell(
                  onTap: onExpandToggle ?? onTap,
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(12),
                    bottomRight: Radius.circular(12),
                  ),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    decoration: BoxDecoration(
                      color: isExpanded
                          ? (isDark ? const Color(0xFF1A3326) : const Color(0xFFE8F5E9))
                          : (isDark ? Colors.black26 : const Color(0xFFF9F9F9)),
                      borderRadius: const BorderRadius.only(
                        bottomLeft: Radius.circular(12),
                        bottomRight: Radius.circular(12),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          isExpanded ? Icons.remove_circle_outline : Icons.add_circle_outline,
                          size: 13,
                          color: isExpanded ? AppColors.emerald : genderColor,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${member.childrenIds.length} ${isUrdu ? "اولاد" : (member.childrenIds.length == 1 ? "Child" : "Children")}',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.bold,
                            color: isExpanded ? AppColors.emerald : (isDark ? Colors.white70 : Colors.black87),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
