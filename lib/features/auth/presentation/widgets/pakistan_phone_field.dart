import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../../core/constants/app_colors.dart';

class PakistanPhoneField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final FocusNode? nextFocusNode;
  final String? Function(String?)? validator;
  final void Function(String)? onChanged;

  const PakistanPhoneField({
    super.key,
    required this.controller,
    this.focusNode,
    this.nextFocusNode,
    this.validator,
    this.onChanged,
  });

  /// Normalizes Pakistani phone input to `+92 3XXXXXXXXX`
  static String normalizeToFullNumber(String raw) {
    var digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }
    return '+92 $digits';
  }

  /// Validates a Pakistani mobile number
  static String? validatePakistaniNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your mobile number.';
    }

    var digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92')) {
      digits = digits.substring(2);
    }
    if (digits.startsWith('0')) {
      digits = digits.substring(1);
    }

    if (digits.length != 10) {
      return 'Mobile number must be 10 digits (e.g. 300 1234567).';
    }

    // Pakistani mobile network codes: 300-349 (Jazz, Telenor, Zong, Ufone, Scom)
    if (!digits.startsWith('3')) {
      return 'Pakistani mobile numbers must start with 3 (e.g. 300...).';
    }

    final prefix = int.tryParse(digits.substring(0, 2)) ?? 0;
    if (prefix < 30 || prefix > 35) {
      return 'Invalid network code. Expected 030X to 035X.';
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: TextInputType.phone,
      textInputAction: nextFocusNode != null ? TextInputAction.next : TextInputAction.done,
      onFieldSubmitted: (_) => nextFocusNode?.requestFocus(),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(11), // Allow up to 11 if typing 03..., auto-trimmed
        _PakistaniPhoneFormatter(controller),
      ],
      validator: validator ?? validatePakistaniNumber,
      onChanged: onChanged,
      decoration: InputDecoration(
        labelText: 'Mobile Number',
        hintText: '300 1234567',
        prefixIcon: Container(
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            border: Border(
              right: BorderSide(
                color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                width: 1,
              ),
            ),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('🇵🇰', style: TextStyle(fontSize: 18)),
              SizedBox(width: 6),
              Text(
                '+92',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PakistaniPhoneFormatter extends TextInputFormatter {
  final TextEditingController controller;
  _PakistaniPhoneFormatter(this.controller);

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    var text = newValue.text;

    // If user starts typing with '03', remove the leading '0'
    if (text.startsWith('0')) {
      text = text.substring(1);
    }

    // Limit to 10 digits
    if (text.length > 10) {
      text = text.substring(0, 10);
    }

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }
}
