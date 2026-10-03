import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_person.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import '../widgets/hamdard_family_member_picker_modal.dart';
import '../widgets/hamdard_user_avatar.dart';
import 'hamdard_donor_profile_screen.dart';

enum PersonFilterMode {
  all,
  familyTree,
  manual,
  donors,
  recipients,
  donatedThisMonth,
  notDonatedThisMonth,
}

class HamdardDonorsScreen extends ConsumerStatefulWidget {
  const HamdardDonorsScreen({super.key});

  @override
  ConsumerState<HamdardDonorsScreen> createState() => _HamdardDonorsScreenState();
}

class _HamdardDonorsScreenState extends ConsumerState<HamdardDonorsScreen> {
  String _searchQuery = '';
  PersonFilterMode _filterMode = PersonFilterMode.all;

  void _showAddPersonOptionsSheet() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkCard : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.isUrdu ? 'نیا فرد شامل کریں' : 'Add Person to Directory',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(
              loc.isUrdu
                  ? 'آپ شجرہ نسب سے منتخب کر سکتے ہیں یا دستی تفصیلات درج کر سکتے ہیں'
                  : 'Select an existing family tree member or create a manual record',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
            const SizedBox(height: 20),

            // Option A: Select from Family Tree
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: AppColors.emerald.withValues(alpha: 0.3)),
              ),
              tileColor: AppColors.emerald.withValues(alpha: 0.08),
              leading: const CircleAvatar(
                backgroundColor: AppColors.emerald,
                child: Icon(Icons.account_tree, color: Colors.white, size: 20),
              ),
              title: Text(
                loc.isUrdu ? 'شجرہ نسب سے فرد منتخب کریں' : 'Select from Family Tree',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              subtitle: Text(
                loc.isUrdu
                    ? 'شجرہ نسب سے معلومات خودکار حاصل کر کے ربط قائم کریں'
                    : 'Auto-fill details and establish link with unique member ID',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _addPersonFromFamilyTree();
              },
            ),
            const SizedBox(height: 12),

            // Option B: Add Manually
            ListTile(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
              ),
              leading: CircleAvatar(
                backgroundColor: isDark ? AppColors.darkSurface : Colors.grey.shade200,
                child: const Icon(Icons.edit, color: Colors.grey, size: 20),
              ),
              title: Text(
                loc.isUrdu ? 'دستی اندراج کریں (غیر شجرہ فرد)' : 'Add Manually',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
              ),
              subtitle: Text(
                loc.isUrdu
                    ? 'جو افراد ابھی شجرہ نسب میں نہیں ہیں ان کے کوائف درج کریں'
                    : 'Enter details manually for individuals not in the family tree',
                style: const TextStyle(fontSize: 11),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.pop(ctx);
                _showManualAddPersonDialog();
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  Future<void> _addPersonFromFamilyTree() async {
    final loc = AppLocalizations.of(context);
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final selectedMember = await HamdardFamilyMemberPickerModal.show(context);
    if (selectedMember == null || !mounted) return;

    final repo = ref.read(hamdardRepositoryProvider);
    final allPeople = await repo.getPeople();

    // Check if member is already linked
    final existingMemberLink = allPeople.cast<HamdardPerson?>().firstWhere(
          (p) => p?.familyMemberId == selectedMember.id,
          orElse: () => null,
        );

    if (existingMemberLink != null) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.gold,
            content: Text(
              loc.isUrdu
                  ? 'یہ فرد پہلے سے ہمدرد ڈائریکٹری میں موجود ہے: ${existingMemberLink.name}'
                  : 'This family tree member is already in the Hamdard directory: ${existingMemberLink.name}',
            ),
          ),
        );
      }
      return;
    }

    final normalizedPhone = HamdardPerson.normalizePhone(selectedMember.phoneNumber);

    final newPerson = HamdardPerson(
      id: '',
      name: selectedMember.nameEn.isNotEmpty ? selectedMember.nameEn : selectedMember.nameUr,
      fatherName: selectedMember.nameUr.isNotEmpty ? selectedMember.nameUr : 'Laghari Family Member',
      phoneNumber: normalizedPhone,
      sourceType: 'family_tree',
      familyMemberId: selectedMember.id,
      profileImageUrl: selectedMember.imageUrl,
      bloodGroup: selectedMember.bloodGroup,
      profession: selectedMember.profession,
      gender: selectedMember.gender,
    );

    try {
      final saved = await repo.savePerson(
        newPerson,
        performedBy: currentUser.uid,
        performedByName: currentUser.name,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text(
              loc.isUrdu
                  ? 'شجرہ نسب سے فرد شامل کر لیا گیا: ${saved.name}'
                  : 'Added ${saved.name} from Family Tree.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).hideCurrentSnackBar();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Error adding person: $e')),
        );
      }
    }
  }

  void _showManualAddPersonDialog({HamdardPerson? personToEdit}) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController(text: personToEdit?.name ?? '');
    final fatherCtrl = TextEditingController(text: personToEdit?.fatherName ?? '');
    final phoneCtrl = TextEditingController(text: personToEdit?.phoneNumber ?? '');
    final notesCtrl = TextEditingController(text: personToEdit?.notes ?? '');
    String selectedBlood = personToEdit?.bloodGroup ?? 'Unknown';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(personToEdit == null
              ? (loc.isUrdu ? 'نیا فرد شامل کریں' : 'Add Person Manually')
              : (loc.isUrdu ? 'کوائف میں ترمیم کریں' : 'Edit Person Details')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: InputDecoration(
                    labelText: loc.isUrdu ? 'مکمل نام *' : 'Full Name *',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: fatherCtrl,
                  decoration: InputDecoration(
                    labelText: loc.isUrdu ? 'والد کا نام *' : "Father's Name *",
                    prefixIcon: const Icon(Icons.person_outline),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: phoneCtrl,
                  keyboardType: TextInputType.phone,
                  decoration: InputDecoration(
                    labelText: loc.isUrdu ? 'موبائل نمبر (03XXXXXXXXX) *' : 'Phone Number (03XXXXXXXXX) *',
                    prefixIcon: const Icon(Icons.phone),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: selectedBlood,
                  decoration: InputDecoration(
                    labelText: 'Blood Group',
                    prefixIcon: const Icon(Icons.bloodtype, color: Colors.red),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Unknown', child: Text('Unknown')),
                    DropdownMenuItem(value: 'A+', child: Text('A+')),
                    DropdownMenuItem(value: 'A-', child: Text('A-')),
                    DropdownMenuItem(value: 'B+', child: Text('B+')),
                    DropdownMenuItem(value: 'B-', child: Text('B-')),
                    DropdownMenuItem(value: 'AB+', child: Text('AB+')),
                    DropdownMenuItem(value: 'AB-', child: Text('AB-')),
                    DropdownMenuItem(value: 'O+', child: Text('O+')),
                    DropdownMenuItem(value: 'O-', child: Text('O-')),
                  ],
                  onChanged: (val) {
                    if (val != null) setDialogState(() => selectedBlood = val);
                  },
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: notesCtrl,
                  decoration: InputDecoration(
                    labelText: loc.isUrdu ? 'اضافی نوٹس' : 'Notes / Remarks',
                    prefixIcon: const Icon(Icons.note_alt_outlined),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.translate('cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                final name = nameCtrl.text.trim();
                final father = fatherCtrl.text.trim();
                final phone = phoneCtrl.text.trim();

                // Validation Feedback with clear Snackbars
                if (name.isEmpty) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.danger,
                      content: Text(loc.isUrdu ? 'براہ کرم فرد کا نام درج کریں' : 'Please enter the person\'s name.'),
                    ),
                  );
                  return;
                }

                if (father.isEmpty) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.danger,
                      content: Text(loc.isUrdu ? 'براہ کرم والد کا نام درج کریں' : 'Please enter the father\'s name.'),
                    ),
                  );
                  return;
                }

                if (phone.isEmpty || !HamdardPerson.isValidPakistaniPhone(phone)) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.danger,
                      content: Text(loc.isUrdu
                          ? 'براہ کرم درست 11 ہندسوں کا موبائل نمبر درج کریں (03XXXXXXXXX)'
                          : 'Please enter a valid 11-digit mobile number (03XXXXXXXXX).'),
                    ),
                  );
                  return;
                }

                final currentUser = ref.read(currentUserProvider);
                if (currentUser == null) return;

                final normalizedPhone = HamdardPerson.normalizePhone(phone);
                final repo = ref.read(hamdardRepositoryProvider);

                // Duplicate Phone check
                if (personToEdit == null) {
                  final allPeople = await repo.getPeople();
                  final duplicate = allPeople.cast<HamdardPerson?>().firstWhere(
                        (p) => p?.phoneNumber == normalizedPhone,
                        orElse: () => null,
                      );
                  if (duplicate != null) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          backgroundColor: AppColors.danger,
                          content: Text(loc.isUrdu
                              ? 'اس موبائل نمبر کے ساتھ فرد پہلے سے موجود ہے: ${duplicate.name}'
                              : 'A person with this phone number already exists: ${duplicate.name}'),
                        ),
                      );
                    }
                    return;
                  }
                }

                final personToSave = (personToEdit ?? const HamdardPerson(id: '', name: '', fatherName: '', phoneNumber: '')).copyWith(
                  name: name,
                  fatherName: father,
                  phoneNumber: normalizedPhone,
                  bloodGroup: selectedBlood != 'Unknown' ? selectedBlood : null,
                  notes: notesCtrl.text.trim(),
                  sourceType: personToEdit?.sourceType ?? 'manual',
                );

                await repo.savePerson(
                  personToSave,
                  performedBy: currentUser.uid,
                  performedByName: currentUser.name,
                );

                if (ctx.mounted) Navigator.pop(ctx);
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.emerald,
                      content: Text(loc.isUrdu ? 'معلومات محفوظ ہو گئیں' : 'Person details saved successfully.'),
                    ),
                  );
                }
              },
              child: Text(loc.translate('save')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final currentUser = ref.watch(currentUserProvider);
    final canManage = currentUser?.canManageHamdard ?? false;

    final statsList = ref.watch(hamdardPeopleWithStatsProvider);
    final peopleState = ref.watch(hamdardPeopleStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'ہمدرد افراد ڈائریکٹری' : 'Hamdard People Directory'),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: Text(isUrdu ? 'نیا فرد' : 'Add Person'),
              onPressed: _showAddPersonOptionsSheet,
            )
          : null,
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: isUrdu
                    ? 'نام، والد کا نام یا فون نمبر سے تلاش کریں...'
                    : 'Search by name, father name, or phone...',
                prefixIcon: const Icon(Icons.search, size: 20),
                suffixIcon: _searchQuery.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear, size: 18),
                        onPressed: () => setState(() => _searchQuery = ''),
                      )
                    : null,
                filled: true,
                fillColor: isDark ? AppColors.darkSurface : AppColors.lightCard,
                contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  ),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
            ),
          ),

          // Filter Chips (All, Family Tree, Manual, Donors, Recipients, Donated This Month, Not Donated)
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            child: Row(
              children: [
                _buildFilterChip(PersonFilterMode.all, isUrdu ? 'تمام افراد' : 'All People'),
                const SizedBox(width: 8),
                _buildFilterChip(PersonFilterMode.familyTree, isUrdu ? 'شجرہ نسب سے' : 'Family Tree'),
                const SizedBox(width: 8),
                _buildFilterChip(PersonFilterMode.manual, isUrdu ? 'دستی اندراج' : 'Manual'),
                const SizedBox(width: 8),
                _buildFilterChip(PersonFilterMode.donors, isUrdu ? 'عطیہ دہندگان' : 'Donors'),
                const SizedBox(width: 8),
                _buildFilterChip(PersonFilterMode.recipients, isUrdu ? 'مستحقین امداد' : 'Recipients'),
                const SizedBox(width: 8),
                _buildFilterChip(PersonFilterMode.donatedThisMonth, isUrdu ? 'اس ماہ عطیہ دیا' : 'Donated This Month'),
                const SizedBox(width: 8),
                _buildFilterChip(PersonFilterMode.notDonatedThisMonth, isUrdu ? 'اس ماہ عطیہ نہیں دیا' : 'No Donation This Month'),
              ],
            ),
          ),
          const SizedBox(height: 4),

          // People Registry List
          Expanded(
            child: peopleState.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.emerald),
                    SizedBox(height: 12),
                    Text('Loading Hamdard people...'),
                  ],
                ),
              ),
              error: (err, _) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 12),
                    Text(isUrdu ? 'ڈیٹا لوڈ کرنے میں خرابی' : 'Unable to load people.'),
                    const SizedBox(height: 12),
                    ElevatedButton(
                      onPressed: () => ref.invalidate(hamdardPeopleStreamProvider),
                      child: Text(isUrdu ? 'دوبارہ کوشش کریں' : 'Retry'),
                    ),
                  ],
                ),
              ),
              data: (_) {
                // Filter the computed stats list
                final filtered = statsList.where((stats) {
                  final p = stats.person;
                  // Search query
                  if (_searchQuery.isNotEmpty) {
                    final n = p.name.toLowerCase();
                    final f = p.fatherName.toLowerCase();
                    final ph = p.phoneNumber.toLowerCase();
                    if (!n.contains(_searchQuery) && !f.contains(_searchQuery) && !ph.contains(_searchQuery)) {
                      return false;
                    }
                  }

                  // Mode filter
                  switch (_filterMode) {
                    case PersonFilterMode.all:
                      return true;
                    case PersonFilterMode.familyTree:
                      return p.isFromFamilyTree;
                    case PersonFilterMode.manual:
                      return !p.isFromFamilyTree;
                    case PersonFilterMode.donors:
                      return stats.isDonor;
                    case PersonFilterMode.recipients:
                      return stats.isRecipient;
                    case PersonFilterMode.donatedThisMonth:
                      return stats.thisMonthTotal > 0;
                    case PersonFilterMode.notDonatedThisMonth:
                      return stats.thisMonthTotal == 0;
                  }
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 54, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          isUrdu ? 'کوئی فرد نہیں ملا' : 'No people found matching filters.',
                          style: TextStyle(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final stats = filtered[i];
                    final p = stats.person;

                    return Card(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => HamdardDonorProfileScreen(person: p),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  HamdardUserAvatar(
                                    imageUrl: p.profileImageUrl,
                                    name: p.name,
                                    size: 48,
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
                                                p.name,
                                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15.5),
                                              ),
                                            ),
                                            if (p.isFromFamilyTree)
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: AppColors.emerald.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    const Icon(Icons.account_tree, size: 10, color: AppColors.emerald),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isUrdu ? 'شجرہ' : 'Family Tree',
                                                      style: const TextStyle(
                                                        fontSize: 9.5,
                                                        color: AppColors.emerald,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              )
                                            else
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withValues(alpha: 0.15),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  isUrdu ? 'دستی' : 'Manual',
                                                  style: const TextStyle(
                                                    fontSize: 9.5,
                                                    color: Colors.grey,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${isUrdu ? "والد" : "Father"}: ${p.fatherName.isNotEmpty ? p.fatherName : "N/A"} • ${p.phoneNumber}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),

                              // Financial Metrics Summary Bar
                              Row(
                                children: [
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.emerald.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isUrdu ? 'اس ماہ عطیہ' : 'This Month',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          ),
                                          Text(
                                            HamdardRepository.formatPkr(stats.thisMonthTotal),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                              color: AppColors.emerald,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: AppColors.gold.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isUrdu ? 'کل عطیات' : 'Total Donated',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          ),
                                          Text(
                                            HamdardRepository.formatPkr(stats.allTimeTotal),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                              color: AppColors.gold,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.withValues(alpha: 0.08),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            isUrdu ? 'موصولہ امداد' : 'Assistance',
                                            style: const TextStyle(fontSize: 10, color: Colors.grey),
                                          ),
                                          Text(
                                            HamdardRepository.formatPkr(stats.totalAssistanceReceived),
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 12.5,
                                              color: Colors.orange,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),

                              if (canManage) ...[
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (p.isFromFamilyTree)
                                      TextButton.icon(
                                        icon: const Icon(Icons.account_tree_outlined, size: 14, color: AppColors.gold),
                                        label: Text(isUrdu ? 'شجرہ میں دیکھیں' : 'Tree View', style: const TextStyle(fontSize: 11)),
                                        onPressed: () {
                                          context.push('/family-tree?focusMemberId=${p.familyMemberId}');
                                        },
                                      ),
                                    TextButton.icon(
                                      icon: const Icon(Icons.edit_outlined, size: 14),
                                      label: Text(isUrdu ? 'ترمیم' : 'Edit', style: const TextStyle(fontSize: 11)),
                                      onPressed: () => _showManualAddPersonDialog(personToEdit: p),
                                    ),
                                  ],
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(PersonFilterMode mode, String label) {
    final isSelected = _filterMode == mode;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.emerald,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11.5,
      ),
      onSelected: (_) => setState(() => _filterMode = mode),
    );
  }
}
