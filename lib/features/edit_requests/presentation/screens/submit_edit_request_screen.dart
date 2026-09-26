import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../admin/models/audit_log_model.dart';
import '../../../admin/repositories/audit_log_repository.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family_tree/models/family_member.dart';
import '../../../family_tree/providers/family_tree_providers.dart';
import '../../../family_tree/repositories/family_repository.dart';
import '../../models/edit_request.dart';
import '../../repositories/edit_request_repository.dart';

class SubmitEditRequestScreen extends ConsumerStatefulWidget {
  final String memberId;
  final bool isDirectAdmin;

  const SubmitEditRequestScreen({
    super.key,
    required this.memberId,
    this.isDirectAdmin = false,
  });

  @override
  ConsumerState<SubmitEditRequestScreen> createState() =>
      _SubmitEditRequestScreenState();
}

class _SubmitEditRequestScreenState
    extends ConsumerState<SubmitEditRequestScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameEnController;
  late TextEditingController _nameUrController;
  late TextEditingController _birthDateController;
  late TextEditingController _deathDateController;
  late TextEditingController _phoneController;
  late TextEditingController _professionController;
  late TextEditingController _sectionController;
  late TextEditingController _notesController;
  late TextEditingController _reasonController;

  String _gender = 'male';
  String _bloodGroup = 'Unknown';
  AliveStatus _aliveStatus = AliveStatus.unknown;

  bool _isSubmitting = false;
  bool _isReviewing = false; // Step 2 for Normal Users
  UserModel? _selectedAdmin;

  // Stored differences for review
  final Map<String, dynamic> _changedOldValues = {};
  final Map<String, dynamic> _changedNewValues = {};

  static const List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  @override
  void initState() {
    super.initState();
    _nameEnController = TextEditingController();
    _nameUrController = TextEditingController();
    _birthDateController = TextEditingController();
    _deathDateController = TextEditingController();
    _phoneController = TextEditingController();
    _professionController = TextEditingController();
    _sectionController = TextEditingController();
    _notesController = TextEditingController();
    _reasonController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final member = ref.read(familyMembersMapProvider)[widget.memberId];
    if (member != null &&
        _nameEnController.text.isEmpty &&
        _nameUrController.text.isEmpty) {
      _nameEnController.text = member.nameEn;
      _nameUrController.text = member.nameUr;
      _birthDateController.text = member.birthDate ?? '';
      _deathDateController.text = member.deathDate ?? '';
      _phoneController.text = member.phoneNumber ?? '';
      _professionController.text = member.profession ?? '';
      _sectionController.text = member.section ?? '';
      _notesController.text = member.notes ?? '';
      _gender = member.gender;
      _aliveStatus = member.aliveStatus;
      if (member.bloodGroup != null &&
          _bloodGroupOptions.contains(member.bloodGroup)) {
        _bloodGroup = member.bloodGroup!;
      }
    }
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameUrController.dispose();
    _birthDateController.dispose();
    _deathDateController.dispose();
    _phoneController.dispose();
    _professionController.dispose();
    _sectionController.dispose();
    _notesController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  /// Calculates differences between existing member data and edited fields
  bool _calculateChanges(FamilyMember member, {required bool isAdmin}) {
    _changedOldValues.clear();
    _changedNewValues.clear();

    if (_nameEnController.text.trim() != member.nameEn) {
      _changedOldValues['name_en'] = member.nameEn;
      _changedNewValues['name_en'] = _nameEnController.text.trim();
    }
    if (_nameUrController.text.trim() != member.nameUr) {
      _changedOldValues['name_ur'] = member.nameUr;
      _changedNewValues['name_ur'] = _nameUrController.text.trim();
    }
    if (isAdmin && _gender != member.gender) {
      _changedOldValues['gender'] = member.gender;
      _changedNewValues['gender'] = _gender;
    }

    if (_aliveStatus != member.aliveStatus) {
      _changedOldValues['alive_status'] = member.aliveStatus.name;
      _changedNewValues['alive_status'] = _aliveStatus.toDbValue();
    }
    if (_birthDateController.text.trim() != (member.birthDate ?? '')) {
      _changedOldValues['birth_date'] = member.birthDate ?? 'Unknown';
      _changedNewValues['birth_date'] = _birthDateController.text.trim();
    }
    if (_deathDateController.text.trim() != (member.deathDate ?? '')) {
      _changedOldValues['death_date'] = member.deathDate ?? 'Unknown';
      _changedNewValues['death_date'] = _deathDateController.text.trim();
    }
    if (_phoneController.text.trim() != (member.phoneNumber ?? '')) {
      _changedOldValues['phone_number'] = member.phoneNumber ?? 'None';
      _changedNewValues['phone_number'] = _phoneController.text.trim();
    }
    if (_bloodGroup != (member.bloodGroup ?? 'Unknown')) {
      _changedOldValues['blood_group'] = member.bloodGroup ?? 'Unknown';
      _changedNewValues['blood_group'] = _bloodGroup;
    }
    if (_professionController.text.trim() != (member.profession ?? '')) {
      _changedOldValues['profession'] = member.profession ?? 'None';
      _changedNewValues['profession'] = _professionController.text.trim();
    }
    if (_sectionController.text.trim() != (member.section ?? '')) {
      _changedOldValues['section'] = member.section ?? 'None';
      _changedNewValues['section'] = _sectionController.text.trim();
    }
    if (_notesController.text.trim() != (member.notes ?? '')) {
      _changedOldValues['notes'] = member.notes ?? '';
      _changedNewValues['notes'] = _notesController.text.trim();
    }

    return _changedNewValues.isNotEmpty;
  }

  /// Admin directly applies changes without creating an edit request
  Future<void> _handleDirectAdminSave(FamilyMember member, UserModel admin) async {
    if (!_formKey.currentState!.validate()) return;
    if (!_calculateChanges(member, isAdmin: true)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No changes detected.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final updated = member.copyWith(
        nameEn: _nameEnController.text.trim(),
        nameUr: _nameUrController.text.trim(),
        gender: _gender,
        aliveStatus: _aliveStatus,
        birthDate: _birthDateController.text.trim().isEmpty ? null : _birthDateController.text.trim(),
        deathDate: _deathDateController.text.trim().isEmpty ? null : _deathDateController.text.trim(),
        phoneNumber: _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        bloodGroup: _bloodGroup,
        profession: _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
        section: _sectionController.text.trim().isEmpty ? null : _sectionController.text.trim(),
        notes: _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
      );

      // Save directly to repository (memory, local storage file, Firestore)
      await ref.read(familyRepositoryProvider).saveMember(updated);

      // Record in Audit Log
      await ref.read(auditLogRepositoryProvider).recordLog(
        AuditLogModel(
          logId: const Uuid().v4(),
          action: 'direct_edit',
          performedBy: admin.uid,
          performedByName: admin.name,
          performedByRole: admin.role.value,
          performedByPhone: admin.phone,
          targetMemberId: member.id,
          targetMemberName: member.nameEn,
          oldData: Map.from(_changedOldValues),
          newData: Map.from(_changedNewValues),
          timestamp: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('Family member updated directly and logged in audit history.'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Normal User proceeds to Step 2 (Review Summary)
  void _proceedToReview(FamilyMember member) {
    if (!_formKey.currentState!.validate()) return;
    final hasChanges = _calculateChanges(member, isAdmin: false);
    if (!hasChanges) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please make at least one change before reviewing.')),
      );
      return;
    }
    setState(() => _isReviewing = true);
  }

  /// Normal User submits the reviewed request
  Future<void> _submitRequest(FamilyMember member, UserModel user) async {
    if (_selectedAdmin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Admin to review your request.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final request = EditRequest(
        requestId: '',
        type: EditRequestType.editMember,
        memberId: member.id,
        targetMemberName: member.nameEn,
        requestedBy: user.uid,
        requestedByName: user.name,
        requestedByPhone: user.phone,
        selectedAdminId: _selectedAdmin!.uid,
        selectedAdminName: _selectedAdmin!.name,
        changes: Map.from(_changedNewValues),
        oldData: Map.from(_changedOldValues),
        newData: Map.from(_changedNewValues),
        reason: _reasonController.text.trim(),
        createdAt: DateTime.now(),
      );

      await ref.read(editRequestRepositoryProvider).submitRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('Request submitted to ${_selectedAdmin!.name}!'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to submit: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);
    final member = ref.watch(familyMembersMapProvider)[widget.memberId];
    final isDirectAdmin = widget.isDirectAdmin && currentUser?.isAdmin == true;

    if (member == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.translate('edit_member'))),
        body: const Center(child: Text('Member not found.')),
      );
    }

    // Step 2: Member review summary screen (when requesting edit)
    if (_isReviewing && !isDirectAdmin) {
      return _buildReviewSummaryScreen(context, loc, isDark, member, currentUser!);
    }

    // Step 1: Form editing screen (Direct for Admin Portal, Step 1 for Member Portal)
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isDirectAdmin
              ? (loc.isUrdu ? 'رکن کی معلومات میں ترمیم (ایڈمن پورٹل)' : 'Edit Family Member (Admin Portal)')
              : loc.translate('suggest_edit'),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              children: [
                // Mode Banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDirectAdmin
                        ? AppColors.emerald.withValues(alpha: isDark ? 0.15 : 0.08)
                        : AppColors.gold.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isDirectAdmin ? AppColors.emerald : AppColors.gold,
                      width: 1.2,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        isDirectAdmin ? Icons.admin_panel_settings : Icons.info_outline,
                        color: isDirectAdmin ? AppColors.emerald : AppColors.gold,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          isDirectAdmin
                              ? (loc.isUrdu
                                  ? 'ایڈمن براہ راست ترمیم: آپ کی تبدیلیاں براہ راست خاندانی شجرہ میں محفوظ ہوں گی اور آڈٹ لاگ میں ریکارڈ کی جائیں گی۔'
                                  : 'Admin Direct Edit: Your modifications apply directly to the family tree without approval and are logged in audit history.')
                              : (loc.isUrdu
                                  ? 'شجرہ کی معلومات میں ترمیم: نام (انگریزی اور اردو)، تاریخ، رابطہ یا دیگر تفصیلات تبدیل کر کے تصدیق کے لیے جائزہ لیں۔'
                                  : 'Suggest Edit: Edit English and Urdu name, contact, dates, blood group, profession, and status for admin review.'),
                          style: TextStyle(
                            fontSize: 12,
                            height: 1.4,
                            color: isDark ? AppColors.textLightPrimary : AppColors.textDarkPrimary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Name Fields (Both English and Urdu editable for all)
                TextFormField(
                  controller: _nameEnController,
                  decoration: InputDecoration(
                    labelText: '${loc.translate('name_en')} (English)',
                    hintText: 'e.g. Ghulam Hussain Khan',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'English name is required' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _nameUrController,
                  textDirection: TextDirection.rtl,
                  decoration: InputDecoration(
                    labelText: '${loc.translate('name_ur')} (اردو نام)',
                    hintText: 'مثلاً: غلام حسین خان',
                    prefixIcon: const Icon(Icons.badge),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Urdu name is required' : null,
                ),
                const SizedBox(height: 16),
                if (isDirectAdmin) ...[
                  DropdownButtonFormField<String>(
                    initialValue: _gender,
                    decoration: InputDecoration(
                      labelText: loc.translate('gender'),
                      prefixIcon: const Icon(Icons.wc),
                    ),
                    items: [
                      DropdownMenuItem(value: 'male', child: Text(loc.translate('male'))),
                      DropdownMenuItem(value: 'female', child: Text(loc.translate('female'))),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => _gender = val);
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Alive Status
                DropdownButtonFormField<AliveStatus>(
                  initialValue: _aliveStatus,
                  decoration: InputDecoration(
                    labelText: loc.translate('status'),
                    prefixIcon: const Icon(Icons.favorite_border),
                  ),
                  items: [
                    DropdownMenuItem(value: AliveStatus.alive, child: Text(loc.translate('alive'))),
                    DropdownMenuItem(value: AliveStatus.deceased, child: Text(loc.translate('deceased'))),
                    DropdownMenuItem(value: AliveStatus.unknown, child: Text(loc.translate('unknown'))),
                  ],
                  onChanged: (val) {
                    if (val != null) setState(() => _aliveStatus = val);
                  },
                ),
                const SizedBox(height: 16),

                // Birth Date
                TextFormField(
                  controller: _birthDateController,
                  decoration: InputDecoration(
                    labelText: loc.translate('birth_date'),
                    hintText: 'e.g. 1975, or 15/04/1975',
                    prefixIcon: const Icon(Icons.cake_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Death Date
                if (_aliveStatus == AliveStatus.deceased) ...[
                  TextFormField(
                    controller: _deathDateController,
                    decoration: InputDecoration(
                      labelText: loc.translate('death_date'),
                      hintText: 'e.g. 2020, or 10/11/2020',
                      prefixIcon: const Icon(Icons.event_busy_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Phone Number
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: loc.translate('phone_number'),
                    hintText: '03001234567',
                    prefixIcon: const Icon(Icons.phone_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Blood Group
                DropdownButtonFormField<String>(
                  initialValue: _bloodGroup,
                  decoration: InputDecoration(
                    labelText: loc.translate('blood_group'),
                    prefixIcon: const Icon(Icons.bloodtype_outlined),
                  ),
                  items: _bloodGroupOptions
                      .map((bg) => DropdownMenuItem(value: bg, child: Text(bg)))
                      .toList(),
                  onChanged: (val) {
                    if (val != null) setState(() => _bloodGroup = val);
                  },
                ),
                const SizedBox(height: 16),

                // Profession
                TextFormField(
                  controller: _professionController,
                  decoration: InputDecoration(
                    labelText: loc.translate('profession'),
                    hintText: 'e.g. Doctor, Advocate, Farmer...',
                    prefixIcon: const Icon(Icons.work_outline),
                  ),
                ),
                const SizedBox(height: 16),

                // Address / Section
                TextFormField(
                  controller: _sectionController,
                  decoration: InputDecoration(
                    labelText: loc.translate('address'),
                    hintText: 'e.g. Jhang, Derajat, Lahore...',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: loc.translate('notes'),
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Reason (For Member Portal edit requests)
                if (!isDirectAdmin) ...[
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: loc.isUrdu ? 'ترمیم کی وجہ (ایڈمن کے لیے)' : 'Reason for Edit Suggestion',
                      hintText: loc.isUrdu ? 'وضاحت کریں کہ یہ معلومات کیوں درست ہیں...' : 'Explain why this edit should be approved...',
                      prefixIcon: const Icon(Icons.help_outline),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Please explain the reason for the suggested edit' : null,
                  ),
                  const SizedBox(height: 24),
                ],

                // Action Button
                if (isDirectAdmin)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSubmitting ? null : () => _handleDirectAdminSave(member, currentUser!),
                    icon: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                      loc.isUrdu ? 'تبدیلیاں براہ راست محفوظ کریں' : 'Save Changes Directly',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  )
                else
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.gold,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: () => _proceedToReview(member),
                    icon: const Icon(Icons.arrow_forward_rounded),
                    label: Text(
                      loc.translate('review_request'),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Step 2: Review Request Summary Screen for Normal Users
  Widget _buildReviewSummaryScreen(
    BuildContext context,
    AppLocalizations loc,
    bool isDark,
    FamilyMember member,
    UserModel currentUser,
  ) {
    final adminsAsync = ref.watch(adminUsersFutureProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('review_request')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _isReviewing = false),
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Header Card
              Card(
                color: isDark ? AppColors.darkCard : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const CircleAvatar(
                        backgroundColor: AppColors.gold,
                        child: Icon(Icons.person, color: Colors.black),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              member.nameEn,
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              member.nameUr,
                              style: const TextStyle(fontSize: 14, color: AppColors.gold),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              Text(
                loc.isUrdu ? 'تجویز کردہ تبدیلیاں:' : 'Changes to Submit:',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Changes List
              ..._changedNewValues.entries.map((entry) {
                final key = entry.key;
                final newVal = entry.value.toString();
                final oldVal = (_changedOldValues[key] ?? 'None').toString();

                return Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc.translate(key),
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text('${loc.translate('old_value')} ', style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary)),
                            Expanded(child: Text(oldVal.isEmpty ? 'Empty' : oldVal, style: const TextStyle(fontSize: 13, decoration: TextDecoration.lineThrough))),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text('${loc.translate('new_value')} ', style: const TextStyle(fontSize: 12, color: AppColors.emeraldLight, fontWeight: FontWeight.bold)),
                            Expanded(child: Text(newVal.isEmpty ? 'Empty' : newVal, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.emeraldLight))),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Select Admin Field
              Text(
                loc.translate('select_admin'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              adminsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                error: (e, _) => Text('Error loading admins: $e'),
                data: (allAdmins) {
                  final validAdmins = allAdmins
                      .where((a) => a.uid != currentUser.uid && a.isAdmin && !a.status.isBlocked)
                      .toList();
                  final displayAdmins = validAdmins.isNotEmpty ? validAdmins : allAdmins;

                  if (_selectedAdmin == null && displayAdmins.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedAdmin = displayAdmins.first);
                    });
                  }

                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.gold),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<UserModel>(
                        isExpanded: true,
                        value: displayAdmins.contains(_selectedAdmin) ? _selectedAdmin : (displayAdmins.isNotEmpty ? displayAdmins.first : null),
                        hint: Text(loc.translate('select_admin_hint')),
                        items: displayAdmins.map((adm) {
                          return DropdownMenuItem<UserModel>(
                            value: adm,
                            child: Row(
                              children: [
                                Icon(
                                  adm.role.isSuperAdmin ? Icons.shield : Icons.security,
                                  size: 20,
                                  color: adm.role.isSuperAdmin ? AppColors.gold : AppColors.emerald,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              adm.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Text(
                                            '(${adm.role.isSuperAdmin ? "Super Admin" : "Admin"})',
                                            style: const TextStyle(fontSize: 10.5, color: AppColors.textLightSecondary),
                                          ),
                                        ],
                                      ),
                                      if (adm.email.isNotEmpty)
                                        Text(
                                          adm.email,
                                          style: const TextStyle(fontSize: 11, color: AppColors.textLightSecondary),
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

              const SizedBox(height: 28),

              // Action Buttons: Edit Request (Back) vs Submit Request
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: () => setState(() => _isReviewing = false),
                      icon: const Icon(Icons.edit, size: 18),
                      label: Text(loc.translate('edit_request')),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _isSubmitting ? null : () => _submitRequest(member, currentUser),
                      icon: _isSubmitting
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send_rounded, size: 18),
                      label: Text(
                        loc.translate('submit_request'),
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
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
