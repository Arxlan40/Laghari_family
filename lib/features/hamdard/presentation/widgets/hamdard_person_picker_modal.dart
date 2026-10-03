import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family_tree/models/family_member.dart';
import '../../../family_tree/repositories/family_repository.dart';
import '../../models/hamdard_person.dart';
import '../../providers/hamdard_providers.dart';
import 'hamdard_family_member_picker_modal.dart';
import 'hamdard_user_avatar.dart';

class HamdardPersonPickerModal extends ConsumerStatefulWidget {
  final String? title;
  final bool filterRecipientsOnly;

  const HamdardPersonPickerModal({
    super.key,
    this.title,
    this.filterRecipientsOnly = false,
  });

  static Future<HamdardPerson?> show(
    BuildContext context, {
    String? title,
    bool filterRecipientsOnly = false,
  }) {
    return showModalBottomSheet<HamdardPerson>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => HamdardPersonPickerModal(
        title: title,
        filterRecipientsOnly: filterRecipientsOnly,
      ),
    );
  }

  @override
  ConsumerState<HamdardPersonPickerModal> createState() => _HamdardPersonPickerModalState();
}

class _HamdardPersonPickerModalState extends ConsumerState<HamdardPersonPickerModal> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();
  String _sourceFilter = 'all'; // all, family_tree, manual

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _showAddPersonSheet() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                loc.isUrdu ? 'نیا فرد شامل کریں' : 'Add New Person',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 6),
              Text(
                loc.isUrdu
                    ? 'شجرہ نسب سے فرد منتخب کریں یا دستی طور پر درج کریں'
                    : 'Choose whether to link from the family tree or enter details manually.',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 20),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: AppColors.emerald.withValues(alpha: 0.3)),
                ),
                tileColor: AppColors.emerald.withValues(alpha: 0.08),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: AppColors.emerald, shape: BoxShape.circle),
                  child: const Icon(Icons.account_tree, color: Colors.white, size: 20),
                ),
                title: Text(
                  loc.isUrdu ? 'آپشن A — شجرہ نسب سے منتخب کریں' : 'Option A — Select from Family Tree',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  loc.isUrdu ? 'خاندان کے شجرہ سے نام، تصویر، فون لائیں' : 'Import name, photo, father, and phone safely',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  _addFromFamilyTree();
                },
              ),
              const SizedBox(height: 12),
              ListTile(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.withValues(alpha: 0.3)),
                ),
                tileColor: isDark ? AppColors.darkSurface : Colors.grey.withValues(alpha: 0.05),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: const BoxDecoration(color: Colors.blueGrey, shape: BoxShape.circle),
                  child: const Icon(Icons.person_add_alt_1, color: Colors.white, size: 20),
                ),
                title: Text(
                  loc.isUrdu ? 'آپشن B — دستی طور پر درج کریں' : 'Option B — Add Manually',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                ),
                subtitle: Text(
                  loc.isUrdu ? 'شجرہ سے باہر کے افراد کیلئے' : 'For persons not yet registered in family tree',
                  style: const TextStyle(fontSize: 11),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  Navigator.pop(ctx);
                  _showManualAddPersonDialog();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _addFromFamilyTree() async {
    final selectedMember = await HamdardFamilyMemberPickerModal.show(context);
    if (selectedMember == null || !mounted) return;

    final loc = AppLocalizations.of(context);
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final repo = ref.read(hamdardRepositoryProvider);
    final allMembers = ref.read(familyMembersStreamProvider).valueOrNull ?? [];
    String fatherName = '';
    if (selectedMember.fatherId != null && selectedMember.fatherId!.isNotEmpty) {
      final f = allMembers.cast<FamilyMember?>().firstWhere(
            (m) => m?.id == selectedMember.fatherId,
            orElse: () => null,
          );
      if (f != null) {
        fatherName = f.nameEn.isNotEmpty ? f.nameEn : f.nameUr;
      }
    }

    final newPerson = HamdardPerson(
      id: '',
      name: selectedMember.nameEn.isNotEmpty ? selectedMember.nameEn : selectedMember.nameUr,
      fatherName: fatherName.isNotEmpty ? fatherName : (selectedMember.nameUr.isNotEmpty ? selectedMember.nameUr : 'Laghari Family Member'),
      phoneNumber: HamdardPerson.normalizePhone(selectedMember.phoneNumber ?? ''),
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
        Navigator.pop(context, saved);
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

  void _showManualAddPersonDialog() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    final fatherCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final notesCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'نیا فرد دستی طور پر شامل کریں' : 'Add Person Manually'),
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
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: loc.isUrdu ? 'اضافی نوٹس (اختیاری)' : 'Notes (optional)',
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

              final repo = ref.read(hamdardRepositoryProvider);
              final person = HamdardPerson(
                id: '',
                name: name,
                fatherName: father,
                phoneNumber: phone,
                sourceType: 'manual',
                notes: notesCtrl.text.trim(),
              );

              try {
                final saved = await repo.savePerson(
                  person,
                  performedBy: currentUser.uid,
                  performedByName: currentUser.name,
                );

                if (ctx.mounted) {
                  Navigator.pop(ctx); // Close dialog
                }
                if (mounted) {
                  Navigator.pop(context, saved); // Close picker with new person
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      backgroundColor: AppColors.emerald,
                      content: Text(
                        loc.isUrdu
                            ? 'فرد کامیابی سے شامل کر لیا گیا: ${saved.name}'
                            : 'Person added: ${saved.name}',
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(backgroundColor: AppColors.danger, content: Text('Error saving person: $e')),
                  );
                }
              }
            },
            child: Text(loc.translate('save')),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final peopleAsync = ref.watch(hamdardPeopleStreamProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? AppColors.darkCard : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Drag handle
              const SizedBox(height: 12),
              Container(
                width: 44,
                height: 4.5,
                decoration: BoxDecoration(
                  color: Colors.grey.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(height: 12),

              // Title Header & "+ Add Person" Button
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.emerald.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.people_alt, color: AppColors.emerald, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.title ?? (isUrdu ? 'فرد منتخب کریں' : 'Select Person'),
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isUrdu ? 'ہمدرد ڈائریکٹری سے انتخاب کریں' : 'Choose from Hamdard Person Directory',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      icon: const Icon(Icons.person_add, size: 16),
                      label: Text(
                        isUrdu ? '+ نیا فرد' : '+ Add Person',
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showAddPersonSheet,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),

              // Search Field
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
                          )
                        : null,
                    hintText: isUrdu
                        ? 'نام، والد، یا فون سے تلاش کریں...'
                        : 'Search by name, father, or phone...',
                    filled: true,
                    fillColor: isDark ? AppColors.darkSurface : Colors.grey.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: 10),

              // Source Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text(isUrdu ? 'سب' : 'All'),
                      selected: _sourceFilter == 'all',
                      onSelected: (_) => setState(() => _sourceFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.account_tree, size: 14),
                      label: Text(isUrdu ? 'شجرہ نسب' : 'Family Tree'),
                      selected: _sourceFilter == 'family_tree',
                      onSelected: (_) => setState(() => _sourceFilter = 'family_tree'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      avatar: const Icon(Icons.person_outline, size: 14),
                      label: Text(isUrdu ? 'دستی' : 'Manual'),
                      selected: _sourceFilter == 'manual',
                      onSelected: (_) => setState(() => _sourceFilter = 'manual'),
                    ),
                  ],
                ),
              ),
              const Divider(height: 20),

              // People List
              Expanded(
                child: peopleAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(
                    child: Text('Error loading people: $e', style: const TextStyle(color: AppColors.danger)),
                  ),
                  data: (people) {
                    var filtered = people.where((p) {
                      if (_sourceFilter == 'family_tree' && !p.isFromFamilyTree) return false;
                      if (_sourceFilter == 'manual' && p.isFromFamilyTree) return false;
                      if (_searchQuery.isNotEmpty) {
                        return p.name.toLowerCase().contains(_searchQuery) ||
                            p.fatherName.toLowerCase().contains(_searchQuery) ||
                            p.phoneNumber.contains(_searchQuery);
                      }
                      return true;
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.person_off_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                            const SizedBox(height: 12),
                            Text(
                              isUrdu ? 'کوئی فرد نہیں ملا' : 'No persons found',
                              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Colors.grey),
                            ),
                            const SizedBox(height: 12),
                            TextButton.icon(
                              icon: const Icon(Icons.person_add, size: 18),
                              label: Text(isUrdu ? 'نیا فرد شامل کریں' : '+ Add New Person'),
                              onPressed: _showAddPersonSheet,
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.separated(
                      controller: scrollController,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      itemCount: filtered.length,
                      separatorBuilder: (ctx, i) => const Divider(height: 1),
                      itemBuilder: (ctx, index) {
                        final person = filtered[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          leading: HamdardUserAvatar(
                            imageUrl: person.profileImageUrl,
                            name: person.name,
                            radius: 22,
                          ),
                          title: Row(
                            children: [
                              Flexible(
                                child: Text(
                                  person.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: person.isFromFamilyTree
                                      ? AppColors.emerald.withValues(alpha: 0.15)
                                      : Colors.grey.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  person.isFromFamilyTree
                                      ? (isUrdu ? 'شجرہ' : 'Tree')
                                      : (isUrdu ? 'دستی' : 'Manual'),
                                  style: TextStyle(
                                    fontSize: 9,
                                    fontWeight: FontWeight.bold,
                                    color: person.isFromFamilyTree ? AppColors.emerald : Colors.grey,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          subtitle: Text(
                            '${isUrdu ? "والد" : "Father"}: ${person.fatherName.isNotEmpty ? person.fatherName : "N/A"} • ${person.phoneNumber}',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                            ),
                          ),
                          trailing: const Icon(Icons.chevron_right, size: 20),
                          onTap: () => Navigator.pop(context, person),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
