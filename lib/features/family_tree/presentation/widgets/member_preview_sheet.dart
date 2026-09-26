import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../admin/models/audit_log_model.dart';
import '../../../admin/repositories/audit_log_repository.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../edit_requests/models/edit_request.dart';
import '../../../edit_requests/repositories/edit_request_repository.dart';
import '../../../storage/services/supabase_storage_service.dart';
import '../../models/family_member.dart';
import '../../providers/family_tree_providers.dart';
import '../../repositories/family_repository.dart';
import 'member_avatar_widget.dart';

class MemberPreviewSheet extends ConsumerWidget {
  final FamilyMember member;
  final VoidCallback? onCenterInTree;

  const MemberPreviewSheet({
    super.key,
    required this.member,
    this.onCenterInTree,
  });

  static Future<void> show(
    BuildContext context,
    FamilyMember member, {
    VoidCallback? onCenterInTree,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemberPreviewSheet(
        member: member,
        onCenterInTree: onCenterInTree,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final currentUser = ref.watch(currentUserProvider);
    final membersMap = ref.watch(familyMembersMapProvider);
    final father = member.fatherId != null ? membersMap[member.fatherId] : null;

    final primaryName = member.localizedName(loc.locale.languageCode);
    final secondaryName = member.secondaryName(loc.locale.languageCode);

    return Container(
      padding: const EdgeInsets.only(top: 12, left: 20, right: 20, bottom: 32),
      decoration: const BoxDecoration(
        color: AppColors.darkSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(top: BorderSide(color: AppColors.gold, width: 2)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.darkBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header with Avatar and Names
          Row(
            children: [
              MemberAvatarWidget(member: member, radius: 36),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      primaryName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textLightPrimary,
                      ),
                    ),
                    if (secondaryName.isNotEmpty && secondaryName != primaryName)
                      Text(
                        secondaryName,
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.textLightSecondary,
                        ),
                      ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.darkBackground,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${isUrdu ? "پشت" : "Gen"} ${member.generation}',
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (member.aliveStatus != AliveStatus.unknown) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: (member.aliveStatus == AliveStatus.alive
                                      ? AppColors.aliveColor
                                      : AppColors.deceasedColor)
                                  .withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              isUrdu ? member.aliveStatus.labelUr : member.aliveStatus.labelEn,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: member.aliveStatus == AliveStatus.alive
                                    ? AppColors.aliveColor
                                    : AppColors.textLightSecondary,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: AppColors.darkBorder),
          const SizedBox(height: 12),

          // Details List
          if (father != null) ...[
            InkWell(
              onTap: () {
                Navigator.pop(context);
                ref.read(familyTreeStateProvider.notifier).selectMember(father.id);
                MemberPreviewSheet.show(context, father);
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.escalator_warning, size: 18, color: AppColors.gold),
                    const SizedBox(width: 10),
                    Text('${loc.translate("father")}: ', style: const TextStyle(color: AppColors.textLightSecondary)),
                    Text(
                      father.localizedName(loc.locale.languageCode),
                      style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward_ios, size: 12, color: AppColors.textLightSecondary),
                  ],
                ),
              ),
            ),
          ],

          if (member.birthDate != null || member.deathDate != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  const Icon(Icons.calendar_today, size: 16, color: AppColors.textLightSecondary),
                  const SizedBox(width: 10),
                  Text(
                    '${member.birthDate ?? (isUrdu ? "نامعلوم" : "Unknown")} - ${member.deathDate ?? (member.aliveStatus == AliveStatus.alive ? (isUrdu ? "حیات" : "Present") : (isUrdu ? "وفات نامعلوم" : "Unknown"))}',
                    style: const TextStyle(color: AppColors.textLightSecondary, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],

          if (member.notes != null && member.notes!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.darkBackground,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.darkBorder),
              ),
              child: Text(
                member.notes!,
                style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
              ),
            ),
          ],

          const SizedBox(height: 20),

          // Action Buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              // Center in tree
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(treeFocusTargetProvider.notifier).state = member.id;
                  ref.read(familyTreeStateProvider.notifier).selectMember(member.id);
                  Navigator.pop(context);
                  onCenterInTree?.call();
                  context.go('/family-tree?focusMemberId=${member.id}');
                },
                icon: const Icon(Icons.account_tree, size: 18),
                label: Text(loc.translate('view_family_tree')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.black,
                ),
              ),

              // Full Profile Screen
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/member/${member.id}');
                },
                icon: const Icon(Icons.badge, size: 18),
                label: Text(loc.translate('profile')),
              ),

              // Edit button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/edit-request/${member.id}');
                },
                icon: const Icon(Icons.edit_note, size: 18),
                label: Text(
                  currentUser != null && currentUser.isAdmin
                      ? loc.translate('edit_member')
                      : loc.translate('suggest_edit'),
                ),
              ),

              // Add Child button
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/request-add-child/${member.id}');
                },
                icon: const Icon(Icons.person_add_alt, size: 18),
                label: Text(
                  currentUser != null && currentUser.isAdmin
                      ? loc.translate('add_child')
                      : loc.translate('request_add_child'),
                ),
              ),

              // Add / Update Picture via Supabase
              OutlinedButton.icon(
                onPressed: () async {
                  final scaffoldMessenger = ScaffoldMessenger.of(context);
                  final result = await FilePicker.platform.pickFiles(
                    type: FileType.image,
                    withData: true,
                  );
                  if (result != null && result.files.single.bytes != null) {
                    final bytes = result.files.single.bytes!;
                    final ext = result.files.single.extension ?? 'jpg';

                    scaffoldMessenger.showSnackBar(
                      const SnackBar(content: Text('Uploading picture to Supabase Storage...')),
                    );

                    try {
                      final storage = ref.read(supabaseStorageServiceProvider);
                      final url = await storage.uploadMemberImage(
                        memberId: member.id,
                        bytes: bytes,
                        fileExtension: ext,
                      );

                      if (currentUser != null && currentUser.isAdmin) {
                        // Admin direct update
                        final updated = member.copyWith(imageUrl: url);
                        await ref.read(familyRepositoryProvider).saveMember(updated);
                        await ref.read(auditLogRepositoryProvider).recordLog(
                          AuditLogModel(
                            logId: const Uuid().v4(),
                            action: 'direct_edit',
                            performedBy: currentUser.uid,
                            performedByName: currentUser.name,
                            performedByRole: currentUser.role.value,
                            targetMemberId: member.id,
                            targetMemberName: member.nameEn,
                            oldData: {'imageUrl': member.imageUrl},
                            newData: {'imageUrl': url},
                            timestamp: DateTime.now(),
                          ),
                        );
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Member picture updated successfully!')),
                        );
                      } else {
                        // Create picture edit request for approval
                        await ref.read(editRequestRepositoryProvider).submitRequest(
                          EditRequest(
                            requestId: '',
                            type: EditRequestType.uploadPicture,
                            memberId: member.id,
                            requestedBy: currentUser?.uid ?? 'guest_user',
                            requestedByName: currentUser?.name ?? 'Member',
                            changes: {'image_url': url},
                            reason: 'Uploaded new family portrait photograph.',
                            createdAt: DateTime.now(),
                          ),
                        );
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Picture submitted for Admin approval!')),
                        );
                      }
                      if (context.mounted) Navigator.pop(context);
                    } catch (e) {
                      scaffoldMessenger.showSnackBar(
                        SnackBar(content: Text('Upload failed: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.camera_alt, size: 18),
                label: Text(loc.translate('add_picture')),
              ),

              // Direct Delete for Admin
              if (currentUser != null && currentUser.isAdmin)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
                  onPressed: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: Text(loc.translate('delete_member')),
                        content: Text(
                          loc.isUrdu
                              ? 'کیا آپ واقعی "${member.nameUr.isNotEmpty ? member.nameUr : member.nameEn}" کو حذف کرنا چاہتے ہیں؟'
                              : 'Are you sure you want to delete "${member.nameEn}"? This action will be recorded in audit log.',
                        ),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.translate('cancel'))),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(loc.translate('delete')),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      await ref.read(familyRepositoryProvider).deleteMember(member.id);
                      await ref.read(auditLogRepositoryProvider).recordLog(
                        AuditLogModel(
                          logId: const Uuid().v4(),
                          action: 'direct_delete',
                          performedBy: currentUser.uid,
                          performedByName: currentUser.name,
                          performedByRole: currentUser.role.value,
                          targetMemberId: member.id,
                          targetMemberName: member.nameEn,
                          oldData: member.toJson(),
                          newData: {'deleted': true},
                          timestamp: DateTime.now(),
                        ),
                      );
                      if (context.mounted) {
                        Navigator.pop(context);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.danger,
                            content: Text('Member deleted and logged.'),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                  label: Text(loc.translate('delete')),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
