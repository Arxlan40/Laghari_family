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
import '../../../notifications/presentation/widgets/notification_badge_icon.dart';
import '../../../storage/services/supabase_storage_service.dart';
import '../../models/family_member.dart';
import '../../providers/family_tree_providers.dart';
import '../../repositories/family_repository.dart';
import '../widgets/edit_name_dialog.dart';
import '../widgets/member_avatar_widget.dart';

class MemberProfileScreen extends ConsumerWidget {
  final String memberId;

  const MemberProfileScreen({super.key, required this.memberId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final membersMap = ref.watch(familyMembersMapProvider);
    final member = membersMap[memberId];
    final currentUser = ref.watch(currentUserProvider);

    if (member == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.translate('profile'))),
        body: const Center(child: Text('Member not found.')),
      );
    }

    final father = member.fatherId != null ? membersMap[member.fatherId] : null;
    final children = member.childrenIds
        .map((id) => membersMap[id])
        .whereType<FamilyMember>()
        .toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(member.localizedName(loc.locale.languageCode)),
        actions: [
          const NotificationBadgeIcon(),
          // View in Family Tree action
          IconButton(
            icon: const Icon(Icons.account_tree, color: AppColors.emerald),
            tooltip: loc.translate('view_family_tree'),
            onPressed: () => _navigateToTree(ref, context, member, membersMap),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Avatar Header
            MemberAvatarWidget(member: member, radius: 50),
            const SizedBox(height: 16),

            // English & Urdu Names
            Text(
              member.localizedName(loc.locale.languageCode),
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            if (member.secondaryName(loc.locale.languageCode).isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                member.secondaryName(loc.locale.languageCode),
                style: const TextStyle(fontSize: 16, color: AppColors.textLightSecondary),
              ),
            ],
            const SizedBox(height: 12),

            // Badges Row: Generation, Alive Status (Only shown if alive or deceased, NEVER if unknown), Gender
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildBadge('${loc.translate("generation")} ${member.generation}', AppColors.darkCard),
                if (member.aliveStatus != AliveStatus.unknown) ...[
                  const SizedBox(width: 8),
                  _buildBadge(
                    isUrdu ? member.aliveStatus.labelUr : member.aliveStatus.labelEn,
                    (member.aliveStatus == AliveStatus.alive
                            ? AppColors.aliveColor
                            : AppColors.deceasedColor)
                        .withValues(alpha: 0.25),
                    textColor: member.aliveStatus == AliveStatus.alive
                        ? AppColors.aliveColor
                        : AppColors.textLightSecondary,
                  ),
                ],
                const SizedBox(width: 8),
                _buildBadge(
                  member.isFemale ? loc.translate('female') : loc.translate('male'),
                  (member.isFemale ? AppColors.femaleAccent : AppColors.maleAccent).withValues(alpha: 0.2),
                  textColor: member.isFemale ? AppColors.femaleAccent : AppColors.maleAccent,
                ),
              ],
            ),
            const SizedBox(height: 20),

            // Prominent "View in Family Tree" Action Card
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  elevation: 3,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
                icon: const Icon(Icons.account_tree, size: 22),
                label: Text(
                  loc.translate('view_in_tree'),
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                onPressed: () => _navigateToTree(ref, context, member, membersMap),
              ),
            ),
            const SizedBox(height: 14),

            // Secondary Action Buttons Bar
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                if (currentUser?.isAdmin == true) ...[
                  // Admin Direct: Edit Name
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      EditNameDialog.show(context, member, isDirectAdmin: true);
                    },
                    icon: const Icon(Icons.edit, size: 18, color: Colors.black),
                    label: Text(
                      loc.isUrdu ? 'براہ راست نام میں ترمیم' : 'Direct Edit Name',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Admin Direct: Edit Details
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      context.push('/admin/edit-member/${member.id}');
                    },
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: Text(
                      loc.isUrdu ? 'براہ راست تفصیلات کی ترمیم' : 'Direct Edit Details',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Admin Direct: Add Child
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                    ),
                    onPressed: () {
                      context.push('/admin/add-child/${member.id}');
                    },
                    icon: const Icon(Icons.person_add, size: 18, color: Colors.black),
                    label: Text(
                      loc.isUrdu ? 'براہ راست بچہ شامل کریں' : 'Direct Add Child',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),

                  // Admin Direct: Direct Photo Update
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
                        } catch (e) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(content: Text('Upload failed: $e')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.camera_alt, size: 18, color: AppColors.emerald),
                    label: Text(loc.isUrdu ? 'براہ راست تصویر تبدیل کریں' : 'Direct Photo Update'),
                  ),

                  // Admin Direct: Delete Permanently
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: AppColors.danger),
                      foregroundColor: AppColors.danger,
                    ),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: Row(
                            children: [
                              const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                              const SizedBox(width: 8),
                              Text(loc.isUrdu ? 'رکن مستقل حذف کریں؟' : 'Delete Member?'),
                            ],
                          ),
                          content: Text(
                            loc.isUrdu
                                ? 'کیا آپ واقعی "${member.localizedName(loc.locale.languageCode)}" کو شجرہ نسب سے مستقل طور پر حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں لیا جا سکتا۔'
                                : 'Are you sure you want to permanently delete "${member.localizedName(loc.locale.languageCode)}" from the family tree? This action cannot be undone.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: Text(loc.translate('cancel')),
                            ),
                            ElevatedButton(
                              style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                              onPressed: () => Navigator.pop(ctx, true),
                              child: Text(
                                loc.isUrdu ? 'مستقل حذف کریں' : 'Delete Permanently',
                                style: const TextStyle(color: Colors.white),
                              ),
                            ),
                          ],
                        ),
                      );

                      if (confirm == true && context.mounted) {
                        final messenger = ScaffoldMessenger.of(context);
                        final navigator = Navigator.of(context);
                        try {
                          await ref.read(familyRepositoryProvider).deleteMember(member.id);

                          await ref.read(auditLogRepositoryProvider).recordLog(
                            AuditLogModel(
                              logId: const Uuid().v4(),
                              action: 'direct_delete_member',
                              performedBy: currentUser?.uid ?? 'admin',
                              performedByName: currentUser?.name ?? 'Admin',
                              performedByRole: currentUser?.role.value ?? 'admin',
                              performedByPhone: currentUser?.phone,
                              targetMemberId: member.id,
                              targetMemberName: member.nameEn,
                              oldData: member.toJson(),
                              timestamp: DateTime.now(),
                            ),
                          );

                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.danger,
                              content: Text(
                                loc.isUrdu
                                    ? 'رکن کو شجرہ نسب سے مستقل طور پر حذف کر دیا گیا۔'
                                    : 'Member deleted permanently from the family tree.',
                              ),
                            ),
                          );
                          navigator.pop();
                        } catch (e) {
                          messenger.showSnackBar(
                            SnackBar(
                              backgroundColor: AppColors.danger,
                              content: Text('Failed to delete member: $e'),
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_forever, size: 18, color: AppColors.danger),
                    label: Text(
                      loc.isUrdu ? 'شجرہ سے مستقل حذف' : 'Delete Permanently',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ] else ...[
                  OutlinedButton.icon(
                    onPressed: () {
                      EditNameDialog.show(context, member);
                    },
                    icon: const Icon(Icons.edit, size: 18, color: AppColors.gold),
                    label: Text(
                      loc.isUrdu ? 'نام میں ترمیم (اردو/EN)' : 'Edit Name (EN/UR)',
                      style: const TextStyle(color: AppColors.goldLight),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      context.push('/edit-request/${member.id}');
                    },
                    icon: const Icon(Icons.edit_note, size: 18),
                    label: Text(loc.translate('suggest_edit')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      context.push('/request-add-child/${member.id}');
                    },
                    icon: const Icon(Icons.person_add, size: 18),
                    label: Text(loc.translate('request_add_child')),
                  ),
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

                          await ref.read(editRequestRepositoryProvider).submitRequest(
                            EditRequest(
                              requestId: '',
                              type: EditRequestType.uploadPicture,
                              memberId: member.id,
                              requestedBy: currentUser?.uid ?? 'guest_user',
                              requestedByName: currentUser?.name ?? 'Member',
                              requestedByPhone: currentUser?.phone,
                              changes: {'image_url': url},
                              reason: 'Updated portrait image for family tree.',
                              createdAt: DateTime.now(),
                            ),
                          );
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(content: Text('Picture submitted for Admin review!')),
                          );
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
            const SizedBox(height: 28),

            // Contact & Profile Details Card (Phone Number, Blood Group, Profession)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 20, color: AppColors.gold),
                        const SizedBox(width: 8),
                        Text(
                          loc.isUrdu ? 'رابطہ اور ذاتی تفصیلات' : 'Contact & Profile Details',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    _buildDetailTile(
                      icon: Icons.phone_outlined,
                      iconColor: AppColors.emerald,
                      title: loc.translate('phone_number'),
                      value: member.displayPhoneNumber,
                    ),
                    const Divider(height: 18),
                    _buildDetailTile(
                      icon: Icons.bloodtype_outlined,
                      iconColor: AppColors.danger,
                      title: loc.translate('blood_group'),
                      value: member.displayBloodGroup,
                    ),
                    const Divider(height: 18),
                    _buildDetailTile(
                      icon: Icons.work_outline,
                      iconColor: AppColors.info,
                      title: loc.translate('profession'),
                      value: member.displayProfession,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Personal Details Card (Lineage and Confidence removed per user requirement)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      loc.isUrdu ? 'ذاتی معلومات' : 'Personal Details',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.gold),
                    ),
                    const SizedBox(height: 12),
                    if (father != null) ...[
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: MemberAvatarWidget(member: father, radius: 18),
                        title: Text('${loc.translate("father")}: ${father.localizedName(loc.locale.languageCode)}'),
                        subtitle: Text(father.secondaryName(loc.locale.languageCode)),
                        trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                        onTap: () {
                          context.push('/member/${father.id}');
                        },
                      ),
                      const Divider(),
                    ],
                    _buildInfoRow('ID', member.id),
                    if (member.aliveStatus != AliveStatus.unknown)
                      _buildInfoRow(
                        loc.translate('status'),
                        isUrdu ? member.aliveStatus.labelUr : member.aliveStatus.labelEn,
                      ),
                    if (member.birthDate != null && member.birthDate!.isNotEmpty)
                      _buildInfoRow(loc.translate('birth_date'), member.birthDate!),
                    if (member.deathDate != null && member.deathDate!.isNotEmpty)
                      _buildInfoRow(loc.translate('death_date'), member.deathDate!),
                    if (member.notes != null && member.notes!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        loc.translate('notes'),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        member.notes!,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Children Section
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${loc.translate("children")} (${children.length})',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.emerald),
                        ),
                        TextButton.icon(
                          onPressed: () {
                            context.push('/request-add-child/${member.id}');
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: Text(loc.translate('add_child')),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (children.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          loc.translate('no_children'),
                          style: const TextStyle(color: AppColors.textLightSecondary, fontStyle: FontStyle.italic),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: children.length,
                        separatorBuilder: (_, _) => const Divider(color: AppColors.darkBorder),
                        itemBuilder: (context, index) {
                          final child = children[index];
                          return ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: MemberAvatarWidget(member: child, radius: 18),
                            title: Text(child.localizedName(loc.locale.languageCode)),
                            subtitle: Text(
                              '${child.secondaryName(loc.locale.languageCode)} • ${loc.translate("generation")} ${child.generation}',
                              style: const TextStyle(fontSize: 11),
                            ),
                            trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                            onTap: () {
                              context.push('/member/${child.id}');
                            },
                          );
                        },
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBadge(String label, Color bg, {Color? textColor}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: textColor ?? AppColors.textLightPrimary,
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textLightSecondary, fontSize: 13)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
        ],
      ),
    );
  }

  Widget _buildDetailTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String value,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, size: 20, color: iconColor),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: AppColors.textLightSecondary,
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _navigateToTree(
    WidgetRef ref,
    BuildContext context,
    FamilyMember member,
    Map<String, FamilyMember> membersMap,
  ) {
    // 1. Set global focus target provider
    ref.read(treeFocusTargetProvider.notifier).state = member.id;

    // 2. Select member in tree state
    final notifier = ref.read(familyTreeStateProvider.notifier);
    notifier.selectMember(member.id);

    // 3. Expand all ancestors up to root
    final ancestors = <String>{};
    String? curFather = member.fatherId;
    while (curFather != null && membersMap.containsKey(curFather)) {
      ancestors.add(curFather);
      curFather = membersMap[curFather]?.fatherId;
    }
    if (ancestors.isNotEmpty) {
      notifier.expandNodes(ancestors);
    }

    // 4. Expand member's own children
    if (member.childrenIds.isNotEmpty) {
      notifier.expandNodes([member.id]);
    }

    // 5. Navigate to Family Tree tab with query parameter
    context.go('/family-tree?focusMemberId=${member.id}');
  }
}
