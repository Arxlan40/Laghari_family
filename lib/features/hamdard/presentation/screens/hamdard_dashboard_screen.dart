import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_financial_summary.dart';
import '../../models/hamdard_payment_method.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import '../widgets/hamdard_notification_dialog.dart';
import '../widgets/hamdard_spending_pie_chart.dart';
import 'hamdard_add_edit_donation_screen.dart';
import 'hamdard_add_edit_spending_screen.dart';
import 'hamdard_admin_management_screen.dart';
import 'hamdard_donors_screen.dart';
import 'hamdard_json_tools_screen.dart';
import 'hamdard_reports_screen.dart';

class HamdardDashboardScreen extends ConsumerWidget {
  const HamdardDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final currentUser = ref.watch(currentUserProvider);

    final isSuperAdmin = currentUser?.isSuperAdmin ?? false;
    final canManage = currentUser?.canManageHamdard ?? false;

    final summary = ref.watch(hamdardFinancialSummaryProvider);
    final donationsState = ref.watch(hamdardDonationsStreamProvider);
    final spendingState = ref.watch(hamdardSpendingStreamProvider);
    final peopleState = ref.watch(hamdardPeopleStreamProvider);

    final isLoading = donationsState.isLoading || spendingState.isLoading || peopleState.isLoading;
    final hasError = donationsState.hasError || spendingState.hasError || peopleState.hasError;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.volunteer_activism, color: AppColors.emerald, size: 20),
            ),
            const SizedBox(width: 10),
            Text(
              isUrdu ? 'ہمدرد لغاری' : 'Hamdard Laghari',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.assessment_outlined),
            tooltip: isUrdu ? 'رپورٹس' : 'Financial Reports',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HamdardReportsScreen()),
              );
            },
          ),
          if (canManage)
            IconButton(
              icon: const Icon(Icons.campaign_outlined),
              tooltip: isUrdu ? 'اطلاع بھیجیں' : 'Send Notification',
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (_) => const HamdardNotificationDialog(),
                );
              },
            ),
          if (isSuperAdmin)
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert),
              onSelected: (val) {
                if (val == 'admins') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HamdardAdminManagementScreen()),
                  );
                } else if (val == 'json') {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HamdardJsonToolsScreen()),
                  );
                }
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(
                  value: 'admins',
                  child: Row(
                    children: [
                      const Icon(Icons.admin_panel_settings, size: 18, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Text(isUrdu ? 'ہمدرد ایڈمنز' : 'Manage Hamdard Admins'),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'json',
                  child: Row(
                    children: [
                      const Icon(Icons.data_object, size: 18, color: AppColors.emerald),
                      const SizedBox(width: 8),
                      Text(isUrdu ? 'JSON ٹولز' : 'JSON Tools & Backup'),
                    ],
                  ),
                ),
              ],
            ),
        ],
      ),
      body: isLoading
          ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: AppColors.emerald),
                  SizedBox(height: 12),
                  Text('Loading Hamdard Financial Data...'),
                ],
              ),
            )
          : hasError
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      const SizedBox(height: 8),
                      const Text('Unable to load Hamdard financial data.'),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          ref.invalidate(hamdardDonationsStreamProvider);
                          ref.invalidate(hamdardSpendingStreamProvider);
                          ref.invalidate(hamdardPeopleStreamProvider);
                        },
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final isTablet = constraints.maxWidth >= 720;

                    return RefreshIndicator(
                      onRefresh: () async {
                        ref.invalidate(hamdardDonationsStreamProvider);
                        ref.invalidate(hamdardSpendingStreamProvider);
                        ref.invalidate(hamdardPeopleStreamProvider);
                      },
                      child: ListView(
                        padding: const EdgeInsets.all(20),
                        children: [
                          // 1. Primary Highlight Banner: Current Combined Balance
                          _buildPrimaryBalanceBanner(summary, isDark, isUrdu),
                          const SizedBox(height: 20),

                          // 2. Action Shortcuts
                          _buildActionShortcuts(context, canManage, isSuperAdmin, isDark, isUrdu),
                          const SizedBox(height: 24),

                          // 3. Financial Summary Cards Grid
                          Text(
                            isUrdu ? 'مالیاتی خلاصہ' : 'Financial Overview',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          GridView.count(
                            crossAxisCount: isTablet ? 4 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: isTablet ? 1.6 : 1.35,
                            children: [
                              _buildMetricCard(
                                title: isUrdu ? 'اس ماہ وصولی' : "This Month Collection",
                                amount: HamdardRepository.formatPkr(summary.thisMonthCollection),
                                icon: Icons.arrow_downward,
                                color: AppColors.emerald,
                                isDark: isDark,
                              ),
                              _buildMetricCard(
                                title: isUrdu ? 'اس ماہ اخراجات' : "This Month Spending",
                                amount: HamdardRepository.formatPkr(summary.thisMonthSpending),
                                icon: Icons.arrow_upward,
                                color: AppColors.danger,
                                isDark: isDark,
                              ),
                              _buildMetricCard(
                                title: isUrdu ? 'اس سال وصولی' : "This Year Collection",
                                amount: HamdardRepository.formatPkr(summary.thisYearCollection),
                                icon: Icons.calendar_month,
                                color: AppColors.gold,
                                isDark: isDark,
                              ),
                              _buildMetricCard(
                                title: isUrdu ? 'اس سال اخراجات' : "This Year Spending",
                                amount: HamdardRepository.formatPkr(summary.thisYearSpending),
                                icon: Icons.account_balance,
                                color: Colors.orange,
                                isDark: isDark,
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),

                          // 4. Donor Participation Cards
                          Card(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        isUrdu ? 'افراد و عطیات کی شرکت' : 'Donor Participation This Month',
                                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                                      ),
                                      TextButton(
                                        onPressed: () {
                                          Navigator.push(
                                            context,
                                            MaterialPageRoute(builder: (_) => const HamdardDonorsScreen()),
                                          );
                                        },
                                        child: Text(isUrdu ? 'تمام افراد دیکھیں' : 'View Registry'),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),
                                  Row(
                                    children: [
                                      Expanded(
                                        child: _buildParticipantPill(
                                          isUrdu ? 'کل افراد' : 'Total Donors',
                                          '${summary.totalDonors}',
                                          AppColors.info,
                                          isDark,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildParticipantPill(
                                          isUrdu ? 'اس ماہ دیا' : 'Donated',
                                          '${summary.donorsDonatedThisMonth}',
                                          AppColors.emerald,
                                          isDark,
                                        ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: _buildParticipantPill(
                                          isUrdu ? 'باقی افراد' : 'Not Donated',
                                          '${summary.donorsNotDonatedThisMonth}',
                                          AppColors.warning,
                                          isDark,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 5. Dynamic Charts
                          Text(
                            isUrdu ? 'اخراجات کی تفصیلات' : 'Spending Distribution',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          Card(
                            color: isDark ? AppColors.darkSurface : Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: Padding(
                              padding: const EdgeInsets.all(18),
                              child: HamdardSpendingPieChart(
                                categorySpending: summary.categorySpending,
                                totalSpending: summary.totalSpending,
                                isUrdu: isUrdu,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),

                          // 6. Payment Method Breakdown Cards
                          Text(
                            isUrdu ? 'ادائیگی کے طریقوں کے مطابق کل وصولی' : 'Collection by Payment Method',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 12),

                          GridView.count(
                            crossAxisCount: isTablet ? 4 : 2,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            childAspectRatio: 1.8,
                            children: HamdardPaymentMethod.values.map((method) {
                              final amount = summary.paymentMethodDonations[method] ?? 0;
                              return Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isDark ? AppColors.darkSurface : Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  border: Border.all(
                                    color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    CircleAvatar(
                                      radius: 18,
                                      backgroundColor: method.color.withValues(alpha: 0.15),
                                      child: Icon(method.icon, color: method.color, size: 20),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            method.label(isUrdu),
                                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            HamdardRepository.formatPkr(amount),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                              color: method.color,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            }).toList(),
                          ),
                          const SizedBox(height: 32),
                        ],
                      ),
                    );
                  },
                ),
    );
  }

  Widget _buildPrimaryBalanceBanner(HamdardFinancialSummary summary, bool isDark, bool isUrdu) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isDark
              ? [const Color(0xFF064E3B), const Color(0xFF0D1F18)]
              : [const Color(0xFF047857), const Color(0xFF065F46)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF047857).withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isUrdu ? 'موجودہ مشترکہ میزان' : 'CURRENT COMBINED BALANCE',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.1,
                  color: Colors.white70,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.gold.withValues(alpha: 0.25),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.lock_outline, size: 12, color: AppColors.goldLight),
                    const SizedBox(width: 4),
                    Text(
                      isUrdu ? 'محفوظ آڈٹ' : 'Verified',
                      style: const TextStyle(fontSize: 10, color: AppColors.goldLight, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            HamdardRepository.formatPkr(summary.currentBalance),
            style: const TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${isUrdu ? "ابتدائی بیلنس" : "Opening"}: ${HamdardRepository.formatPkr(summary.openingBalance)}  +  ${isUrdu ? "عطیات" : "Donations"}: ${HamdardRepository.formatPkr(summary.totalDonations)}  -  ${isUrdu ? "اخراجات" : "Spending"}: ${HamdardRepository.formatPkr(summary.totalSpending)}',
            style: const TextStyle(fontSize: 11, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildActionShortcuts(BuildContext context, bool canManage, bool isSuperAdmin, bool isDark, bool isUrdu) {
    return Row(
      children: [
        if (canManage) ...[
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.add_circle_outline),
              label: Text(isUrdu ? 'نیا عطیہ' : 'Add Donation'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HamdardAddEditDonationScreen()),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.danger,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.remove_circle_outline),
              label: Text(isUrdu ? 'نیا خرچ' : 'Add Spending'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HamdardAddEditSpendingScreen()),
                );
              },
            ),
          ),
        ] else ...[
          Expanded(
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.people),
              label: Text(isUrdu ? 'افراد کی فہرست' : 'Donors List'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HamdardDonorsScreen()),
                );
              },
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.emerald,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              icon: const Icon(Icons.assessment),
              label: Text(isUrdu ? 'رپورٹس' : 'View Reports'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HamdardReportsScreen()),
                );
              },
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String amount,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? AppColors.darkBorder : AppColors.lightBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11.5, color: Colors.grey, fontWeight: FontWeight.w500),
                ),
              ),
              CircleAvatar(
                radius: 14,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Icon(icon, size: 14, color: color),
              ),
            ],
          ),
          Text(
            amount,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildParticipantPill(String label, String value, Color color, bool isDark) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 10, color: Colors.grey)),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: color),
          ),
        ],
      ),
    );
  }
}
