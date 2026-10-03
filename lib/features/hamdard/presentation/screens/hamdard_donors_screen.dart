import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_person.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import 'hamdard_donor_profile_screen.dart';

enum DonorFilterMode { all, donatedThisMonth, notDonatedThisMonth }

class HamdardDonorsScreen extends ConsumerStatefulWidget {
  const HamdardDonorsScreen({super.key});

  @override
  ConsumerState<HamdardDonorsScreen> createState() => _HamdardDonorsScreenState();
}

class _HamdardDonorsScreenState extends ConsumerState<HamdardDonorsScreen> {
  String _searchQuery = '';
  DonorFilterMode _filterMode = DonorFilterMode.all;

  void _showAddDonorDialog() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final nameCtrl = TextEditingController();
    final fatherCtrl = TextEditingController();
    final phoneCtrl = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'نیا عطیہ دہندہ شامل کریں' : 'Add New Donor'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: loc.isUrdu ? 'نام' : 'Full Name',
                  prefixIcon: const Icon(Icons.person),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: fatherCtrl,
                decoration: InputDecoration(
                  labelText: loc.isUrdu ? 'والد کا نام' : "Father's Name",
                  prefixIcon: const Icon(Icons.person_outline),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => (v == null || v.trim().isEmpty) ? "Father's name is required" : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: phoneCtrl,
                keyboardType: TextInputType.phone,
                decoration: InputDecoration(
                  labelText: loc.isUrdu ? 'موبائل نمبر (03XXXXXXXXX)' : 'Phone Number (03XXXXXXXXX)',
                  prefixIcon: const Icon(Icons.phone),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) return 'Phone is required';
                  if (!HamdardPerson.isValidPakistaniPhone(v)) {
                    return 'Enter valid 11-digit mobile number';
                  }
                  return null;
                },
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
              if (formKey.currentState!.validate()) {
                final currentUser = ref.read(currentUserProvider);
                if (currentUser != null) {
                  final newPerson = HamdardPerson(
                    id: '',
                    name: nameCtrl.text.trim(),
                    fatherName: fatherCtrl.text.trim(),
                    phoneNumber: HamdardPerson.normalizePhone(phoneCtrl.text.trim()),
                  );
                  await ref.read(hamdardRepositoryProvider).savePerson(
                    newPerson,
                    performedBy: currentUser.uid,
                    performedByName: currentUser.name,
                  );
                }
                if (ctx.mounted) Navigator.pop(ctx);
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
    final currentUser = ref.watch(currentUserProvider);
    final canManage = currentUser?.canManageHamdard ?? false;

    final peopleStatsAsync = ref.watch(hamdardPeopleWithStatsProvider);
    final peopleState = ref.watch(hamdardPeopleStreamProvider);

    // Apply filter mode & search query
    final filtered = peopleStatsAsync.where((stat) {
      if (_filterMode == DonorFilterMode.donatedThisMonth && stat.thisMonthTotal <= 0) {
        return false;
      }
      if (_filterMode == DonorFilterMode.notDonatedThisMonth && stat.thisMonthTotal > 0) {
        return false;
      }

      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      return stat.person.name.toLowerCase().contains(query) ||
          stat.person.fatherName.toLowerCase().contains(query) ||
          stat.person.phoneNumber.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'ہمدرد افراد و عطیہ دہندگان' : 'Hamdard People & Donors'),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.person_add),
              label: Text(isUrdu ? 'شخص شامل کریں' : 'Add Person'),
              onPressed: _showAddDonorDialog,
            )
          : null,
      body: Column(
        children: [
          // Search & Filter Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: isUrdu
                        ? 'نام، والد، یا فون نمبر سے تلاش کریں...'
                        : 'Search by name, father name, or phone...',
                    filled: true,
                    fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 10),

                // Filter Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(isUrdu ? 'تمام افراد (${peopleStatsAsync.length})' : 'All (${peopleStatsAsync.length})'),
                        selected: _filterMode == DonorFilterMode.all,
                        selectedColor: AppColors.emerald,
                        labelStyle: TextStyle(
                          color: _filterMode == DonorFilterMode.all ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: _filterMode == DonorFilterMode.all ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                        onSelected: (_) => setState(() => _filterMode = DonorFilterMode.all),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(isUrdu ? 'اس ماہ عطیہ دیا' : 'Donated This Month'),
                        selected: _filterMode == DonorFilterMode.donatedThisMonth,
                        selectedColor: AppColors.emerald,
                        labelStyle: TextStyle(
                          color: _filterMode == DonorFilterMode.donatedThisMonth ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: _filterMode == DonorFilterMode.donatedThisMonth ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                        onSelected: (_) => setState(() => _filterMode = DonorFilterMode.donatedThisMonth),
                      ),
                      const SizedBox(width: 8),
                      ChoiceChip(
                        label: Text(isUrdu ? 'اس ماہ کوئی عطیہ نہیں' : 'No Donation This Month'),
                        selected: _filterMode == DonorFilterMode.notDonatedThisMonth,
                        selectedColor: AppColors.gold,
                        labelStyle: TextStyle(
                          color: _filterMode == DonorFilterMode.notDonatedThisMonth ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: _filterMode == DonorFilterMode.notDonatedThisMonth ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                        onSelected: (_) => setState(() => _filterMode = DonorFilterMode.notDonatedThisMonth),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Main List View with Loading / Empty / Error handling
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
              error: (err, stack) => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                    const SizedBox(height: 8),
                    Text('Error: $err'),
                    ElevatedButton(
                      onPressed: () => ref.refresh(hamdardPeopleStreamProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (_) {
                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people_outline, size: 54, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          isUrdu ? 'کوئی شخص نہیں ملا' : 'No donors found',
                          style: TextStyle(
                            fontSize: 15,
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
                  itemBuilder: (context, i) {
                    final item = filtered[i];
                    final p = item.person;
                    final hasDonatedThisMonth = item.thisMonthTotal > 0;

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
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 24,
                                    backgroundColor: hasDonatedThisMonth
                                        ? AppColors.emerald.withValues(alpha: 0.15)
                                        : Colors.grey.withValues(alpha: 0.15),
                                    child: Text(
                                      p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: hasDonatedThisMonth ? AppColors.emerald : Colors.grey,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          p.name,
                                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${isUrdu ? "والد" : "Father"}: ${p.fatherName.isNotEmpty ? p.fatherName : "N/A"}',
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                          ),
                                        ),
                                        Text(
                                          '${isUrdu ? "فون" : "Phone"}: ${p.phoneNumber}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(Icons.chevron_right, color: Colors.grey),
                                ],
                              ),
                              const SizedBox(height: 12),
                              const Divider(height: 1),
                              const SizedBox(height: 10),

                              // Metrics Grid: This Month, This Year, Total
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  _buildDonorMetric(
                                    isUrdu ? 'اس ماہ' : 'This Month',
                                    hasDonatedThisMonth
                                        ? HamdardRepository.formatPkr(item.thisMonthTotal)
                                        : (isUrdu ? 'کوئی نہیں' : 'None'),
                                    hasDonatedThisMonth ? AppColors.emerald : Colors.grey,
                                  ),
                                  _buildDonorMetric(
                                    isUrdu ? 'اس سال' : 'This Year',
                                    HamdardRepository.formatPkr(item.thisYearTotal),
                                    AppColors.gold,
                                  ),
                                  _buildDonorMetric(
                                    isUrdu ? 'کل میزان' : 'All-Time Total',
                                    HamdardRepository.formatPkr(item.allTimeTotal),
                                    AppColors.info,
                                  ),
                                ],
                              ),
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

  Widget _buildDonorMetric(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
        const SizedBox(height: 2),
        Text(value, style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: color)),
      ],
    );
  }
}
