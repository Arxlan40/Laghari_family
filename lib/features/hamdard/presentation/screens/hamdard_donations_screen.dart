import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_donation.dart';
import '../../models/hamdard_payment_method.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import 'hamdard_add_edit_donation_screen.dart';

class HamdardDonationsScreen extends ConsumerStatefulWidget {
  const HamdardDonationsScreen({super.key});

  @override
  ConsumerState<HamdardDonationsScreen> createState() => _HamdardDonationsScreenState();
}

class _HamdardDonationsScreenState extends ConsumerState<HamdardDonationsScreen> {
  String _searchQuery = '';
  HamdardPaymentMethod? _selectedPaymentMethod;

  Future<void> _confirmDeleteDonation(HamdardDonation donation) async {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.read(currentUserProvider);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'عطیہ حذف کریں؟' : 'Delete Donation?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(donation.personNameSnapshot, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              HamdardRepository.formatPkr(donation.amount),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.danger),
            ),
            Text('${donation.paymentMethod.label(loc.isUrdu)} • ${DateFormat('dd MMMM yyyy').format(donation.date)}'),
            const SizedBox(height: 12),
            Text(
              loc.isUrdu
                  ? 'یہ ٹرانزیکشن مالی حسابات سے خارج کر دی جائے گی اور اس کا آڈٹ لاگ محفوظ ہو گا۔'
                  : 'This transaction will be removed from financial calculations and an audit log will be created.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
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
            child: Text(loc.translate('delete')),
          ),
        ],
      ),
    );

    if (confirm == true && currentUser != null) {
      await ref.read(hamdardRepositoryProvider).deleteDonation(
        donation,
        performedBy: currentUser.uid,
        performedByName: currentUser.name,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final currentUser = ref.watch(currentUserProvider);
    final canManage = currentUser?.canManageHamdard ?? false;

    final donationsState = ref.watch(hamdardDonationsStreamProvider);
    final filteredDonations = ref.watch(hamdardFilteredDonationsProvider);
    final activeFilter = ref.watch(hamdardDateFilterProvider);

    // Filter by search & payment method
    final results = filteredDonations.where((d) {
      if (_selectedPaymentMethod != null && d.paymentMethod != _selectedPaymentMethod) {
        return false;
      }
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      return d.personNameSnapshot.toLowerCase().contains(query) ||
          d.fatherNameSnapshot.toLowerCase().contains(query) ||
          d.phoneNumberSnapshot.contains(query) ||
          d.description.toLowerCase().contains(query);
    }).toList();

    int totalAmount = 0;
    for (final d in results) {
      totalAmount += d.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'تمام عطیات' : 'Donations Registry'),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(isUrdu ? 'نیا عطیہ' : 'Add Donation'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HamdardAddEditDonationScreen()),
                );
              },
            )
          : null,
      body: Column(
        children: [
          // Filter & Search Controls
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              children: [
                TextField(
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: isUrdu
                        ? 'عطیہ دہندہ یا فون سے تلاش کریں...'
                        : 'Search by donor or phone...',
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

                // Payment Method Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(isUrdu ? 'تمام طریقے' : 'All Methods'),
                        selected: _selectedPaymentMethod == null,
                        selectedColor: AppColors.emerald,
                        labelStyle: TextStyle(
                          color: _selectedPaymentMethod == null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: _selectedPaymentMethod == null ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                        onSelected: (_) => setState(() => _selectedPaymentMethod = null),
                      ),
                      ...HamdardPaymentMethod.values.map((method) {
                        final isSelected = _selectedPaymentMethod == method;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            avatar: Icon(method.icon, size: 14, color: isSelected ? Colors.white : method.color),
                            label: Text(method.label(isUrdu)),
                            selected: isSelected,
                            selectedColor: method.color,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11.5,
                            ),
                            onSelected: (_) => setState(() => _selectedPaymentMethod = method),
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Total Bar for Current Filter
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${activeFilter.type.label(isUrdu)} • ${results.length} ${isUrdu ? "عطیات" : "Records"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ),
                Text(
                  HamdardRepository.formatPkr(totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.emerald),
                ),
              ],
            ),
          ),

          // Main Donations List
          Expanded(
            child: donationsState.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.emerald),
                    SizedBox(height: 12),
                    Text('Loading donations...'),
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
                      onPressed: () => ref.refresh(hamdardDonationsStreamProvider),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
              data: (_) {
                if (results.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inventory_2_outlined, size: 54, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          isUrdu ? 'اس مدت میں کوئی عطیہ نہیں ملا' : 'No donations found for this period.',
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
                  itemCount: results.length,
                  itemBuilder: (context, i) {
                    final d = results[i];

                    return Card(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      margin: const EdgeInsets.only(bottom: 12),
                      elevation: 1.5,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  backgroundColor: d.paymentMethod.color.withValues(alpha: 0.15),
                                  child: Icon(d.paymentMethod.icon, color: d.paymentMethod.color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        d.personNameSnapshot,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Father: ${d.fatherNameSnapshot.isNotEmpty ? d.fatherNameSnapshot : "N/A"} • ${d.phoneNumberSnapshot}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                        ),
                                      ),
                                      if (d.description.isNotEmpty) ...[
                                        const SizedBox(height: 2),
                                        Text(
                                          d.description,
                                          style: const TextStyle(fontSize: 11.5, fontStyle: FontStyle.italic),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      HamdardRepository.formatPkr(d.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.emerald,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('dd MMM yyyy').format(d.date),
                                      style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            if (canManage) ...[
                              const SizedBox(height: 8),
                              const Divider(height: 1),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  TextButton.icon(
                                    icon: const Icon(Icons.edit_outlined, size: 16),
                                    label: Text(loc.translate('edit'), style: const TextStyle(fontSize: 12)),
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => HamdardAddEditDonationScreen(existingDonation: d),
                                        ),
                                      );
                                    },
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: Text(loc.translate('delete'), style: const TextStyle(fontSize: 12)),
                                    onPressed: () => _confirmDeleteDonation(d),
                                  ),
                                ],
                              ),
                            ],
                          ],
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
}
