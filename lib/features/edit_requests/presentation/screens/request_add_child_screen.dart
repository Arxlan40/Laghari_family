import 'package:file_picker/file_picker.dart';
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
import '../../../storage/services/supabase_storage_service.dart';
import '../../models/edit_request.dart';
import '../../repositories/edit_request_repository.dart';

class RequestAddChildScreen extends ConsumerStatefulWidget {
  final String fatherId;

  const RequestAddChildScreen({super.key, required this.fatherId});

  @override
  ConsumerState<RequestAddChildScreen> createState() =>
      _RequestAddChildScreenState();
}

class _RequestAddChildScreenState extends ConsumerState<RequestAddChildScreen> {
  final _formKey = GlobalKey<FormState>();

  final _nameEnController = TextEditingController();
  final _nameUrController = TextEditingController();
  final _birthDateController = TextEditingController();
  final _deathDateController = TextEditingController();
  final _phoneController = TextEditingController();
  final _professionController = TextEditingController();
  final _notesController = TextEditingController();
  final _reasonController = TextEditingController();

  String _gender = 'male';
  String _bloodGroup = 'Unknown';
  AliveStatus _aliveStatus = AliveStatus.alive;
  late int _generation;
  String? _uploadedImageUrl;
  bool _isUploadingImage = false;
  bool _isSubmitting = false;

  bool _isReviewing = false; // Step 2 for Normal Users
  UserModel? _selectedAdmin;

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
    final father = ref.read(familyMembersMapProvider)[widget.fatherId];
    _generation = (father?.generation ?? 50) + 1;
  }

  @override
  void dispose() {
    _nameEnController.dispose();
    _nameUrController.dispose();
    _birthDateController.dispose();
    _deathDateController.dispose();
    _phoneController.dispose();
    _professionController.dispose();
    _notesController.dispose();
    _reasonController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadImage() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      setState(() => _isUploadingImage = true);
      try {
        final storage = ref.read(supabaseStorageServiceProvider);
        final url = await storage.uploadMemberImage(
          memberId: 'child_${DateTime.now().millisecondsSinceEpoch}',
          bytes: result.files.single.bytes!,
          fileExtension: result.files.single.extension ?? 'jpg',
        );
        setState(() => _uploadedImageUrl = url);
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Image upload failed: $e')),
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingImage = false);
      }
    }
  }

  Map<String, dynamic> _collectData() {
    return {
      'name_en': _nameEnController.text.trim(),
      'name_ur': _nameUrController.text.trim(),
      'father_id': widget.fatherId,
      'gender': _gender,
      'alive_status': _aliveStatus.toDbValue(),
      'generation': _generation,
      'image_url': _uploadedImageUrl ?? '',
      'birth_date': _birthDateController.text.trim().isEmpty ? null : _birthDateController.text.trim(),
      'death_date': _deathDateController.text.trim().isEmpty ? null : _deathDateController.text.trim(),
      'phone_number': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
      'blood_group': _bloodGroup,
      'profession': _professionController.text.trim().isEmpty ? null : _professionController.text.trim(),
      'notes': _notesController.text.trim().isEmpty ? null : _notesController.text.trim(),
    };
  }

  /// Admin directly adds child to family tree without creating approval request
  Future<void> _handleDirectAdminAdd(UserModel admin, FamilyMember father) async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);
    try {
      final data = _collectData();
      final cleanName = data['name_en'].toString().toLowerCase().replaceAll(RegExp(r'\s+'), '_');
      final newId = '${cleanName}_${DateTime.now().millisecondsSinceEpoch % 10000}';

      final newMember = FamilyMember(
        id: newId,
        nameEn: data['name_en'] ?? '',
        nameUr: data['name_ur'] ?? '',
        fatherId: widget.fatherId,
        gender: _gender,
        aliveStatus: _aliveStatus,
        generation: _generation,
        imageUrl: _uploadedImageUrl ?? '',
        phoneNumber: data['phone_number'],
        bloodGroup: _bloodGroup,
        profession: data['profession'],
        birthDate: data['birth_date'],
        deathDate: data['death_date'],
        notes: data['notes'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Save directly into family tree repository
      await ref.read(familyRepositoryProvider).saveMember(newMember);

      // Record Audit Log for Super Admin history
      await ref.read(auditLogRepositoryProvider).recordLog(
        AuditLogModel(
          logId: const Uuid().v4(),
          action: 'direct_add_child',
          performedBy: admin.uid,
          performedByName: admin.name,
          performedByRole: admin.role.value,
          targetMemberId: newId,
          targetMemberName: newMember.nameEn,
          oldData: {'father_id': father.id, 'father_name': father.nameEn},
          newData: data,
          timestamp: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('Child added directly to family tree and logged in audit history.'),
          ),
        );
        context.pop();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add child: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  /// Normal User proceeds to Step 2 (Review Summary)
  void _proceedToReview() {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isReviewing = true);
  }

  /// Normal User submits the reviewed add-child request
  Future<void> _submitRequest(UserModel user, FamilyMember father) async {
    if (_selectedAdmin == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an Admin to review your request.')),
      );
      return;
    }

    setState(() => _isSubmitting = true);
    try {
      final data = _collectData();

      final request = EditRequest(
        requestId: '',
        type: EditRequestType.addChild,
        memberId: widget.fatherId,
        targetMemberName: father.nameEn,
        requestedBy: user.uid,
        requestedByName: user.name,
        selectedAdminId: _selectedAdmin!.uid,
        selectedAdminName: _selectedAdmin!.name,
        changes: data,
        oldData: {'father_id': father.id, 'father_name': father.nameEn},
        newData: data,
        reason: _reasonController.text.trim().isNotEmpty
            ? _reasonController.text.trim()
            : 'Registering child under ${father.nameEn}',
        createdAt: DateTime.now(),
      );

      await ref.read(editRequestRepositoryProvider).submitRequest(request);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text('Add-child request submitted to ${_selectedAdmin!.name}!'),
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
    final father = ref.watch(familyMembersMapProvider)[widget.fatherId];
    final currentUser = ref.watch(currentUserProvider);
    final isAdmin = currentUser?.isAdmin == true;

    if (father == null) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.translate('add_child'))),
        body: const Center(child: Text('Father not found.')),
      );
    }

    // Step 2 for Normal Users: Review Summary Screen
    if (_isReviewing && !isAdmin) {
      return _buildReviewSummaryScreen(context, loc, isDark, father, currentUser!);
    }

    // Step 1: Form Screen (Direct for Admin, Step 1 for User)
    return Scaffold(
      appBar: AppBar(
        title: Text(
          isAdmin
              ? (loc.isUrdu ? 'بچے کا اندراج (براہ راست)' : 'Add Child (Direct)')
              : loc.translate('request_add_child'),
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
                // Father Info Header Card
                Card(
                  child: ListTile(
                    leading: const CircleAvatar(
                      backgroundColor: AppColors.gold,
                      child: Icon(Icons.escalator_warning, color: Colors.black),
                    ),
                    title: Text(
                      '${loc.translate("father")}: ${father.localizedName(loc.locale.languageCode)}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text('${loc.translate("generation")}: ${father.generation}'),
                  ),
                ),
                const SizedBox(height: 12),

                // Mode Banner
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isAdmin
                        ? AppColors.emerald.withValues(alpha: isDark ? 0.15 : 0.08)
                        : AppColors.gold.withValues(alpha: isDark ? 0.15 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: isAdmin ? AppColors.emerald : AppColors.gold),
                  ),
                  child: Row(
                    children: [
                      Icon(isAdmin ? Icons.admin_panel_settings : Icons.info_outline,
                          color: isAdmin ? AppColors.emerald : AppColors.gold, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isAdmin
                              ? (loc.isUrdu
                                  ? 'ایڈمن اندراج: بچہ براہ راست شجرہ میں شامل ہوگا اور آڈٹ لاگ میں ریکارڈ ہوگا۔'
                                  : 'Admin Direct Action: The child is added directly to the tree without approval and logged in audit history.')
                              : (loc.isUrdu
                                  ? 'بچے کی معلومات درج کر کے جائزے کے لیے آگے بڑھیں۔'
                                  : 'Enter the child details, then review your request before submitting to an Admin.'),
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Photo Picker
                Center(
                  child: Stack(
                    children: [
                      CircleAvatar(
                        radius: 46,
                        backgroundColor: AppColors.darkSurface,
                        backgroundImage: _uploadedImageUrl != null ? NetworkImage(_uploadedImageUrl!) : null,
                        child: _uploadedImageUrl == null
                            ? const Icon(Icons.person_add, size: 40, color: AppColors.gold)
                            : null,
                      ),
                      Positioned(
                        bottom: 0,
                        right: 0,
                        child: CircleAvatar(
                          radius: 16,
                          backgroundColor: AppColors.gold,
                          child: IconButton(
                            icon: _isUploadingImage
                                ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.camera_alt, size: 14, color: Colors.black),
                            onPressed: _isUploadingImage ? null : _pickAndUploadImage,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Name in English
                TextFormField(
                  controller: _nameEnController,
                  decoration: InputDecoration(
                    labelText: loc.translate('name_en'),
                    hintText: 'e.g. Asad Khan Laghari',
                    prefixIcon: const Icon(Icons.badge_outlined),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'English name is required' : null,
                ),
                const SizedBox(height: 16),

                // Name in Urdu
                TextFormField(
                  controller: _nameUrController,
                  decoration: InputDecoration(
                    labelText: loc.translate('name_ur'),
                    hintText: 'مثلاً: اسد خان لغاری',
                    prefixIcon: const Icon(Icons.badge),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Urdu name is required' : null,
                ),
                const SizedBox(height: 16),

                // Gender
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text(loc.translate('male'))),
                        selected: _gender == 'male',
                        onSelected: (sel) => setState(() => _gender = 'male'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(child: Text(loc.translate('female'))),
                        selected: _gender == 'female',
                        onSelected: (sel) => setState(() => _gender = 'female'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

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
                    hintText: 'e.g. 2024 or 15/05/2024',
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
                      hintText: 'e.g. 2024',
                      prefixIcon: const Icon(Icons.event_busy_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Phone
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
                    hintText: 'e.g. Student, Doctor...',
                    prefixIcon: const Icon(Icons.work_outline),
                  ),
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  controller: _notesController,
                  maxLines: 2,
                  decoration: InputDecoration(
                    labelText: loc.translate('notes'),
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                  ),
                ),
                const SizedBox(height: 16),

                // Reason (For User)
                if (!isAdmin) ...[
                  TextFormField(
                    controller: _reasonController,
                    maxLines: 2,
                    decoration: InputDecoration(
                      labelText: loc.translate('reason'),
                      hintText: 'e.g. Newborn in the family',
                      prefixIcon: const Icon(Icons.help_outline),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],

                // Action Button
                if (isAdmin)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.emerald,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    onPressed: _isSubmitting ? null : () => _handleDirectAdminAdd(currentUser!, father),
                    icon: _isSubmitting
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.person_add),
                    label: Text(
                      loc.isUrdu ? 'بچے کا براہ راست اندراج کریں' : 'Add Child Directly',
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
                    onPressed: _proceedToReview,
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

  /// Step 2: Review Add Child Request Summary Screen for Normal Users
  Widget _buildReviewSummaryScreen(
    BuildContext context,
    AppLocalizations loc,
    bool isDark,
    FamilyMember father,
    UserModel currentUser,
  ) {
    final adminsAsync = ref.watch(adminUsersFutureProvider);
    final data = _collectData();

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
                        backgroundColor: AppColors.emerald,
                        child: Icon(Icons.person_add, color: Colors.black),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['name_en'],
                              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              data['name_ur'],
                              style: const TextStyle(fontSize: 14, color: AppColors.gold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${loc.translate("father")}: ${father.nameEn}',
                              style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
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
                loc.isUrdu ? 'درخواست کی تفصیلات:' : 'Request Summary Details:',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),

              // Detail Cards
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      _buildSummaryRow(loc.translate('gender'), _gender == 'female' ? loc.translate('female') : loc.translate('male')),
                      const Divider(height: 16),
                      _buildSummaryRow(loc.translate('status'), _aliveStatus.name),
                      const Divider(height: 16),
                      _buildSummaryRow(loc.translate('birth_date'), data['birth_date'] ?? 'Unknown'),
                      const Divider(height: 16),
                      _buildSummaryRow(loc.translate('phone_number'), data['phone_number'] ?? 'None'),
                      const Divider(height: 16),
                      _buildSummaryRow(loc.translate('blood_group'), _bloodGroup),
                      const Divider(height: 16),
                      _buildSummaryRow(loc.translate('profession'), data['profession'] ?? 'None'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Select Admin Field
              Text(
                loc.translate('select_admin'),
                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              adminsAsync.when(
                loading: () => const Center(child: Padding(padding: EdgeInsets.all(8.0), child: CircularProgressIndicator())),
                error: (e, _) => Text('Error loading admins: $e'),
                data: (admins) {
                  if (_selectedAdmin == null && admins.isNotEmpty) {
                    WidgetsBinding.instance.addPostFrameCallback((_) {
                      if (mounted) setState(() => _selectedAdmin = admins.first);
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
                        value: _selectedAdmin,
                        hint: Text(loc.translate('select_admin_hint')),
                        items: admins.map((adm) {
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
                                Text(adm.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                const SizedBox(width: 8),
                                Text(
                                  '(${adm.role.isSuperAdmin ? 'Super Admin' : 'Admin'})',
                                  style: const TextStyle(fontSize: 11, color: AppColors.textLightSecondary),
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

              // Buttons
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
                      onPressed: _isSubmitting ? null : () => _submitRequest(currentUser, father),
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

  Widget _buildSummaryRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textLightSecondary)),
        Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
