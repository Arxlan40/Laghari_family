import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_payment_method.dart';
import '../../models/hamdard_spending.dart';
import '../../models/hamdard_spending_category.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import 'hamdard_add_edit_spending_screen.dart';

class HamdardSpendingScreen extends ConsumerStatefulWidget {
  const HamdardSpendingScreen({super.key});

  @override
  ConsumerState<HamdardSpendingScreen> createState() => _HamdardSpendingScreenState();
}

class _HamdardSpendingScreenState extends ConsumerState<HamdardSpendingScreen> {
  String _searchQuery = '';
  HamdardSpendingCategory? _selectedCategory;
  HamdardPaymentMethod? _selectedPaymentMethod;

  Future<void> _confirmDeleteSpending(HamdardSpending spending) async {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.read(currentUserProvider);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'خرچ حذف کریں؟' : 'Delete Spending?'),
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
                  ? 'یہ ٹرانزیکشن مالی حسابات سے خارج کر دی جائے گی اور اس کا آڈٹ لاگ محفوظ ہو گا۔'
                  : 'This spending record will be removed from financial calculations and an audit log will be created.',
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

    final spendingState = ref.watch(hamdardSpendingStreamProvider);
    final filteredSpending = ref.watch(hamdardFilteredSpendingProvider);
    final activeFilter = ref.watch(hamdardDateFilterProvider);

    // Apply filters
    final results = filteredSpending.where((s) {
      if (_selectedCategory != null && s.category != _selectedCategory) {
        return false;
      }
      if (_selectedPaymentMethod != null && s.paymentMethod != _selectedPaymentMethod) {
        return false;
      }
      final query = _searchQuery.toLowerCase().trim();
      if (query.isEmpty) return true;
      return s.recipientName.toLowerCase().contains(query) ||
          s.recipientFatherName.toLowerCase().contains(query) ||
          s.recipientPhoneNumber.contains(query) ||
          s.description.toLowerCase().contains(query);
    }).toList();

    int totalAmount = 0;
    for (final s in results) {
      totalAmount += s.amount;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'تمام اخراجات' : 'Spending Registry'),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
              icon: const Icon(Icons.add),
              label: Text(isUrdu ? 'نیا خرچ' : 'Add Spending'),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const HamdardAddEditSpendingScreen()),
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
                        ? 'مستحق یا فون سے تلاش کریں...'
                        : 'Search by recipient, father, or phone...',
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

                // Category Chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ChoiceChip(
                        label: Text(isUrdu ? 'تمام زمرہ جات' : 'All Categories'),
                        selected: _selectedCategory == null,
                        selectedColor: AppColors.danger,
                        labelStyle: TextStyle(
                          color: _selectedCategory == null ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                          fontWeight: _selectedCategory == null ? FontWeight.bold : FontWeight.normal,
                          fontSize: 11.5,
                        ),
                        onSelected: (_) => setState(() => _selectedCategory = null),
                      ),
                      ...HamdardSpendingCategory.values.map((cat) {
                        final isSelected = _selectedCategory == cat;
                        return Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: ChoiceChip(
                            avatar: Icon(cat.icon, size: 14, color: isSelected ? Colors.white : cat.color),
                            label: Text(cat.label(isUrdu)),
                            selected: isSelected,
                            selectedColor: cat.color,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white70 : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                              fontSize: 11.5,
                            ),
                            onSelected: (_) => setState(() => _selectedCategory = cat),
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
                  '${activeFilter.type.label(isUrdu)} • ${results.length} ${isUrdu ? "ریکارڈز" : "Records"}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ),
                Text(
                  HamdardRepository.formatPkr(totalAmount),
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.danger),
                ),
              ],
            ),
          ),

          // Main Spending List
          Expanded(
            child: spendingState.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.danger),
                    SizedBox(height: 12),
                    Text('Loading spending records...'),
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
                      onPressed: () => ref.refresh(hamdardSpendingStreamProvider),
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
                        Icon(Icons.money_off, size: 54, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          isUrdu ? 'اس مدت میں کوئی اخراجات نہیں ملے' : 'No spending records found for this period.',
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
                    final s = results[i];

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
                                  backgroundColor: s.category.color.withValues(alpha: 0.15),
                                  child: Icon(s.category.icon, color: s.category.color, size: 20),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        s.recipientName,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Father: ${s.recipientFatherName.isNotEmpty ? s.recipientFatherName : "N/A"} • ${s.recipientPhoneNumber}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                        ),
                                      ),
                                      const SizedBox(height: 3),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: s.category.color.withValues(alpha: 0.15),
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          s.category.label(isUrdu),
                                          style: TextStyle(
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.bold,
                                            color: s.category.color,
                                          ),
                                        ),
                                      ),
                                      if (s.description.isNotEmpty) ...[
                                        const SizedBox(height: 3),
                                        Text(
                                          s.description,
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
                                      HamdardRepository.formatPkr(s.amount),
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: AppColors.danger,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      DateFormat('dd MMM yyyy').format(s.date),
                                      style: const TextStyle(fontSize: 10.5, color: Colors.grey),
                                    ),
                                    Text(
                                      s.paymentMethod.label(isUrdu),
                                      style: const TextStyle(fontSize: 10, color: Colors.grey),
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
                                          builder: (_) => HamdardAddEditSpendingScreen(existingSpending: s),
                                        ),
                                      );
                                    },
                                  ),
                                  TextButton.icon(
                                    style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                                    icon: const Icon(Icons.delete_outline, size: 16),
                                    label: Text(loc.translate('delete'), style: const TextStyle(fontSize: 12)),
                                    onPressed: () => _confirmDeleteSpending(s),
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
