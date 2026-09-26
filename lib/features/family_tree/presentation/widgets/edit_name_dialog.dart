import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../admin/models/audit_log_model.dart';
import '../../../admin/repositories/audit_log_repository.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../edit_requests/models/edit_request.dart';
import '../../../edit_requests/repositories/edit_request_repository.dart';
import '../../models/family_member.dart';
import '../../repositories/family_repository.dart';

/// Interactive dialog providing both English and Urdu name editing for any person in the family tree.
/// For normal users: includes 2-step review workflow with Admin selection for approval.
/// For admins in Admin Portal: applies changes directly and records audit log.
class EditNameDialog extends ConsumerStatefulWidget {
  final FamilyMember member;
  final bool isDirectAdmin;

  const EditNameDialog({
    super.key,
    required this.member,
    this.isDirectAdmin = false,
  });

  static Future<void> show(
    BuildContext context,
    FamilyMember member, {
    bool isDirectAdmin = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => EditNameDialog(
        member: member,
        isDirectAdmin: isDirectAdmin,
      ),
    );
  }

  @override
  ConsumerState<EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends ConsumerState<EditNameDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameEnController;
  late final TextEditingController _nameUrController;
  late final TextEditingController _reasonController;

  bool _isSaving = false;
  bool _isReviewing = false; // Step 2 review mode for normal user requests
  UserModel? _selectedAdmin;

  @override
  void initState() {
    super.initState();
    _nameEnController = TextEditingController(text: widget.member.nameEn);
    _nameUrController = TextEditingController(text: widget.member.nameUr);
    _reasonController = TextEditingController();
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameUrController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  /// Admin directly saves changes to family tree
  Future<void> _handleDirectAdminSave() async {
    if (!_formKey.currentState!.validate()) return;

    final newNameEn = _nameEnController.text.trim();
    final newNameUr = _nameUrController.text.trim();

    if (newNameEn == widget.member.nameEn && newNameUr == widget.member.nameUr) {
      Navigator.pop(context);
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    setState(() => _isSaving = true);

    try {
      final updated = widget.member.copyWith(
        nameEn: newNameEn,
        nameUr: newNameUr,
        updatedAt: DateTime.now(),
      );

      await ref.read(familyRepositoryProvider).saveMember(updated);

      await ref.read(auditLogRepositoryProvider).recordLog(
        AuditLogModel(
          logId: const Uuid().v4(),
          action: 'direct_edit_name',
          performedBy: currentUser?.uid ?? 'admin',
          performedByName: currentUser?.name ?? 'Admin',
          performedByRole: currentUser?.role.value ?? 'admin',
          performedByPhone: currentUser?.phone,
          targetMemberId: widget.member.id,
          targetMemberName: newNameEn,
          oldData: {
            'name_en': widget.member.nameEn,
            'name_ur': widget.member.nameUr,
          },
          newData: {
            'name_en': newNameEn,
            'name_ur': newNameUr,
          },
          timestamp: DateTime.now(),
        ),
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('Name updated successfully in family tree!'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error saving name: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Validates input and proceeds to Step 2 Review Summary
  void _proceedToReview() {
    if (!_formKey.currentState!.validate()) return;

    final newNameEn = _nameEnController.text.trim();
    final newNameUr = _nameUrController.text.trim();

    if (newNameEn == widget.member.nameEn && newNameUr == widget.member.nameUr) {
      final loc = AppLocalizations.of(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.isUrdu
                ? 'برائے مہربانی نام میں کم از کم ایک تبدیلی کریں'
                : 'Please make at least one change to the English or Urdu name.',
          ),
        ),
      );
      return;
    }

    setState(() => _isReviewing = true);
  }

  /// Submits the request after user reviews summary and selected Admin
  Future<void> _submitRequest() async {
    final loc = AppLocalizations.of(context);
    if (_selectedAdmin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            loc.isUrdu
                ? 'برائے مہربانی منظوری کے لیے ایک ایڈمن منتخب کریں'
                : 'Please select an Admin for approval.',
          ),
        ),
      );
      return;
    }

    final newNameEn = _nameEnController.text.trim();
    final newNameUr = _nameUrController.text.trim();
    final currentUser = ref.read(currentUserProvider);

    setState(() => _isSaving = true);

    try {
      final changes = <String, dynamic>{};
      final oldData = <String, dynamic>{
        'name_en': widget.member.nameEn,
        'name_ur': widget.member.nameUr,
      };
      final newData = <String, dynamic>{
        'name_en': newNameEn,
        'name_ur': newNameUr,
      };

      if (newNameEn != widget.member.nameEn) {
        changes['name_en'] = newNameEn;
      }
      if (newNameUr != widget.member.nameUr) {
        changes['name_ur'] = newNameUr;
      }

      final summaryBuf = StringBuffer();
      if (newNameEn != widget.member.nameEn) {
        summaryBuf.writeln('English Name: ${widget.member.nameEn} -> $newNameEn');
      }
      if (newNameUr != widget.member.nameUr) {
        summaryBuf.writeln('Urdu Name: ${widget.member.nameUr} -> $newNameUr');
      }

      final request = EditRequest(
        requestId: const Uuid().v4(),
        type: EditRequestType.editMember,
        memberId: widget.member.id,
        targetMemberName: widget.member.nameEn,
        requestedBy: currentUser?.uid ?? 'guest',
        requestedByName: currentUser?.name ?? 'Member',
        requestedByPhone: currentUser?.phone,
        selectedAdminId: _selectedAdmin!.uid,
        selectedAdminName: _selectedAdmin!.name,
        changes: changes,
        oldData: oldData,
        newData: newData,
        changesSummary: summaryBuf.toString().trim(),
        reason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : 'Name update request (English/Urdu)',
        createdAt: DateTime.now(),
      );

      await ref.read(editRequestRepositoryProvider).submitRequest(request);

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text(
              loc.isUrdu
                  ? 'نام میں تبدیلی کی درخواست ${_selectedAdmin!.name} کو بھیج دی گئی ہے!'
                  : 'Name change request submitted to ${_selectedAdmin!.name}!',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error submitting request: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final adminsAsync = ref.watch(adminUsersFutureProvider);
    final currentUser = ref.watch(currentUserProvider);
    final effectiveIsAdmin = widget.isDirectAdmin || (currentUser?.isAdmin ?? false);

    // If reviewing Step 2 (Normal user review summary)
    if (_isReviewing && !effectiveIsAdmin) {
      return _buildReviewDialog(context, loc, isUrdu, isDark, adminsAsync, currentUser);
    }

    // Step 1 Form Dialog
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.gold.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit, color: AppColors.gold, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUrdu ? 'نام میں ترمیم' : 'Edit Person Name',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  isUrdu ? 'اردو اور انگریزی دونوں نام سپورٹ ہیں' : 'Edit English and/or Urdu Name',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Member Card Info
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                    ),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.person, size: 18, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.member.nameEn} (${widget.member.nameUr})',
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // English Name Field
                TextFormField(
                  controller: _nameEnController,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: '${loc.translate("name_en")} (English)',
                    hintText: 'e.g. Muhammad Ali Khan',
                    prefixIcon: const Icon(Icons.badge_outlined, color: AppColors.emerald),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'English name is required';
                    }
                    if (v.trim().length < 2) {
                      return 'Name is too short';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Urdu Name Field
                TextFormField(
                  controller: _nameUrController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: '${loc.translate("name_ur")} (اردو نام)',
                    hintText: 'مثلاً: محمد علی خان',
                    prefixIcon: const Icon(Icons.badge, color: AppColors.gold),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'اردو نام لازمی ہے';
                    }
                    if (v.trim().length < 2) {
                      return 'نام بہت مختصر ہے';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Optional Reason field
                TextFormField(
                  controller: _reasonController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: isUrdu ? 'ترمیم کی وجہ (اختیاری)' : 'Reason (Optional)',
                    hintText: isUrdu ? 'مثلاً: ہجے کی درستی' : 'e.g. Spelling correction',
                    prefixIcon: const Icon(Icons.help_outline),
                    filled: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),

                // Mode banner
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                  decoration: BoxDecoration(
                    color: effectiveIsAdmin
                        ? AppColors.emerald.withValues(alpha: 0.12)
                        : AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        effectiveIsAdmin ? Icons.verified_user : Icons.info_outline,
                        size: 16,
                        color: effectiveIsAdmin ? AppColors.emerald : AppColors.gold,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          effectiveIsAdmin
                              ? (isUrdu
                                  ? 'ایڈمن پورٹل: نام میں تبدیلی فوری طور پر محفوظ ہو جائے گی۔'
                                  : 'Admin Direct Mode: Name will be updated immediately.')
                              : (isUrdu
                                  ? 'نام کی تبدیلی کے لیے ایڈمن کا انتخاب کریں اور جائزہ لیں۔'
                                  : 'Next step: Select an Admin for approval and review request.'),
                          style: const TextStyle(fontSize: 11),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(loc.translate('cancel')),
        ),
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: effectiveIsAdmin ? AppColors.emerald : AppColors.gold,
            foregroundColor: Colors.black,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving
              ? null
              : (effectiveIsAdmin ? _handleDirectAdminSave : _proceedToReview),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                )
              : Icon(effectiveIsAdmin ? Icons.check_circle : Icons.arrow_forward, size: 18),
          label: Text(
            _isSaving
                ? (isUrdu ? 'محفوظ ہو رہا ہے...' : 'Saving...')
                : (effectiveIsAdmin
                    ? (isUrdu ? 'براہ راست محفوظ کریں' : 'Save Name Directly')
                    : (isUrdu ? 'جائزہ لیں (Review)' : 'Review Request')),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }

  /// Step 2 Dialog: Request Summary + Select Admin + Back / Edit Request / Submit Request
  Widget _buildReviewDialog(
    BuildContext context,
    AppLocalizations loc,
    bool isUrdu,
    bool isDark,
    AsyncValue<List<UserModel>> adminsAsync,
    UserModel? currentUser,
  ) {
    final newNameEn = _nameEnController.text.trim();
    final newNameUr = _nameUrController.text.trim();

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.rate_review_outlined, color: AppColors.emerald, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  isUrdu ? 'درخواست کا جائزہ' : 'Request Summary',
                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  isUrdu ? 'تبدیلیوں کی تصدیق کریں اور ایڈمن منتخب کریں' : 'Review changes & select approval Admin',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Target Member Card
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      isUrdu ? 'رکن (Member):' : 'Member:',
                      style: const TextStyle(fontSize: 11.5, color: AppColors.textLightSecondary, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${widget.member.nameEn} (${widget.member.nameUr})',
                      style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              Text(
                isUrdu ? 'تبدیلیاں (Changes):' : 'Changes:',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              // English Name Old vs New Card
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: newNameEn != widget.member.nameEn
                        ? AppColors.emerald.withValues(alpha: 0.4)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge_outlined, size: 16, color: AppColors.emerald),
                        const SizedBox(width: 6),
                        Text(
                          isUrdu ? 'انگریزی نام (English Name)' : 'English Name',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          isUrdu ? 'پرانا (Old): ' : 'Old: ',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textLightSecondary),
                        ),
                        Expanded(
                          child: Text(
                            widget.member.nameEn,
                            style: const TextStyle(
                              fontSize: 12.5,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          isUrdu ? 'نیا (New): ' : 'New: ',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.emeraldLight,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            newNameEn,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.emeraldLight,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Urdu Name Old vs New Card
              Container(
                margin: const EdgeInsets.only(bottom: 14),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: isDark ? AppColors.darkSurface : Colors.grey.shade50,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: newNameUr != widget.member.nameUr
                        ? AppColors.gold.withValues(alpha: 0.4)
                        : (isDark ? AppColors.darkBorder : AppColors.lightBorder),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.badge, size: 16, color: AppColors.gold),
                        const SizedBox(width: 6),
                        Text(
                          isUrdu ? 'اردو نام (Urdu Name)' : 'Urdu Name',
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      children: [
                        Text(
                          isUrdu ? 'پرانا (Old): ' : 'Old: ',
                          style: const TextStyle(fontSize: 11.5, color: AppColors.textLightSecondary),
                        ),
                        Expanded(
                          child: Text(
                            widget.member.nameUr,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 12.5,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          isUrdu ? 'نیا (New): ' : 'New: ',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AppColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            newNameUr,
                            textDirection: TextDirection.rtl,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Select Admin for Approval
              Text(
                isUrdu ? 'منظوری کے لیے ایڈمن منتخب کریں:' : 'Select Admin for Approval',
                style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),

              adminsAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => Text('Error loading admins: $e', style: const TextStyle(color: AppColors.danger)),
                data: (allAdmins) {
                  // Filter out normal users, requesting user, and inactive/blocked accounts
                  final validAdmins = allAdmins
                      .where((a) =>
                          a.uid != currentUser?.uid &&
                          a.isAdmin &&
                          !a.status.isBlocked)
                      .toList();

                  final displayAdmins = validAdmins.isNotEmpty ? validAdmins : allAdmins;

                  if (_selectedAdmin == null && displayAdmins.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedAdmin = displayAdmins.first);
                    });
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold),
                      borderRadius: BorderRadius.circular(12),
                      color: isDark ? AppColors.darkSurface : Colors.white,
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<UserModel>(
                        isExpanded: true,
                        value: displayAdmins.contains(_selectedAdmin)
                            ? _selectedAdmin
                            : (displayAdmins.isNotEmpty ? displayAdmins.first : null),
                        hint: Text(
                          isUrdu ? 'ایڈمن منتخب کریں ▼' : 'Select Admin ▼',
                          style: const TextStyle(fontSize: 13),
                        ),
                        items: displayAdmins.map((adm) {
                          return DropdownMenuItem<UserModel>(
                            value: adm,
                            child: Row(
                              children: [
                                Icon(
                                  adm.role.isSuperAdmin ? Icons.shield : Icons.security,
                                  size: 18,
                                  color: adm.role.isSuperAdmin ? AppColors.gold : AppColors.emerald,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        adm.name,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (adm.email.isNotEmpty)
                                        Text(
                                          adm.email,
                                          style: const TextStyle(fontSize: 10.5, color: AppColors.textLightSecondary),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) setState(() => _selectedAdmin = val);
                        },
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        // 1. Back button (dismisses dialog)
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context),
          child: Text(
            isUrdu ? 'واپس' : 'Back',
            style: TextStyle(
              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
            ),
          ),
        ),

        // 2. Edit Request button (returns to Step 1 Form to modify)
        OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppColors.gold),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : () => setState(() => _isReviewing = false),
          child: Text(
            isUrdu ? 'ترمیم کریں' : 'Edit Request',
            style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
          ),
        ),

        // 3. Submit Request button (final submission)
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.emerald,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: _isSaving ? null : _submitRequest,
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.send, size: 16),
          label: Text(
            _isSaving
                ? (isUrdu ? 'بھیجا جا رہا ہے...' : 'Submitting...')
                : (isUrdu ? 'درخواست جمع کریں' : 'Submit Request'),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
