import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_donation.dart';
import '../../models/hamdard_person.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import 'hamdard_add_edit_donation_screen.dart';

class HamdardDonorProfileScreen extends ConsumerStatefulWidget {
  final HamdardPerson person;

  const HamdardDonorProfileScreen({super.key, required this.person});

  @override
  ConsumerState<HamdardDonorProfileScreen> createState() => _HamdardDonorProfileScreenState();
}

class _HamdardDonorProfileScreenState extends ConsumerState<HamdardDonorProfileScreen> {
  int _selectedYear = DateTime.now().year;

  static const List<String> _monthNamesEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _monthNamesUr = [
    'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
    'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'
  ];

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
                  ? 'یہ ٹرانزیکشن مالی حسابات سے خارج کر دی جائے گی اور اس کارروائی کا آڈٹ لاگ محفوظ ہو گا۔'
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

    final allDonations = ref.watch(hamdardDonationsStreamProvider).valueOrNull ?? [];
    final donorDonations = allDonations.where((d) => d.personId == widget.person.id).toList();

    // Filter by selected year
    final yearDonations = donorDonations.where((d) => d.date.year == _selectedYear).toList();
    int yearTotal = 0;
    for (final d in yearDonations) {
      yearTotal += d.amount;
    }
    final int donationCount = yearDonations.length;
    final double averageDonation = donationCount > 0 ? (yearTotal / donationCount) : 0.0;

    // Monthly breakdown for all 12 months
    final Map<int, int> monthlyTotals = {for (int m = 1; m <= 12; m++) m: 0};
    for (final d in yearDonations) {
      monthlyTotals[d.date.month] = (monthlyTotals[d.date.month] ?? 0) + d.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'پروفائل عطیہ دہندہ' : 'Donor Profile'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Donor Info Header Card
          Card(
            color: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
                    child: Text(
                      widget.person.name.isNotEmpty ? widget.person.name[0].toUpperCase() : '?',
                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.emerald),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.person.name,
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${isUrdu ? "والد" : "Father"}: ${widget.person.fatherName.isNotEmpty ? widget.person.fatherName : "N/A"}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                        Text(
                          '${isUrdu ? "موبائل" : "Phone"}: ${widget.person.phoneNumber}',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Year Selector Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isUrdu ? 'ماہانہ ریکارڈ' : 'Monthly Breakdown',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              DropdownButton<int>(
                value: _selectedYear,
                dropdownColor: isDark ? AppColors.darkSurface : Colors.white,
                items: [2024, 2025, 2026, 2027].map((yr) {
                  return DropdownMenuItem(value: yr, child: Text('$yr', style: const TextStyle(fontWeight: FontWeight.bold)));
                }).toList(),
                onChanged: (yr) {
                  if (yr != null) setState(() => _selectedYear = yr);
                },
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Year Stats Banner
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppColors.emerald.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('$_selectedYear Total', HamdardRepository.formatPkr(yearTotal), AppColors.emerald),
                _buildStatItem('Donations', '$donationCount', AppColors.gold),
                _buildStatItem('Average', HamdardRepository.formatPkr(averageDonation.round()), AppColors.info),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // 12-Month Table
          Card(
            color: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: List.generate(12, (index) {
                  final monthNum = index + 1;
                  final monthName = isUrdu ? _monthNamesUr[index] : _monthNamesEn[index];
                  final monthAmount = monthlyTotals[monthNum] ?? 0;
                  final hasDonation = monthAmount > 0;

                  return Container(
                    decoration: BoxDecoration(
                      border: index < 11
                          ? Border(
                              bottom: BorderSide(
                                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                width: 0.5,
                              ),
                            )
                          : null,
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(
                              hasDonation ? Icons.check_circle : Icons.radio_button_unchecked,
                              size: 16,
                              color: hasDonation ? AppColors.emerald : Colors.grey,
                            ),
                            const SizedBox(width: 12),
                            Text(
                              monthName,
                              style: TextStyle(
                                fontWeight: hasDonation ? FontWeight.bold : FontWeight.normal,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          hasDonation
                              ? HamdardRepository.formatPkr(monthAmount)
                              : (isUrdu ? 'کوئی عطیہ نہیں' : 'No donation'),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: hasDonation ? FontWeight.bold : FontWeight.normal,
                            color: hasDonation
                                ? AppColors.emerald
                                : (isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary),
                          ),
                        ),
                      ],
                    ),
                  );
                }),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Individual Transactions History
          Text(
            isUrdu ? 'عطیات کی تفصیلی فہرست' : 'Transaction History',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          if (yearDonations.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  isUrdu ? 'اس سال کے لیے کوئی عطیہ نہیں ملا' : 'No donations recorded for $_selectedYear.',
                  style: const TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...yearDonations.map((donation) {
              return Card(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: donation.paymentMethod.color.withValues(alpha: 0.15),
                    child: Icon(donation.paymentMethod.icon, color: donation.paymentMethod.color, size: 20),
                  ),
                  title: Text(
                    HamdardRepository.formatPkr(donation.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.emerald),
                  ),
                  subtitle: Text(
                    '${donation.paymentMethod.label(isUrdu)} • ${DateFormat('dd MMM yyyy').format(donation.date)}${donation.description.isNotEmpty ? " • ${donation.description}" : ""}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: canManage
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 20),
                              tooltip: loc.translate('edit'),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HamdardAddEditDonationScreen(existingDonation: donation),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 20, color: AppColors.danger),
                              tooltip: loc.translate('delete'),
                              onPressed: () => _confirmDeleteDonation(donation),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(label, style: const TextStyle(fontSize: 10.5, color: Colors.grey)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)),
      ],
    );
  }
}
