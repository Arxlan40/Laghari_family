import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../edit_requests/models/edit_request.dart';
import '../../../edit_requests/repositories/edit_request_repository.dart';
import '../../../family_tree/models/family_member.dart';
import '../../../family_tree/providers/family_tree_providers.dart';

class PendingRequestsScreen extends ConsumerWidget {
  const PendingRequestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final pendingAsync = ref.watch(pendingRequestsStreamProvider);
    final currentUser = ref.watch(currentUserProvider);
    final membersMap = ref.watch(familyMembersMapProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('pending_requests')),
      ),
      body: pendingAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
        error: (err, stack) => Center(child: Text('Error loading requests: $err')),
        data: (requests) {
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: AppColors.emerald),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('no_requests'),
                    style: const TextStyle(fontSize: 16, color: AppColors.textLightSecondary),
                  ),
                ],
              ),
            );
          }

          // If normal admin, filter requests assigned to this admin (or unassigned)
          final filteredRequests = requests.where((r) {
            if (currentUser?.isSuperAdmin == true) return true;
            if (r.selectedAdminId != null && r.selectedAdminId!.isNotEmpty) {
              return r.selectedAdminId == currentUser?.uid;
            }
            return true;
          }).toList();

          if (filteredRequests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.check_circle_outline, size: 64, color: AppColors.emerald),
                  const SizedBox(height: 16),
                  Text(
                    loc.translate('no_requests'),
                    style: const TextStyle(fontSize: 16, color: AppColors.textLightSecondary),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: filteredRequests.length,
            itemBuilder: (context, index) {
              final req = filteredRequests[index];
              final targetMember = req.memberId != null ? membersMap[req.memberId] : null;

              return Card(
                margin: const EdgeInsets.only(bottom: 20),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header: Type badge & Date/Time
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: req.type == EditRequestType.addChild
                                  ? AppColors.emerald.withValues(alpha: 0.15)
                                  : AppColors.gold.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color: req.type == EditRequestType.addChild
                                    ? AppColors.emerald
                                    : AppColors.gold,
                                width: 0.8,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  req.type == EditRequestType.addChild ? Icons.person_add : Icons.edit,
                                  size: 13,
                                  color: req.type == EditRequestType.addChild
                                      ? AppColors.emeraldLight
                                      : AppColors.goldLight,
                                ),
                                const SizedBox(width: 5),
                                Text(
                                  loc.isUrdu ? req.type.labelUr : req.type.labelEn,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    color: req.type == EditRequestType.addChild
                                        ? AppColors.emeraldLight
                                        : AppColors.goldLight,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Text(
                            '${req.createdAt.day}/${req.createdAt.month}/${req.createdAt.year} ${req.createdAt.hour}:${req.createdAt.minute.toString().padLeft(2, '0')}',
                            style: const TextStyle(fontSize: 11, color: AppColors.textLightSecondary),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // 1. Detailed Requester Profile Card
                      _buildRequesterProfileCard(context, ref, req, loc),
                      const SizedBox(height: 14),

                      // Assigned Admin info (if specified)
                      if (req.selectedAdminName != null && req.selectedAdminName!.isNotEmpty)
                        Container(
                          margin: const EdgeInsets.only(bottom: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.gold.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.admin_panel_settings, size: 15, color: AppColors.gold),
                              const SizedBox(width: 6),
                              Text(
                                '${loc.translate("selected_admin")}: ',
                                style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
                              ),
                              Text(
                                req.selectedAdminName!,
                                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.goldLight),
                              ),
                            ],
                          ),
                        ),

                      // Reason Container (if provided)
                      if (req.reason.isNotEmpty)
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(10),
                          margin: const EdgeInsets.only(bottom: 14),
                          decoration: BoxDecoration(
                            color: AppColors.darkBackground,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.darkBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${loc.translate("reason")}:',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textLightSecondary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                req.reason,
                                style: const TextStyle(fontStyle: FontStyle.italic, fontSize: 12),
                              ),
                            ],
                          ),
                        ),

                      // 2. Information Display:
                      // If child is added: show complete new child profile without strikethroughs
                      // If member is edited: show old -> new comparison
                      if (req.type == EditRequestType.addChild)
                        _buildNewChildInfoCard(req, targetMember, loc)
                      else
                        _buildEditChangesCard(req, targetMember, loc),

                      const SizedBox(height: 18),

                      // 3. Approve / Reject Action Buttons
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          // Reject Button
                          OutlinedButton(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.danger,
                              side: const BorderSide(color: AppColors.danger),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              final reasonCtrl = TextEditingController();
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: Text(loc.translate('reject_request')),
                                  content: Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(loc.translate('rejection_reason_optional')),
                                      const SizedBox(height: 12),
                                      TextField(
                                        controller: reasonCtrl,
                                        decoration: InputDecoration(
                                          hintText: loc.isUrdu
                                              ? 'مثلاً: معلومات کی تصدیق نہیں ہو سکی'
                                              : 'e.g. Inaccurate information',
                                        ),
                                      ),
                                    ],
                                  ),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(loc.translate('cancel'))),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                      onPressed: () => Navigator.pop(ctx, true),
                                      child: Text(loc.translate('reject')),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true) {
                                await ref.read(editRequestRepositoryProvider).rejectRequest(
                                      requestId: req.requestId,
                                      reviewerUid: currentUser?.uid ?? 'admin',
                                      reviewerName: currentUser?.name ?? 'Admin',
                                      reviewerRole: currentUser?.role.value ?? 'admin',
                                      reason: reasonCtrl.text.trim().isNotEmpty
                                          ? reasonCtrl.text.trim()
                                          : 'Request did not meet verification criteria.',
                                    );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      backgroundColor: AppColors.danger,
                                      content: Text(loc.translate('rejected')),
                                    ),
                                  );
                                }
                              }
                            },
                            child: Text(loc.translate('reject')),
                          ),
                          const SizedBox(width: 12),

                          // Approve Button
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                            onPressed: () async {
                              await ref.read(editRequestRepositoryProvider).approveRequest(
                                    requestId: req.requestId,
                                    reviewerUid: currentUser?.uid ?? 'admin',
                                    reviewerName: currentUser?.name ?? 'Admin',
                                    reviewerRole: currentUser?.role.value ?? 'admin',
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.emerald,
                                    content: Text(loc.translate('approved')),
                                  ),
                                );
                              }
                            },
                            child: Text(loc.translate('approve')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  /// Builds a rich requester profile card with avatar, name, father name, phone, email, and address
  Widget _buildRequesterProfileCard(
    BuildContext context,
    WidgetRef ref,
    EditRequest req,
    AppLocalizations loc,
  ) {
    final requesterAsync = ref.watch(userProfileFutureProvider(req.requestedBy));
    final requester = requesterAsync.valueOrNull;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.darkBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.darkBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // Requester Avatar / Profile Image
              CircleAvatar(
                radius: 22,
                backgroundColor: AppColors.emerald.withValues(alpha: 0.2),
                backgroundImage: (requester?.profileImageUrl != null &&
                        requester!.profileImageUrl.isNotEmpty)
                    ? NetworkImage(requester.profileImageUrl)
                    : null,
                child: (requester?.profileImageUrl == null ||
                        requester!.profileImageUrl.isEmpty)
                    ? Text(
                        (req.requestedByName.isNotEmpty ? req.requestedByName[0] : 'U')
                            .toUpperCase(),
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          color: AppColors.emeraldLight,
                          fontSize: 16,
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            requester?.name ?? req.requestedByName,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            loc.translate('requester'),
                            style: const TextStyle(
                              fontSize: 10,
                              color: AppColors.emeraldLight,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (requester != null && requester.fatherName.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '${loc.translate("father")}: ${requester.fatherName}',
                          style: const TextStyle(fontSize: 11, color: AppColors.textLightSecondary),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          const Divider(height: 1, color: AppColors.darkBorder),
          const SizedBox(height: 8),

          // Contact Details: Phone, Email, Address
          if (requester != null) ...[
            Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                // Phone
                if (requester.phone.isNotEmpty)
                  InkWell(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: requester.phone));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Phone number copied: ${requester.phone}')),
                      );
                    },
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.phone, size: 14, color: AppColors.gold),
                        const SizedBox(width: 4),
                        Text(
                          requester.phone,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.goldLight,
                          ),
                        ),
                      ],
                    ),
                  ),

                // Email
                if (requester.email.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.email, size: 14, color: AppColors.textLightSecondary),
                      const SizedBox(width: 4),
                      Text(
                        requester.email,
                        style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
                      ),
                    ],
                  ),

                // Address
                if (requester.address.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.location_on, size: 14, color: AppColors.textLightSecondary),
                      const SizedBox(width: 4),
                      Text(
                        requester.address,
                        style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
                      ),
                    ],
                  ),

                // Blood Group
                if (requester.bloodGroup.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.bloodtype, size: 14, color: AppColors.danger),
                      const SizedBox(width: 4),
                      Text(
                        requester.bloodGroup,
                        style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
                      ),
                    ],
                  ),
              ],
            ),
          ] else ...[
            Row(
              children: [
                const Icon(Icons.badge, size: 14, color: AppColors.textLightSecondary),
                const SizedBox(width: 6),
                Text(
                  'User ID: ${req.requestedBy}',
                  style: const TextStyle(fontSize: 11, color: AppColors.textLightSecondary),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  /// Builds a dedicated New Child Information card showing ONLY new child details (no cancel lines)
  Widget _buildNewChildInfoCard(
    EditRequest req,
    FamilyMember? father,
    AppLocalizations loc,
  ) {
    final changes = req.changes;
    final childPhoto = changes['image_url']?.toString();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.child_care, color: AppColors.emeraldLight, size: 18),
            const SizedBox(width: 6),
            Text(
              loc.translate('new_child_info'),
              style: const TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 13,
                color: AppColors.emeraldLight,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.darkBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.4)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Child name and photo row
              Row(
                children: [
                  if (childPhoto != null && childPhoto.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          childPhoto,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          changes['name_en']?.toString() ?? 'New Child',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textLightPrimary,
                          ),
                        ),
                        if (changes['name_ur'] != null && changes['name_ur'].toString().isNotEmpty)
                          Text(
                            changes['name_ur'].toString(),
                            style: const TextStyle(fontSize: 14, color: AppColors.goldLight),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: AppColors.darkBorder),
              const SizedBox(height: 10),

              // Father row
              _buildDetailRow(
                icon: Icons.escalator_warning,
                label: loc.translate('father'),
                value: father != null
                    ? '${father.nameEn} (${father.nameUr})'
                    : (req.targetMemberName ?? 'Father ID: ${req.memberId}'),
                isHighlighted: true,
              ),

              // Badges: Gender, Generation, Alive Status
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (changes.containsKey('gender'))
                      _buildBadge(
                        changes['gender'] == 'female' ? loc.translate('female') : loc.translate('male'),
                        changes['gender'] == 'female' ? AppColors.femaleAccent : AppColors.maleAccent,
                      ),
                    if (changes.containsKey('generation'))
                      _buildBadge(
                        '${loc.translate("generation")} ${changes["generation"]}',
                        AppColors.darkCard,
                      ),
                    if (changes.containsKey('alive_status'))
                      _buildBadge(
                        changes['alive_status'].toString().toUpperCase(),
                        AppColors.aliveColor,
                      ),
                  ],
                ),
              ),

              // Birth Date
              if (changes.containsKey('birth_date') && changes['birth_date'].toString().isNotEmpty)
                _buildDetailRow(
                  icon: Icons.cake,
                  label: loc.translate('birth_date'),
                  value: changes['birth_date'].toString(),
                ),

              // Death Date
              if (changes.containsKey('death_date') && changes['death_date'].toString().isNotEmpty)
                _buildDetailRow(
                  icon: Icons.event_busy,
                  label: loc.translate('death_date'),
                  value: changes['death_date'].toString(),
                ),

              // Phone Number
              if (changes.containsKey('phone_number') && changes['phone_number'].toString().isNotEmpty)
                _buildDetailRow(
                  icon: Icons.phone,
                  label: loc.translate('phone_number'),
                  value: changes['phone_number'].toString(),
                ),

              // Blood Group
              if (changes.containsKey('blood_group') && changes['blood_group'].toString().isNotEmpty)
                _buildDetailRow(
                  icon: Icons.bloodtype,
                  label: loc.translate('blood_group'),
                  value: changes['blood_group'].toString(),
                ),

              // Profession
              if (changes.containsKey('profession') && changes['profession'].toString().isNotEmpty)
                _buildDetailRow(
                  icon: Icons.work,
                  label: loc.translate('profession'),
                  value: changes['profession'].toString(),
                ),

              // Notes
              if (changes.containsKey('notes') && changes['notes'].toString().isNotEmpty)
                _buildDetailRow(
                  icon: Icons.note,
                  label: loc.translate('notes'),
                  value: changes['notes'].toString(),
                ),
            ],
          ),
        ),
      ],
    );
  }

  /// Builds a diff comparison card showing old vs new values for edited members
  Widget _buildEditChangesCard(
    EditRequest req,
    FamilyMember? targetMember,
    AppLocalizations loc,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (targetMember != null || (req.targetMemberName != null && req.targetMemberName!.isNotEmpty))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(Icons.person, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  '${loc.translate("target_member")}: ',
                  style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
                ),
                Text(
                  req.targetMemberName ?? targetMember?.localizedName(loc.locale.languageCode) ?? '',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.goldLight),
                ),
              ],
            ),
          ),
        Text(
          '${loc.translate("changes")}:',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.emerald),
        ),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.darkBackground,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppColors.darkBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: req.changes.entries.map((entry) {
              final key = entry.key;
              final newVal = entry.value;
              dynamic oldVal;
              if (req.oldData.containsKey(key)) {
                oldVal = req.oldData[key];
              } else if (targetMember != null) {
                final json = targetMember.toJson();
                oldVal = json[key];
              }

              // Special preview for uploaded photo URL
              if (key == 'image_url' && newVal is String && newVal.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(
                    children: [
                      const Text('New Photo: ', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(width: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(newVal, width: 50, height: 50, fit: BoxFit.cover),
                      ),
                    ],
                  ),
                );
              }

              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$key: ',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: AppColors.goldLight),
                    ),
                    if (oldVal != null) ...[
                      Text(
                        '$oldVal',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.danger,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                      const Text(' → ', style: TextStyle(fontSize: 12)),
                    ],
                    Expanded(
                      child: Text(
                        '$newVal',
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.emeraldLight,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow({
    required IconData icon,
    required String label,
    required String value,
    bool isHighlighted = false,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 15, color: isHighlighted ? AppColors.gold : AppColors.textLightSecondary),
          const SizedBox(width: 6),
          Text(
            '$label: ',
            style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: 12,
                fontWeight: isHighlighted ? FontWeight.bold : FontWeight.w600,
                color: isHighlighted ? AppColors.goldLight : AppColors.textLightPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.5), width: 0.8),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
