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
import 'delete_member_dialog.dart';
import 'edit_name_dialog.dart';
import 'member_avatar_widget.dart';

class MemberPreviewSheet extends ConsumerWidget {
  final FamilyMember member;
  final VoidCallback? onCenterInTree;
  final bool isDirectAdmin;

  const MemberPreviewSheet({
    super.key,
    required this.member,
    this.onCenterInTree,
    this.isDirectAdmin = false,
  });

  static Future<void> show(
    BuildContext context,
    FamilyMember member, {
    VoidCallback? onCenterInTree,
    bool isDirectAdmin = false,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => MemberPreviewSheet(
        member: member,
        onCenterInTree: onCenterInTree,
        isDirectAdmin: isDirectAdmin,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final currentUser = ref.watch(currentUserProvider);
    final effectiveIsAdmin = isDirectAdmin || (currentUser?.isAdmin ?? false);
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
              // Dedicated Descendant Tree
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/member/${member.id}/tree');
                },
                icon: const Icon(Icons.account_tree, size: 18, color: Colors.black),
                label: Text(
                  isUrdu ? 'ذاتی شجرہ دیکھیں' : 'See Family Tree',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.gold,
                ),
              ),

              // Center in whole tree
              ElevatedButton.icon(
                onPressed: () {
                  ref.read(treeFocusTargetProvider.notifier).state = member.id;
                  ref.read(familyTreeStateProvider.notifier).selectMember(member.id);
                  Navigator.pop(context);
                  onCenterInTree?.call();
                  context.go('/family-tree?focusMemberId=${member.id}');
                },
                icon: const Icon(Icons.explore_outlined, size: 18),
                label: Text(loc.translate('locate_in_full_tree')),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
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

              if (effectiveIsAdmin) ...[
                // Admin Portal Direct: Edit Name (EN/UR)
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    EditNameDialog.show(context, member, isDirectAdmin: true);
                  },
                  icon: const Icon(Icons.edit, size: 18, color: Colors.black),
                  label: Text(
                    isUrdu ? 'براہ راست نام میں ترمیم' : 'Direct Edit Name',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                  ),
                ),

                // Admin Portal Direct: Edit Details
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/admin/edit-member/${member.id}');
                  },
                  icon: const Icon(Icons.edit_note, size: 18, color: Colors.black),
                  label: Text(
                    isUrdu ? 'براہ راست تفصیلات کی ترمیم' : 'Direct Edit Details',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                  ),
                ),

                // Admin Portal Direct: Add Child
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/admin/add-child/${member.id}');
                  },
                  icon: const Icon(Icons.person_add, size: 18, color: Colors.black),
                  label: Text(
                    isUrdu ? 'براہ راست بچہ شامل کریں' : 'Direct Add Child',
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.gold,
                  ),
                ),

                // Admin Portal Direct: Upload Picture
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

                        final updated = member.copyWith(imageUrl: url, updatedAt: DateTime.now());
                        await ref.read(familyRepositoryProvider).saveMember(updated);

                        await ref.read(auditLogRepositoryProvider).recordLog(
                          AuditLogModel(
                            logId: const Uuid().v4(),
                            action: 'direct_upload_picture',
                            performedBy: currentUser?.uid ?? 'admin',
                            performedByName: currentUser?.name ?? 'Admin',
                            performedByRole: currentUser?.role.value ?? 'admin',
                            performedByPhone: currentUser?.phone,
                            targetMemberId: member.id,
                            targetMemberName: member.nameEn,
                            newData: {'image_url': url},
                            timestamp: DateTime.now(),
                          ),
                        );

                        scaffoldMessenger.showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.emerald,
                            content: Text('Profile picture updated successfully!'),
                          ),
                        );
                        if (context.mounted) Navigator.pop(context);
                      } catch (e) {
                        scaffoldMessenger.showSnackBar(
                          SnackBar(content: Text('Upload failed: $e')),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.camera_alt, size: 18, color: AppColors.emerald),
                  label: Text(isUrdu ? 'براہ راست تصویر تبدیل کریں' : 'Direct Photo Update'),
                ),

                // Admin Portal Direct: Delete Member
                OutlinedButton.icon(
                  onPressed: () async {
                    final deleted = await DeleteMemberDialog.show(context, ref, member);
                    if (deleted && context.mounted) {
                      Navigator.pop(context);
                    }
                  },
                  icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                  label: Text(
                    isUrdu ? 'شجرہ سے خارج کریں' : 'Direct Delete',
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ] else ...[
                // Member Portal: Request Edit actions only
                // Edit Name button (Submits request for admin review)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    EditNameDialog.show(context, member, isDirectAdmin: false);
                  },
                  icon: const Icon(Icons.edit, size: 18, color: AppColors.gold),
                  label: Text(
                    isUrdu ? 'نام میں ترمیم (اردو/EN)' : 'Edit Name (EN/UR)',
                    style: const TextStyle(color: AppColors.goldLight),
                  ),
                ),

                // Edit button (Suggest Edit request)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/edit-request/${member.id}');
                  },
                  icon: const Icon(Icons.edit_note, size: 18),
                  label: Text(loc.translate('suggest_edit')),
                ),

                // Add Child button (Request Add Child)
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    context.push('/request-add-child/${member.id}');
                  },
                  icon: const Icon(Icons.person_add_alt, size: 18),
                  label: Text(loc.translate('request_add_child')),
                ),

                // Add / Update Picture (Submits photo request for approval)
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

                        // Submit photo request for approval
                        await ref.read(editRequestRepositoryProvider).submitRequest(
                          EditRequest(
                            requestId: '',
                            type: EditRequestType.uploadPicture,
                            memberId: member.id,
                            requestedBy: currentUser?.uid ?? 'guest_user',
                            requestedByName: currentUser?.name ?? 'Member',
                            requestedByPhone: currentUser?.phone,
                            changes: {'image_url': url},
                            reason: 'Uploaded new family portrait photograph.',
                            createdAt: DateTime.now(),
                          ),
                        );
                        scaffoldMessenger.showSnackBar(
                          const SnackBar(content: Text('Picture submitted for Admin approval!')),
                        );
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
              ],
            ],
          ),
        ],
      ),
    );
  }
}
