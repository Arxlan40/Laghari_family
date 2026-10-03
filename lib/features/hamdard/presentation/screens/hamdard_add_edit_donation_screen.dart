import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_donation.dart';
import '../../models/hamdard_payment_method.dart';
import '../../models/hamdard_person.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import 'hamdard_receipt_screen.dart';

class HamdardAddEditDonationScreen extends ConsumerStatefulWidget {
  final HamdardDonation? existingDonation;

  const HamdardAddEditDonationScreen({super.key, this.existingDonation});

  @override
  ConsumerState<HamdardAddEditDonationScreen> createState() => _HamdardAddEditDonationScreenState();
}

class _HamdardAddEditDonationScreenState extends ConsumerState<HamdardAddEditDonationScreen> {
  final _formKey = GlobalKey<FormState>();

  HamdardPerson? _selectedPerson;
  bool _isCreatingNewPerson = false;

  final _newPersonNameCtrl = TextEditingController();
  final _newPersonFatherCtrl = TextEditingController();
  final _newPersonPhoneCtrl = TextEditingController();

  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();

  HamdardPaymentMethod _paymentMethod = HamdardPaymentMethod.cash;
  DateTime _selectedDate = DateTime.now();

  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingDonation != null) {
      final d = widget.existingDonation!;
      _amountCtrl.text = d.amount.toString();
      _descriptionCtrl.text = d.description;
      _noteCtrl.text = d.note;
      _paymentMethod = d.paymentMethod;
      _selectedDate = d.date;
      _selectedPerson = HamdardPerson(
        id: d.personId,
        name: d.personNameSnapshot,
        fatherName: d.fatherNameSnapshot,
        phoneNumber: d.phoneNumberSnapshot,
      );
    }
  }

  @override
  void dispose() {
    _newPersonNameCtrl.dispose();
    _newPersonFatherCtrl.dispose();
    _newPersonPhoneCtrl.dispose();
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

  void _showSelectPersonDialog(List<HamdardPerson> people) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    String search = '';

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = people.where((p) {
            final query = search.toLowerCase().trim();
            if (query.isEmpty) return true;
            return p.name.toLowerCase().contains(query) ||
                p.fatherName.toLowerCase().contains(query) ||
                p.phoneNumber.contains(query);
          }).toList();

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(loc.isUrdu ? 'عطیہ دہندہ منتخب کریں' : 'Select Donor'),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: loc.isUrdu ? 'نام، والد، یا فون سے تلاش کریں' : 'Search name, father, or phone...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) => setDialogState(() => search = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              loc.isUrdu ? 'کوئی شخص نہیں ملا' : 'No person found',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final p = filtered[i];
                              return ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.emerald.withValues(alpha: 0.15),
                                  child: Text(
                                    p.name.isNotEmpty ? p.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(
                                  'Father: ${p.fatherName.isNotEmpty ? p.fatherName : "N/A"} • ${p.phoneNumber}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                onTap: () {
                                  setState(() {
                                    _selectedPerson = p;
                                    _isCreatingNewPerson = false;
                                  });
                                  Navigator.pop(ctx);
                                },
                              );
                            },
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
            ],
          );
        },
      ),
    );
  }

  Future<void> _submitDonation() async {
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

    if (!_isCreatingNewPerson && _selectedPerson == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(loc.isUrdu ? 'براہ کرم عطیہ دہندہ منتخب کریں' : 'Please select or add a donor.')),
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

    // Review Confirmation Dialog
    final donorName = _isCreatingNewPerson ? _newPersonNameCtrl.text.trim() : _selectedPerson!.name;
    final donorFather = _isCreatingNewPerson ? _newPersonFatherCtrl.text.trim() : _selectedPerson!.fatherName;
    final donorPhone = _isCreatingNewPerson
        ? HamdardPerson.normalizePhone(_newPersonPhoneCtrl.text.trim())
        : _selectedPerson!.phoneNumber;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'عطیہ کی تصدیق کریں' : 'Review & Confirm Donation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${loc.isUrdu ? "عطیہ دہندہ" : "Donor"}: $donorName', style: const TextStyle(fontWeight: FontWeight.bold)),
            Text('${loc.isUrdu ? "والد" : "Father"}: $donorFather'),
            Text('${loc.isUrdu ? "فون" : "Phone"}: $donorPhone'),
            const SizedBox(height: 8),
            Text('${loc.isUrdu ? "رقم" : "Amount"}: ${HamdardRepository.formatPkr(parsedAmount)}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: AppColors.emerald)),
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
              backgroundColor: AppColors.emerald,
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

      HamdardPerson personToUse;
      if (_isCreatingNewPerson) {
        // Save new person first
        final newPerson = HamdardPerson(
          id: '',
          name: donorName,
          fatherName: donorFather,
          phoneNumber: donorPhone,
        );
        personToUse = await repo.savePerson(
          newPerson,
          performedBy: currentUser.uid,
          performedByName: currentUser.name,
        );
      } else {
        personToUse = _selectedPerson!;
      }

      final isEditing = widget.existingDonation != null;
      HamdardDonation savedDonation;

      if (isEditing) {
        final newDonation = widget.existingDonation!.copyWith(
          personId: personToUse.id,
          personNameSnapshot: personToUse.name,
          fatherNameSnapshot: personToUse.fatherName,
          phoneNumberSnapshot: personToUse.phoneNumber,
          amount: parsedAmount,
          paymentMethod: _paymentMethod,
          date: _selectedDate,
          description: _descriptionCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
        );
        savedDonation = await repo.editDonation(
          newDonation,
          widget.existingDonation!,
          performedBy: currentUser.uid,
          performedByName: currentUser.name,
        );
      } else {
        final newDonation = HamdardDonation(
          id: '',
          personId: personToUse.id,
          personNameSnapshot: personToUse.name,
          fatherNameSnapshot: personToUse.fatherName,
          phoneNumberSnapshot: personToUse.phoneNumber,
          amount: parsedAmount,
          paymentMethod: _paymentMethod,
          date: _selectedDate,
          description: _descriptionCtrl.text.trim(),
          note: _noteCtrl.text.trim(),
        );
        savedDonation = await repo.addDonation(
          newDonation,
          performedBy: currentUser.uid,
          performedByName: currentUser.name,
        );
      }

      if (!mounted) return;
      setState(() => _isSubmitting = false);

      // Replace screen with receipt preview
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => HamdardReceiptScreen(donation: savedDonation)),
      );
    } catch (e) {
      if (mounted) {
        setState(() => _isSubmitting = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text('Error saving donation: $e'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final isEditing = widget.existingDonation != null;
    final people = ref.watch(hamdardPeopleStreamProvider).valueOrNull ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text(isEditing
            ? (isUrdu ? 'عطیہ میں ترمیم' : 'Edit Donation')
            : (isUrdu ? 'عطیہ درج کریں' : 'Add Donation')),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Donor Selection / Entry Card
              Card(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            isUrdu ? 'عطیہ دہندہ' : 'Donor Information',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            icon: Icon(_isCreatingNewPerson ? Icons.list : Icons.person_add, size: 18),
                            label: Text(_isCreatingNewPerson
                                ? (isUrdu ? 'موجودہ شخص منتخب کریں' : 'Select Existing')
                                : (isUrdu ? 'نیا شخص شامل کریں' : 'Add New Person')),
                            onPressed: () {
                              setState(() {
                                _isCreatingNewPerson = !_isCreatingNewPerson;
                                if (_isCreatingNewPerson) _selectedPerson = null;
                              });
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      if (!_isCreatingNewPerson) ...[
                        // Select existing donor
                        if (_selectedPerson != null)
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.emerald.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  backgroundColor: AppColors.emerald,
                                  child: Text(
                                    _selectedPerson!.name.isNotEmpty ? _selectedPerson!.name[0].toUpperCase() : '?',
                                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(_selectedPerson!.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                      Text(
                                        'Father: ${_selectedPerson!.fatherName.isNotEmpty ? _selectedPerson!.fatherName : "N/A"} • ${_selectedPerson!.phoneNumber}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(Icons.edit, size: 18),
                                  onPressed: () => _showSelectPersonDialog(people),
                                ),
                              ],
                            ),
                          )
                        else
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                              foregroundColor: isDark ? Colors.white : Colors.black87,
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            icon: const Icon(Icons.person_search, color: AppColors.emerald),
                            label: Text(isUrdu ? 'فہرست سے عطیہ دہندہ منتخب کریں' : 'Select Donor From Registry'),
                            onPressed: () => _showSelectPersonDialog(people),
                          ),
                      ] else ...[
                        // Add new donor fields
                        TextFormField(
                          controller: _newPersonNameCtrl,
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'نام' : 'Donor Name',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPersonFatherCtrl,
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'والد کا نام' : "Father's Name",
                            prefixIcon: const Icon(Icons.person_outline),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? "Father's name is required" : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPersonPhoneCtrl,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // 2. Financial Amount & Payment Method Card
              Card(
                color: isDark ? AppColors.darkSurface : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isUrdu ? 'مالی تفصیلات' : 'Financial Details',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _amountCtrl,
                        keyboardType: TextInputType.number,
                        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: AppColors.emerald),
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

                      // Date Picker Row
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
                        isUrdu ? 'اضافی تفصیلات' : 'Notes & Description',
                        style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _descriptionCtrl,
                        decoration: InputDecoration(
                          labelText: isUrdu ? 'تفصیل (مثلاً ماہانہ فنڈ)' : 'Description (e.g. Monthly contribution)',
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
                  backgroundColor: AppColors.emerald,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _isSubmitting ? null : _submitDonation,
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
                                : (isUrdu ? 'عطیہ درج کریں' : 'Record Donation'),
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
