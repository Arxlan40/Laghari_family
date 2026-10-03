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
import '../widgets/hamdard_person_picker_modal.dart';
import '../widgets/hamdard_user_avatar.dart';
import 'hamdard_receipt_screen.dart';

class HamdardAddEditDonationScreen extends ConsumerStatefulWidget {
  final HamdardDonation? existingDonation;
  final HamdardDonation? donationToEdit;
  final HamdardPerson? preselectedPerson;

  const HamdardAddEditDonationScreen({
    super.key,
    this.existingDonation,
    this.donationToEdit,
    this.preselectedPerson,
  });

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
    final d = widget.existingDonation ?? widget.donationToEdit;
    if (d != null) {
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
    } else if (widget.preselectedPerson != null) {
      _selectedPerson = widget.preselectedPerson;
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

  Future<void> _pickDonorFromDirectory() async {
    final loc = AppLocalizations.of(context);
    final person = await HamdardPersonPickerModal.show(
      context,
      title: loc.isUrdu ? 'عطیہ دہندہ منتخب کریں' : 'Select Donor',
    );
    if (person != null) {
      setState(() {
        _selectedPerson = person;
        _isCreatingNewPerson = false;
      });
    }
  }

  void _showValidationSnackbar(String message) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: AppColors.danger,
        content: Text(message, style: const TextStyle(fontWeight: FontWeight.w600)),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _submitDonation() async {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.read(currentUserProvider);

    if (currentUser == null) {
      _showValidationSnackbar(loc.isUrdu ? 'براہ کرم لاگ ان کریں' : 'Please log in to continue.');
      return;
    }

    // 1. Validation: Person selection or new person entry
    if (!_isCreatingNewPerson && _selectedPerson == null) {
      _showValidationSnackbar(
        loc.isUrdu ? 'براہ کرم عطیہ دہندہ منتخب کریں' : 'Please select or add a donor.',
      );
      return;
    }

    if (_isCreatingNewPerson) {
      final name = _newPersonNameCtrl.text.trim();
      final father = _newPersonFatherCtrl.text.trim();
      final phone = _newPersonPhoneCtrl.text.trim();

      if (name.isEmpty) {
        _showValidationSnackbar(
          loc.isUrdu ? 'براہ کرم عطیہ دہندہ کا نام درج کریں' : 'Please enter the donor name.',
        );
        return;
      }

      if (father.isEmpty) {
        _showValidationSnackbar(
          loc.isUrdu ? 'براہ کرم والد کا نام درج کریں' : "Please enter the father's name.",
        );
        return;
      }

      if (phone.isEmpty || !HamdardPerson.isValidPakistaniPhone(phone)) {
        _showValidationSnackbar(
          loc.isUrdu
              ? 'براہ کرم درست 11 ہندسوں کا موبائل نمبر درج کریں (03XXXXXXXXX)'
              : 'Please enter a valid 11-digit mobile number (e.g. 03001234567).',
        );
        return;
      }
    }

    // 2. Validation: Amount
    final rawAmountText = _amountCtrl.text.replaceAll(',', '').trim();
    if (rawAmountText.isEmpty) {
      _showValidationSnackbar(
        loc.isUrdu ? 'براہ کرم رقم درج کریں' : 'Please enter the donation amount.',
      );
      return;
    }

    final parsedAmount = int.tryParse(rawAmountText) ?? 0;
    if (parsedAmount <= 0) {
      _showValidationSnackbar(
        loc.isUrdu ? 'براہ کرم درست رقم درج کریں' : 'Please enter a valid amount greater than 0.',
      );
      return;
    }

    // 3. Form fields validation
    if (!_formKey.currentState!.validate()) {
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
        final newPerson = HamdardPerson(
          id: '',
          name: donorName,
          fatherName: donorFather,
          phoneNumber: donorPhone,
          sourceType: 'manual',
        );
        personToUse = await repo.savePerson(
          newPerson,
          performedBy: currentUser.uid,
          performedByName: currentUser.name,
        );
      } else {
        personToUse = _selectedPerson!;
      }

      final currentExisting = widget.existingDonation ?? widget.donationToEdit;
      final isEditing = currentExisting != null;
      HamdardDonation savedDonation;

      if (isEditing) {
        final newDonation = currentExisting.copyWith(
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
          currentExisting,
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
        _showValidationSnackbar('Error saving donation: $e');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final isEditing = (widget.existingDonation ?? widget.donationToEdit) != null;

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
                            isUrdu ? 'عطیہ دہندہ کی معلومات' : 'Donor Information',
                            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                          TextButton.icon(
                            icon: Icon(_isCreatingNewPerson ? Icons.list : Icons.person_add, size: 18),
                            label: Text(_isCreatingNewPerson
                                ? (isUrdu ? 'ڈائریکٹری سے منتخب کریں' : 'Select Existing')
                                : (isUrdu ? 'نیا فرد دستی درج کریں' : 'Add New Person')),
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
                                HamdardUserAvatar(
                                  imageUrl: _selectedPerson!.profileImageUrl,
                                  name: _selectedPerson!.name,
                                  radius: 24,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Flexible(
                                            child: Text(
                                              _selectedPerson!.name,
                                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: _selectedPerson!.isFromFamilyTree
                                                  ? AppColors.emerald.withValues(alpha: 0.15)
                                                  : Colors.grey.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              _selectedPerson!.isFromFamilyTree
                                                  ? (isUrdu ? 'شجرہ' : 'Tree')
                                                  : (isUrdu ? 'دستی' : 'Manual'),
                                              style: TextStyle(
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                                color: _selectedPerson!.isFromFamilyTree ? AppColors.emerald : Colors.grey,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      Text(
                                        '${isUrdu ? "والد" : "Father"}: ${_selectedPerson!.fatherName.isNotEmpty ? _selectedPerson!.fatherName : "N/A"} • ${_selectedPerson!.phoneNumber}',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                OutlinedButton.icon(
                                  style: OutlinedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                  ),
                                  icon: const Icon(Icons.swap_horiz, size: 16),
                                  label: Text(isUrdu ? 'تبدیل' : 'Change', style: const TextStyle(fontSize: 12)),
                                  onPressed: _pickDonorFromDirectory,
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
                            label: Text(isUrdu ? 'ڈائریکٹری سے عطیہ دہندہ منتخب کریں' : 'Select Donor From Directory'),
                            onPressed: _pickDonorFromDirectory,
                          ),
                      ] else ...[
                        // Add new donor fields
                        TextFormField(
                          controller: _newPersonNameCtrl,
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'مکمل نام *' : 'Donor Name *',
                            prefixIcon: const Icon(Icons.person),
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: _newPersonFatherCtrl,
                          decoration: InputDecoration(
                            labelText: isUrdu ? 'والد کا نام *' : "Father's Name *",
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
                            labelText: isUrdu ? 'موبائل نمبر (03XXXXXXXXX) *' : 'Phone Number (03XXXXXXXXX) *',
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
                          labelText: isUrdu ? 'رقم (روپے) *' : 'Amount (PKR) *',
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
