import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../family_tree/models/family_member.dart';
import '../../../family_tree/repositories/family_repository.dart';
import 'hamdard_user_avatar.dart';

class HamdardFamilyMemberPickerModal extends ConsumerStatefulWidget {
  const HamdardFamilyMemberPickerModal({super.key});

  static Future<FamilyMember?> show(BuildContext context) {
    return showModalBottomSheet<FamilyMember>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const HamdardFamilyMemberPickerModal(),
    );
  }

  @override
  ConsumerState<HamdardFamilyMemberPickerModal> createState() => _HamdardFamilyMemberPickerModalState();
}

class _HamdardFamilyMemberPickerModalState extends ConsumerState<HamdardFamilyMemberPickerModal> {
  String _searchQuery = '';
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final membersState = ref.watch(familyMembersStreamProvider);

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
              const SizedBox(height: 14),

              // Title Header
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
                      child: const Icon(Icons.account_tree, color: AppColors.emerald, size: 20),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            isUrdu ? 'شجرہ نسب سے فرد منتخب کریں' : 'Select from Family Tree',
                            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            isUrdu
                              ? 'صحیح شناختی کوڈ کے تحت فرد کا انتخاب کریں'
                              : 'Select person by unique family member identity',
                            style: TextStyle(
                              fontSize: 11,
                              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Search TextField
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: isUrdu
                        ? 'نام، والد کا نام یا شناختی کوڈ سے تلاش کریں...'
                        : 'Search by name, father name, or ID...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    suffixIcon: _searchQuery.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: () {
                              _searchCtrl.clear();
                              setState(() => _searchQuery = '');
                            },
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
              const SizedBox(height: 10),

              // Members List
              Expanded(
                child: membersState.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(color: AppColors.emerald),
                  ),
                  error: (err, _) => Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text('Error loading family members: $err'),
                    ),
                  ),
                  data: (members) {
                    final filtered = members.where((m) {
                      if (_searchQuery.isEmpty) return true;
                      final nEn = m.nameEn.toLowerCase();
                      final nUr = m.nameUr.toLowerCase();
                      final father = (m.fatherId != null ? members.firstWhere((p) => p.id == m.fatherId, orElse: () => m).nameEn : '').toLowerCase();
                      final phone = (m.phoneNumber ?? '').toLowerCase();
                      final id = m.id.toLowerCase();
                      return nEn.contains(_searchQuery) ||
                          nUr.contains(_searchQuery) ||
                          father.contains(_searchQuery) ||
                          phone.contains(_searchQuery) ||
                          id.contains(_searchQuery);
                    }).toList();

                    if (filtered.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(Icons.person_search, size: 48, color: Colors.grey),
                            const SizedBox(height: 8),
                            Text(
                              isUrdu ? 'کوئی فرد نہیں ملا' : 'No family tree members found.',
                              style: const TextStyle(color: Colors.grey),
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
                      itemBuilder: (context, index) {
                        final member = filtered[index];
                        final displayName = isUrdu && member.nameUr.isNotEmpty ? member.nameUr : member.nameEn;
                        
                        String fatherDisplay = '';
                        if (member.fatherId != null && member.fatherId!.isNotEmpty) {
                          final fatherMember = members.cast<FamilyMember?>().firstWhere(
                                (m) => m?.id == member.fatherId,
                                orElse: () => null,
                              );
                          if (fatherMember != null) {
                            fatherDisplay = isUrdu && fatherMember.nameUr.isNotEmpty ? fatherMember.nameUr : fatherMember.nameEn;
                          }
                        }

                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          leading: HamdardUserAvatar(
                            imageUrl: member.imageUrl,
                            name: member.nameEn,
                            size: 44,
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  displayName,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14.5),
                                ),
                              ),
                              if (member.bloodGroup != null && member.bloodGroup!.isNotEmpty && member.bloodGroup != 'Unknown')
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    member.bloodGroup!,
                                    style: const TextStyle(fontSize: 9.5, color: Colors.red, fontWeight: FontWeight.bold),
                                  ),
                                ),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                fatherDisplay.isNotEmpty
                                    ? (isUrdu ? 'والد: $fatherDisplay' : 'Father: $fatherDisplay')
                                    : 'Gen ${member.generation}',
                                style: const TextStyle(fontSize: 12),
                              ),
                              if (member.phoneNumber != null && member.phoneNumber!.isNotEmpty)
                                Text(
                                  member.phoneNumber!,
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                            ],
                          ),
                          trailing: const Icon(Icons.check_circle_outline, color: AppColors.emerald, size: 22),
                          onTap: () => Navigator.pop(context, member),
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
