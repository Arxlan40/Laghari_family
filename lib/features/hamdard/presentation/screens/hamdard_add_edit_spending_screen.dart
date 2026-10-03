import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_payment_method.dart';
import '../../models/hamdard_person.dart';
import '../../models/hamdard_spending.dart';
import '../../models/hamdard_spending_category.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';

class HamdardAddEditSpendingScreen extends ConsumerStatefulWidget {
  final HamdardSpending? existingSpending;

  const HamdardAddEditSpendingScreen({super.key, this.existingSpending});

  @override
  ConsumerState<HamdardAddEditSpendingScreen> createState() => _HamdardAddEditSpendingScreenState();
}

class _HamdardAddEditSpendingScreenState extends ConsumerState<HamdardAddEditSpendingScreen> {
  final _formKey = GlobalKey<FormState>();

  final _recipientNameCtrl = TextEditingController();
  final _recipientFatherCtrl = TextEditingController();
  final _recipientPhoneCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  HamdardPaymentMethod _paymentMethod = HamdardPaymentMethod.cash;
  HamdardSpendingCategory _category = HamdardSpendingCategory.medical;
  DateTime _selectedDate = DateTime.now();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingSpending != null) {
      final s = widget.existingSpending!;
      _recipientNameCtrl.text = s.recipientName;
      _recipientFatherCtrl.text = s.recipientFatherName;
      _recipientPhoneCtrl.text = s.recipientPhoneNumber;
      _amountCtrl.text = s.amount.toString();
      _descriptionCtrl.text = s.description;
      _noteCtrl.text = s.note;
      _paymentMethod = s.paymentMethod;
      _category = s.category;
      _selectedDate = s.date;
    }
  }

  @override
  void dispose() {
    _recipientNameCtrl.dispose();
    _recipientFatherCtrl.dispose();
    _recipientPhoneCtrl.dispose();
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _submitSpending() async {
    if (!_formKey.currentState!.validate()) return;

    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.read(currentUserProvider);

    if (currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.isUrdu ? 'براہ کرم لاگ ان کریں' : 'Please log in to continue.')),
      );
      return;
    }

    final parsedAmount = int.tryParse(_amountCtrl.text.replaceAll(',', '').trim()) ?? 0;
    if (parsedAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.isUrdu ? 'براہ کرم درست رقم درج کریں' : 'Please enter a valid amount greater than 0.')),
      );
      return;
    }

    final recipientName = _recipientNameCtrl.text.trim();
    final recipientFather = _recipientFatherCtrl.text.trim();
    final recipientPhone = HamdardPerson.normalizePhone(_recipientPhoneCtrl.text.trim());

    // Review dialog before finalizing
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'اخراجات کی تصدیق کریں' : 'Review & Confirm Spending'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${loc.isUrdu ? "مستحق / وصول کنندہ" : "Recipient"}: $recipientName',
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${loc.isUrdu ? "والد" : "Father"}: $recipientFather'),
            Text('${loc.isUrdu ? "فون" : "Phone"}: $recipientPhone'),
            const SizedBox(height: 8),
            Text('${loc.isUrdu ? "مد / زمرہ" : "Category"}: ${_category.label(loc.isUrdu)}'),
            Text('${loc.isUrdu ? "رقم" : "Amount"}: ${HamdardRepository.formatPkr(parsedAmount)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.danger)),
            Text('${loc.isUrdu ? "طریقہ" : "Payment Method"}: ${_paymentMethod.label(loc.isUrdu)}'),
            Text('${loc.isUrdu ? "تاریخ" : "Date"}: ${DateFormat('dd MMM yyyy').format(_selectedDate)}'),
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
            child: Text(loc.translate('save')),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(hamdardRepositoryProvider);
      final isEditing = widget.existingSpending != null;

      if (isEditing) {
        final newSpending = widget.existingSpending!.copyWith(
          recipientName: recipientName,
          recipientFatherName: recipientFather,
          recipientPhoneNumber: recipientPhone,
          amount: parsedAmount,
          date: _selectedDate,
          paymentMethod: _paymentMethod,
          category: _category,
          description: _descriptionCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
        );
        await repo.editSpending(
          newSpending,
          widget.existingSpending!,
          performedBy: currentUser.uid,
          performedByName: currentUser.name,
        );
      } else {
        final newSpending = HamdardSpending(
          id: '',
          recipientName: recipientName,
          recipientFatherName: recipientFather,
          recipientPhoneNumber: recipientPhone,
          amount: parsedAmount,
          date: _selectedDate,
          paymentMethod: _paymentMethod,
          category: _category,
          description: _descriptionCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
        );
        await repo.addSpending(
          newSpending,
          performedBy: currentUser.uid,
          performedByName: currentUser.name,
        );
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Error saving spending: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final isEditing = widget.existingSpending != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? (isUrdu ? 'اخراجات میں ترمیم' : 'Edit Spending')
            : (isUrdu ? 'نیا خرچ درج کریں' : 'Record Spending')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Recipient Information Card
              Card(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'وصول کنندہ / مستحق کی معلومات' : 'Recipient Information',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _recipientNameCtrl,
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'نام' : 'Recipient Name',
                          prefixIcon: const Icon(Icons.person),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _recipientFatherCtrl,
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'والد کا نام' : "Father's Name",
                          prefixIcon: const Icon(Icons.person_outline),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty) ? "Father's name is required" : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _recipientPhoneCtrl,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'موبائل نمبر (03XXXXXXXXX)' : 'Phone Number (03XXXXXXXXX)',
                          prefixIcon: const Icon(Icons.phone),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Phone number is required';
                          if (!HamdardPerson.isValidPakistaniPhone(v)) {
                            return 'Enter valid 11-digit mobile number (03001234567)';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Spending Category & Amount Card
              Card(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'اخراجات کی تفصیلات' : 'Spending Details',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.danger),
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'رقم (روپے)' : 'Amount (PKR)',
                          prefixText: 'Rs. ',
                          prefixStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          prefixIcon: const Icon(Icons.currency_rupee),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return 'Amount is required';
                          final num = int.tryParse(v.trim());
                          if (num == null || num <= 0) return 'Enter a valid amount';
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),

                      Text(
                        isUrdu ? 'مد / زمرہ' : 'Spending Category',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: HamdardSpendingCategory.values.map((cat) {
                          final isSelected = _category == cat;
                          return ChoiceChip(
                            avatar: Icon(cat.icon, size: 16, color: isSelected ? Colors.white : cat.color),
                            label: Text(cat.label(isUrdu)),
                            selected: isSelected,
                            selectedColor: cat.color,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => setState(() => _category = cat),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      Text(
                        isUrdu ? 'طریقہ ادائیگی' : 'Payment Method',
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: HamdardPaymentMethod.values.map((method) {
                          final isSelected = _paymentMethod == method;
                          return ChoiceChip(
                            avatar: Icon(method.icon, size: 16, color: isSelected ? Colors.white : method.color),
                            label: Text(method.label(isUrdu)),
                            selected: isSelected,
                            selectedColor: method.color,
                            labelStyle: TextStyle(
                              color: isSelected ? Colors.white : (isDark ? Colors.white : Colors.black87),
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            ),
                            onSelected: (_) => setState(() => _paymentMethod = method),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 16),

                      // Date Picker
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                        leading: const Icon(Icons.calendar_month, color: AppColors.gold),
                        title: Text(isUrdu ? 'تاریخ' : 'Date'),
                        subtitle: Text(DateFormat('dd MMMM yyyy').format(_selectedDate)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 3. Description & Note Card
              Card(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'تفصیل و نوٹ' : 'Description & Note',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionCtrl,
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'تفصیل (مثلاً ہسپتال بل)' : 'Description (e.g. Hospital bill assistance)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _noteCtrl,
                        maxLines: 2,
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'اندرونی نوٹ (اختیاری)' : 'Internal Note (optional)',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.danger,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting ? null : _submitSpending,
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(isEditing ? Icons.save : Icons.check_circle),
                          const SizedBox(width: 8),
                          Text(
                            isEditing
                                ? (isUrdu ? 'ترمیم محفوظ کریں' : 'Save Changes')
                                : (isUrdu ? 'خرچ درج کریں' : 'Record Spending'),
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
