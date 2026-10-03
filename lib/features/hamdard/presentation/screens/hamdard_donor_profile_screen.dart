import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_donation.dart';
import '../../models/hamdard_person.dart';
import '../../models/hamdard_spending.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import '../widgets/hamdard_family_member_picker_modal.dart';
import '../widgets/hamdard_user_avatar.dart';
import 'hamdard_add_edit_donation_screen.dart';
import 'hamdard_add_edit_spending_screen.dart';

class HamdardDonorProfileScreen extends ConsumerStatefulWidget {
  final HamdardPerson person;

  const HamdardDonorProfileScreen({super.key, required this.person});

  @override
  ConsumerState<HamdardDonorProfileScreen> createState() => _HamdardDonorProfileScreenState();
}

class _HamdardDonorProfileScreenState extends ConsumerState<HamdardDonorProfileScreen>
    with SingleTickerProviderStateMixin {
  int _selectedYear = DateTime.now().year;
  late TabController _tabController;

  static const List<String> _monthNamesEn = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];

  static const List<String> _monthNamesUr = [
    'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون',
    'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _linkToFamilyTree(HamdardPerson currentPerson) async {
    final loc = AppLocalizations.of(context);
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final selectedMember = await HamdardFamilyMemberPickerModal.show(context);
    if (selectedMember == null || !mounted) return;

    try {
      await ref.read(hamdardRepositoryProvider).linkPersonToFamilyMember(
            personId: currentPerson.id,
            familyMemberId: selectedMember.id,
            profileImageUrl: selectedMember.imageUrl,
            bloodGroup: selectedMember.bloodGroup,
            profession: selectedMember.profession,
            gender: selectedMember.gender,
            performedBy: currentUser.uid,
            performedByName: currentUser.name,
          );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text(loc.isUrdu
                ? 'فرد کو شجرہ نسب سے کامیابی کے ساتھ منسلک کر دیا گیا'
                : 'Person linked to family tree successfully.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error linking family tree member: $e'),
          ),
        );
      }
    }
  }

  Future<void> _confirmChangeOrUnlink(HamdardPerson currentPerson) async {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'شجرہ نسب کا ربط تبدیل کریں؟' : 'Change Family Tree Link?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.gold.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.gold, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      loc.isUrdu
                          ? 'عطیات اور اخراجات کا تاریخی ریکارڈ حذف نہیں ہو گا۔ صرف منسلک خاندانی شناختی کوڈ بدلے گا۔'
                          : 'Your donation and spending history will not be deleted. Only the linked family-tree member will be changed.',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            Text(
              loc.isUrdu
                  ? 'آپ کیا کرنا چاہتے ہیں؟'
                  : 'What would you like to do?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'cancel'),
            child: Text(loc.translate('cancel')),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, 'unlink'),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: Text(loc.isUrdu ? 'ربط ختم کریں' : 'Unlink'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, 'change'),
            child: Text(loc.isUrdu ? 'نیا فرد منتخب کریں' : 'Change Member'),
          ),
        ],
      ),
    );

    if (action == 'unlink') {
      try {
        await ref.read(hamdardRepositoryProvider).unlinkPersonFromFamilyMember(
              personId: currentPerson.id,
              performedBy: currentUser.uid,
              performedByName: currentUser.name,
            );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: AppColors.emerald,
              content: Text(loc.isUrdu
                  ? 'شجرہ نسب کا ربط ختم کر دیا گیا'
                  : 'Family tree link removed. Person is now manual.'),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(backgroundColor: AppColors.danger, content: Text('Error: $e')),
          );
        }
      }
    } else if (action == 'change') {
      await _linkToFamilyTree(currentPerson);
    }
  }

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

  Future<void> _confirmDeleteSpending(HamdardSpending spending) async {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.read(currentUserProvider);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'اخراجات کا ریکارڈ حذف کریں؟' : 'Delete Spending Record?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(spending.recipientName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 4),
            Text(
              HamdardRepository.formatPkr(spending.amount),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.danger),
            ),
            Text('${spending.category.label(loc.isUrdu)} • ${DateFormat('dd MMMM yyyy').format(spending.date)}'),
            const SizedBox(height: 12),
            Text(
              loc.isUrdu
                  ? 'یہ رقم اخراجات سے منہا ہو جائے گی اور میزان میں خودکار اضافہ ہو جائے گا۔'
                  : 'This transaction will be removed from financial calculations and balance will automatically update.',
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
      await ref.read(hamdardRepositoryProvider).deleteSpending(
        spending,
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

    // Watch live person record
    final allPeople = ref.watch(hamdardPeopleStreamProvider).valueOrNull ?? [];
    final livePerson = allPeople.firstWhere(
      (p) => p.id == widget.person.id,
      orElse: () => widget.person,
    );

    // Watch donations
    final allDonations = ref.watch(hamdardDonationsStreamProvider).valueOrNull ?? [];
    final donorDonations = allDonations.where((d) => d.personId == livePerson.id).toList();

    // Watch spending (assistance received)
    final allSpending = ref.watch(hamdardSpendingStreamProvider).valueOrNull ?? [];
    final normPhone = HamdardPerson.normalizePhone(livePerson.phoneNumber);
    final recipientSpending = allSpending.where((s) {
      if (s.personId != null && s.personId == livePerson.id) return true;
      if (normPhone.isNotEmpty &&
          (s.personId == null || s.personId!.isEmpty) &&
          HamdardPerson.normalizePhone(s.recipientPhoneNumber) == normPhone) {
        return true;
      }
      return false;
    }).toList();

    // Year donations
    final yearDonations = donorDonations.where((d) => d.date.year == _selectedYear).toList();
    int yearDonationTotal = 0;
    for (final d in yearDonations) {
      yearDonationTotal += d.amount;
    }
    final int donationCount = yearDonations.length;
    final double averageDonation = donationCount > 0 ? (yearDonationTotal / donationCount) : 0.0;

    int allTimeDonationTotal = 0;
    for (final d in donorDonations) {
      allTimeDonationTotal += d.amount;
    }

    int allTimeAssistanceTotal = 0;
    for (final s in recipientSpending) {
      allTimeAssistanceTotal += s.amount;
    }

    // Monthly breakdown for selected year
    final Map<int, int> monthlyTotals = {for (int m = 1; m <= 12; m++) m: 0};
    for (final d in yearDonations) {
      monthlyTotals[d.date.month] = (monthlyTotals[d.date.month] ?? 0) + d.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'ہمدرد فرد پروفائل' : 'Hamdard Person Profile'),
        actions: [
          if (canManage)
            IconButton(
              icon: const Icon(Icons.volunteer_activism),
              tooltip: isUrdu ? 'عطیہ درج کریں' : 'Add Donation',
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => HamdardAddEditDonationScreen(preselectedPerson: livePerson),
                  ),
                );
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // 1. Person Header Card with Avatar & Family Tree Status
          Card(
            color: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HamdardUserAvatar(
                        imageUrl: livePerson.profileImageUrl,
                        name: livePerson.name,
                        size: 64,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              livePerson.name,
                              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${isUrdu ? "والد" : "Father"}: ${livePerson.fatherName.isNotEmpty ? livePerson.fatherName : "N/A"}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                              ),
                            ),
                            Text(
                              '${isUrdu ? "موبائل" : "Phone"}: ${livePerson.phoneNumber}',
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                              ),
                            ),
                            if (livePerson.bloodGroup != null && livePerson.bloodGroup!.isNotEmpty && livePerson.bloodGroup != 'Unknown') ...[
                              const SizedBox(height: 2),
                              Text(
                                'Blood Group: ${livePerson.bloodGroup}',
                                style: const TextStyle(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  const Divider(height: 1),
                  const SizedBox(height: 14),

                  // Source & Family Tree Connection Bar
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      if (livePerson.isFromFamilyTree) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.account_tree, size: 14, color: AppColors.emerald),
                              const SizedBox(width: 6),
                              Text(
                                isUrdu ? 'شجرہ نسب سے منسلک' : 'Family Tree Member',
                                style: const TextStyle(fontSize: 11.5, color: AppColors.emerald, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        ),
                        if (canManage)
                          TextButton.icon(
                            style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                            icon: const Icon(Icons.link_off, size: 16, color: Colors.grey),
                            label: Text(isUrdu ? 'ربط تبدیل کریں' : 'Change Link', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                            onPressed: () => _confirmChangeOrUnlink(livePerson),
                          ),
                      ] else ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.grey.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.edit_note, size: 14, color: Colors.grey),
                              const SizedBox(width: 6),
                              Text(
                                isUrdu ? 'دستی اندراج (غیر منسلک)' : 'Manual Record',
                                style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        if (canManage)
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              visualDensity: VisualDensity.compact,
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                            ),
                            icon: const Icon(Icons.add_link, size: 16),
                            label: Text(isUrdu ? 'شجرہ نسب سے جوڑیں' : 'Link to Family Tree', style: const TextStyle(fontSize: 11)),
                            onPressed: () => _linkToFamilyTree(livePerson),
                          ),
                      ],
                    ],
                  ),

                  // View in Family Tree Button (if linked)
                  if (livePerson.isFromFamilyTree) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.visibility, size: 16, color: AppColors.gold),
                            label: Text(isUrdu ? 'شجرہ نسب میں دیکھیں' : 'View in Family Tree'),
                            onPressed: () {
                              context.push('/family-tree?focusMemberId=${livePerson.familyMemberId}');
                            },
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.badge, size: 16, color: AppColors.emerald),
                            label: Text(isUrdu ? 'خاندانی پروفائل' : 'Family Member'),
                            onPressed: () {
                              context.push('/member/${livePerson.familyMemberId}');
                            },
                          ),
                        ),
                      ],
                    ),
                  ],

                  const SizedBox(height: 14),
                  // Financial Overview Highlights
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: AppColors.emerald.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUrdu ? 'کل عطیات' : 'Total Donated',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                HamdardRepository.formatPkr(allTimeDonationTotal),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: AppColors.emerald),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                          decoration: BoxDecoration(
                            color: Colors.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUrdu ? 'موصولہ امداد' : 'Assistance Received',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                HamdardRepository.formatPkr(allTimeAssistanceTotal),
                                style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Colors.orange),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // 2. Tab Bar: Donation History & Assistance History
          TabBar(
            controller: _tabController,
            labelColor: AppColors.emerald,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.emerald,
            indicatorWeight: 3,
            tabs: [
              Tab(
                text: isUrdu
                    ? 'عطیات تاریخچہ (${donorDonations.length})'
                    : 'Donations (${donorDonations.length})',
                icon: const Icon(Icons.volunteer_activism, size: 18),
              ),
              Tab(
                text: isUrdu
                    ? 'موصولہ امداد (${recipientSpending.length})'
                    : 'Assistance (${recipientSpending.length})',
                icon: const Icon(Icons.handshake, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Tab View Body (using shrinkWrap layout in scroll view)
          AnimatedBuilder(
            animation: _tabController,
            builder: (context, _) {
              if (_tabController.index == 0) {
                return _buildDonationHistorySection(
                  yearDonations: yearDonations,
                  yearDonationTotal: yearDonationTotal,
                  donationCount: donationCount,
                  averageDonation: averageDonation,
                  monthlyTotals: monthlyTotals,
                  canManage: canManage,
                  isDark: isDark,
                  isUrdu: isUrdu,
                );
              } else {
                return _buildAssistanceHistorySection(
                  spendingList: recipientSpending,
                  totalAssistance: allTimeAssistanceTotal,
                  canManage: canManage,
                  isDark: isDark,
                  isUrdu: isUrdu,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildDonationHistorySection({
    required List<HamdardDonation> yearDonations,
    required int yearDonationTotal,
    required int donationCount,
    required double averageDonation,
    required Map<int, int> monthlyTotals,
    required bool canManage,
    required bool isDark,
    required bool isUrdu,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Year Selector Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isUrdu ? 'سالانہ عطیات کی تفصیل' : 'Monthly Breakdown',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkSurface : Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
              ),
              child: DropdownButton<int>(
                value: _selectedYear,
                underline: const SizedBox(),
                items: [
                  for (int y = DateTime.now().year; y >= 2024; y--)
                    DropdownMenuItem(value: y, child: Text('$y')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _selectedYear = val);
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Year Summary Stats Banner
        Card(
          color: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem('$_selectedYear Total', HamdardRepository.formatPkr(yearDonationTotal), AppColors.emerald),
                _buildStatItem('Donations', '$donationCount', AppColors.gold),
                _buildStatItem('Average', HamdardRepository.formatPkr(averageDonation.round()), AppColors.info),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // 12 Months Table Card
        Card(
          color: isDark ? AppColors.darkSurface : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                for (int m = 1; m <= 12; m++) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          isUrdu ? _monthNamesUr[m - 1] : _monthNamesEn[m - 1],
                          style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                        ),
                        monthlyTotals[m]! > 0
                            ? Text(
                                HamdardRepository.formatPkr(monthlyTotals[m]!),
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.emerald,
                                  fontSize: 14,
                                ),
                              )
                            : Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: Colors.grey.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  isUrdu ? 'عطیہ نہیں' : 'No donation',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),
                  if (m < 12) const Divider(height: 1),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),

        // Transactions List for this year
        Text(
          isUrdu ? '$_selectedYear کے عطیات کی فہرست' : 'Donation Transactions ($_selectedYear)',
          style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),

        if (yearDonations.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                isUrdu ? 'اس سال کے لیے کوئی عطیہ نہیں ہے۔' : 'No donations recorded for $_selectedYear.',
                style: const TextStyle(color: Colors.grey),
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: yearDonations.length,
            itemBuilder: (ctx, i) {
              final donation = yearDonations[i];
              return Card(
                color: isDark ? AppColors.darkSurface : Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: donation.paymentMethod.color.withValues(alpha: 0.15),
                    child: Icon(donation.paymentMethod.icon, color: donation.paymentMethod.color, size: 20),
                  ),
                  title: Text(
                    HamdardRepository.formatPkr(donation.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.emerald, fontSize: 15),
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
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HamdardAddEditDonationScreen(donationToEdit: donation),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                              onPressed: () => _confirmDeleteDonation(donation),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildAssistanceHistorySection({
    required List<HamdardSpending> spendingList,
    required int totalAssistance,
    required bool canManage,
    required bool isDark,
    required bool isUrdu,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              isUrdu ? 'موصولہ امداد کی تفصیل' : 'Welfare Assistance Received',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            if (canManage)
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.orange,
                  foregroundColor: Colors.white,
                  visualDensity: VisualDensity.compact,
                ),
                icon: const Icon(Icons.add, size: 16),
                label: Text(isUrdu ? 'امداد درج کریں' : 'Add Spending'),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => HamdardAddEditSpendingScreen(preselectedPerson: widget.person),
                    ),
                  );
                },
              ),
          ],
        ),
        const SizedBox(height: 12),

        if (spendingList.isEmpty)
          Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                children: [
                  Icon(Icons.handshake_outlined, size: 48, color: Colors.grey.withValues(alpha: 0.4)),
                  const SizedBox(height: 8),
                  Text(
                    isUrdu
                        ? 'اس فرد کو ابھی تک کوئی مالی امداد نہیں دی گئی۔'
                        : 'No welfare assistance records found for this person.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: spendingList.length,
            itemBuilder: (ctx, i) {
              final spending = spendingList[i];
              return Card(
                color: isDark ? AppColors.darkSurface : Colors.white,
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: spending.category.color.withValues(alpha: 0.15),
                    child: Icon(spending.category.icon, color: spending.category.color, size: 20),
                  ),
                  title: Text(
                    HamdardRepository.formatPkr(spending.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange, fontSize: 15),
                  ),
                  subtitle: Text(
                    '${spending.category.label(isUrdu)} • ${spending.paymentMethod.label(isUrdu)} • ${DateFormat('dd MMM yyyy').format(spending.date)}${spending.description.isNotEmpty ? " • ${spending.description}" : ""}',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: canManage
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.edit_outlined, size: 18),
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HamdardAddEditSpendingScreen(spendingToEdit: spending),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline, size: 18, color: AppColors.danger),
                              onPressed: () => _confirmDeleteSpending(spending),
                            ),
                          ],
                        )
                      : null,
                ),
              );
            },
          ),
      ],
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color)),
        const SizedBox(height: 2),
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
      ],
    );
  }
}
