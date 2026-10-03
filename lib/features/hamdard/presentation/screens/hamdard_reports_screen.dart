import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../models/hamdard_filter.dart';
import '../../models/hamdard_payment_method.dart';
import '../../models/hamdard_spending_category.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import '../../services/hamdard_csv_service.dart';
import '../../services/hamdard_pdf_service.dart';
import '../widgets/hamdard_spending_pie_chart.dart';

class HamdardReportsScreen extends ConsumerStatefulWidget {
  const HamdardReportsScreen({super.key});

  @override
  ConsumerState<HamdardReportsScreen> createState() => _HamdardReportsScreenState();
}

class _HamdardReportsScreenState extends ConsumerState<HamdardReportsScreen> {
  bool _isExportingPdf = false;
  bool _isExportingCsv = false;

  Future<void> _exportPdf() async {
    setState(() => _isExportingPdf = true);
    try {
      final summary = ref.read(hamdardFinancialSummaryProvider);
      final donations = ref.read(hamdardFilteredDonationsProvider);
      final spending = ref.read(hamdardFilteredSpendingProvider);
      final donorStats = ref.read(hamdardPeopleWithStatsProvider);
      final activeFilter = ref.read(hamdardDateFilterProvider);

      await HamdardPdfService.exportAndSharePdf(
        periodTitle: activeFilter.type.name,
        summary: summary,
        donations: donations,
        spending: spending,
        donorStats: donorStats,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Error exporting PDF: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingPdf = false);
    }
  }

  Future<void> _exportCsv() async {
    setState(() => _isExportingCsv = true);
    try {
      final donations = ref.read(hamdardFilteredDonationsProvider);
      final spending = ref.read(hamdardFilteredSpendingProvider);

      await HamdardCsvService.exportAndShareCsv(
        donations: donations,
        spending: spending,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Error exporting CSV: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isExportingCsv = false);
    }
  }

  Future<void> _pickCustomDateRange() async {
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (range != null) {
      ref.read(hamdardDateFilterProvider.notifier).state = HamdardDateRange.forType(
        HamdardDateFilterType.custom,
        customStart: range.start,
        customEnd: range.end,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;

    final summary = ref.watch(hamdardFinancialSummaryProvider);
    final donations = ref.watch(hamdardFilteredDonationsProvider);
    final spending = ref.watch(hamdardFilteredSpendingProvider);
    final activeFilter = ref.watch(hamdardDateFilterProvider);

    int filteredDonationsTotal = 0;
    for (final d in donations) {
      filteredDonationsTotal += d.amount;
    }

    int filteredSpendingTotal = 0;
    for (final s in spending) {
      filteredSpendingTotal += s.amount;
    }

    final netChange = filteredDonationsTotal - filteredSpendingTotal;

    // Filtered payment-method totals
    final Map<HamdardPaymentMethod, int> methodDonations = {for (var m in HamdardPaymentMethod.values) m: 0};
    for (final d in donations) {
      methodDonations[d.paymentMethod] = (methodDonations[d.paymentMethod] ?? 0) + d.amount;
    }

    // Filtered category totals
    final Map<HamdardSpendingCategory, int> categorySpending = {for (var c in HamdardSpendingCategory.values) c: 0};
    for (final s in spending) {
      categorySpending[s.category] = (categorySpending[s.category] ?? 0) + s.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'مالیاتی رپورٹس' : 'Financial Reports'),
        actions: [
          IconButton(
            icon: _isExportingCsv
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.table_view_outlined),
            tooltip: 'Export CSV',
            onPressed: _isExportingCsv ? null : _exportCsv,
          ),
          IconButton(
            icon: _isExportingPdf
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.picture_as_pdf_outlined),
            tooltip: 'Export PDF',
            onPressed: _isExportingPdf ? null : _exportPdf,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Date Filter Selector Bar
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ...[
                  HamdardDateFilterType.thisMonth,
                  HamdardDateFilterType.lastMonth,
                  HamdardDateFilterType.thisYear,
                  HamdardDateFilterType.lastYear,
                  HamdardDateFilterType.allTime,
                ].map((type) {
                  final isSelected = activeFilter.type == type;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(type.label(isUrdu)),
                      selected: isSelected,
                      selectedColor: AppColors.emerald,
                      labelStyle: TextStyle(
                        color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                        fontSize: 12,
                      ),
                      onSelected: (_) {
                        ref.read(hamdardDateFilterProvider.notifier).state = HamdardDateRange.forType(type);
                      },
                    ),
                  );
                }),
                ActionChip(
                  avatar: const Icon(Icons.date_range, size: 16),
                  label: Text(activeFilter.type == HamdardDateFilterType.custom
                      ? '${DateFormat("dd MMM").format(activeFilter.start!)} - ${DateFormat("dd MMM").format(activeFilter.end!)}'
                      : (isUrdu ? 'مخصوص مدت' : 'Custom Range')),
                  backgroundColor: activeFilter.type == HamdardDateFilterType.custom
                      ? AppColors.gold.withValues(alpha: 0.25)
                      : null,
                  onPressed: _pickCustomDateRange,
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Overview KPI Card for Selected Period
          Card(
            color: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${isUrdu ? "خلاصہ برائے" : "Summary for"} ${activeFilter.type.label(isUrdu)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildReportKpi(
                        isUrdu ? 'کل وصولی' : 'Total Collection',
                        HamdardRepository.formatPkr(filteredDonationsTotal),
                        AppColors.emerald,
                      ),
                      _buildReportKpi(
                        isUrdu ? 'کل اخراجات' : 'Total Spending',
                        HamdardRepository.formatPkr(filteredSpendingTotal),
                        AppColors.danger,
                      ),
                      _buildReportKpi(
                        isUrdu ? 'خالص تبدیلی' : 'Net Change',
                        HamdardRepository.formatPkr(netChange),
                        netChange >= 0 ? AppColors.emerald : AppColors.danger,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 1),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        isUrdu ? 'موجودہ مشترکہ میزان' : 'Current Combined Balance',
                        style: TextStyle(
                          fontSize: 13,
                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                        ),
                      ),
                      Text(
                        HamdardRepository.formatPkr(summary.currentBalance),
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.gold),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Spending Distribution Donut Chart
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
                        isUrdu ? 'اخراجات کی تقسیم' : 'Spending Distribution',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        HamdardRepository.formatPkr(filteredSpendingTotal),
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: AppColors.danger),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  HamdardSpendingPieChart(
                    categorySpending: categorySpending,
                    totalSpending: filteredSpendingTotal,
                    isUrdu: isUrdu,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Payment Method Breakdown
          Card(
            color: isDark ? AppColors.darkSurface : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    isUrdu ? 'ادائیگی کے طریقوں کا جائزہ' : 'Payment Method Breakdown',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 14),
                  ...HamdardPaymentMethod.values.map((method) {
                    final amount = methodDonations[method] ?? 0;
                    final pct = filteredDonationsTotal > 0 ? (amount / filteredDonationsTotal) * 100 : 0.0;

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 16,
                            backgroundColor: method.color.withValues(alpha: 0.15),
                            child: Icon(method.icon, color: method.color, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(method.label(isUrdu), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                                Text('${pct.toStringAsFixed(1)}% of donations', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                              ],
                            ),
                          ),
                          Text(
                            HamdardRepository.formatPkr(amount),
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: method.color),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Export Actions
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.table_view),
                  label: Text(isUrdu ? 'ایکسپورٹ CSV' : 'Export CSV'),
                  onPressed: _exportCsv,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.emerald,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: Text(isUrdu ? 'ایکسپورٹ PDF' : 'Export PDF Report'),
                  onPressed: _exportPdf,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _buildReportKpi(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: color)),
      ],
    );
  }
}
