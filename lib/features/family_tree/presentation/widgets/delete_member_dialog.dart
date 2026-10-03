import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../admin/models/audit_log_model.dart';
import '../../../admin/repositories/audit_log_repository.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/family_member.dart';
import '../../repositories/family_repository.dart';

class DeleteMemberDialog {
  /// Confirms and cascadingly deletes [member] and all descendants.
  /// Enforces rule: Normal Admin can only delete if descendant depth <= 3.
  /// Super Admin can delete any depth.
  static Future<bool> show(
    BuildContext context,
    WidgetRef ref,
    FamilyMember member,
  ) async {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final repo = ref.read(familyRepositoryProvider);
    final currentUser = ref.read(currentUserProvider);
    final isSuperAdmin = currentUser?.isSuperAdmin ?? false;

    final depth = repo.getDescendantDepth(member.id);
    final descendantIds = repo.getAllDescendantIds(member.id);
    final totalDescendants = descendantIds.length;
    final directChildrenCount = member.childrenIds.length;

    // 1. Permission check: Admin cannot delete if depth > 3
    if (!isSuperAdmin && depth > 3) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Row(
            children: [
              const Icon(Icons.block, color: AppColors.danger, size: 26),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  isUrdu ? 'حذف کرنے کی اجازت نہیں' : 'Cannot Delete Member',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                ),
              ),
            ],
          ),
          content: Text(
            isUrdu
              ? 'اس فرد کے نیچے $depth پشتیں (کل $totalDescendants افراد) موجود ہیں۔\n\nایڈمن صرف 3 یا اس سے کم پشتوں والے افراد کو حذف کر سکتے ہیں۔ اس پوری شاخ کو حذف کرنے کا اختیار صرف سپر ایڈمن کے پاس ہے۔'
              : 'This person has $depth generations below them (total $totalDescendants descendants).\n\nAdmins can only delete members with 3 generations or fewer below them. Only a Super Admin can delete this branch.',
            style: const TextStyle(fontSize: 14),
          ),
          actions: [
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.emerald),
              onPressed: () => Navigator.pop(ctx),
              child: Text(isUrdu ? 'سمجھ آ گیا' : 'Understood', style: const TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      return false;
    }

    // 2. Confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                isUrdu ? 'رکن مستقل حذف کریں؟' : 'Delete Family Member?',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isUrdu
                  ? 'کیا آپ واقعی "${member.localizedName(loc.locale.languageCode)}" کو حذف کرنا چاہتے ہیں؟'
                  : 'Are you sure you want to permanently delete "${member.localizedName(loc.locale.languageCode)}"?',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUrdu
                        ? 'اس فرد کے $directChildrenCount براہ راست بچے اور کل $totalDescendants اولادیں/نسلیں ہیں۔'
                        : 'This person has $directChildrenCount direct children and $totalDescendants total descendants.',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    isUrdu
                        ? 'اس فرد کو حذف کرنے سے ان کی تمام اولادیں بھی شجرہ نسب سے خارج ہو جائیں گی۔ کوئی لاوارث شاخ نہیں بچے گی۔'
                        : 'Deleting this person will also remove their descendants. No orphaned children will remain in the tree.',
                    style: const TextStyle(fontSize: 12, color: AppColors.danger),
                  ),
                ],
              ),
            ),
            if (isSuperAdmin && depth > 3) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.security, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        isUrdu
                            ? 'انتباہ برائے سپر ایڈمن: آپ ایک گہری شاخ ($depth پشتیں، $totalDescendants افراد) حذف کر رہے ہیں۔'
                            : 'Super Admin Warning: You are deleting a large branch with $depth generations and $totalDescendants descendants.',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.amber),
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Text(
              isUrdu ? 'کیا آپ کو یقین ہے؟' : 'Are you sure?',
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isUrdu ? 'مستقل حذف کریں' : 'Delete Permanently',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      final messenger = ScaffoldMessenger.of(context);
      final auditRepo = ref.read(auditLogRepositoryProvider);
      final currentUid = currentUser?.uid ?? 'admin';
      final currentName = currentUser?.name ?? 'Admin';
      final currentRole = currentUser?.role.value ?? 'admin';
      final currentPhone = currentUser?.phone;

      try {
        await repo.deleteMember(member.id, isSuperAdmin: isSuperAdmin);

        // Record Audit Log safely without referencing widget ref after disposal
        try {
          await auditRepo.recordLog(
            AuditLogModel(
              logId: const Uuid().v4(),
              action: 'direct_delete_member',
              performedBy: currentUid,
              performedByName: currentName,
              performedByRole: currentRole,
              performedByPhone: currentPhone,
              targetMemberId: member.id,
              targetMemberName: member.nameEn,
              oldData: member.toJson(),
              details: 'Deleted member and $totalDescendants descendants (depth: $depth generations).',
              timestamp: DateTime.now(),
            ),
          );
        } catch (auditErr) {
          debugPrint('Secondary audit log error after delete: $auditErr');
        }

        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(
              isUrdu
                  ? 'رکن اور ان کی تمام اولادیں ($totalDescendants افراد) شجرہ نسب سے حذف کر دی گئیں۔'
                  : 'Member and all descendants ($totalDescendants members) permanently deleted.',
            ),
          ),
        );
        return true;
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Failed to delete member: $e'),
          ),
        );
        return false;
      }
    }
    return false;
  }
}
