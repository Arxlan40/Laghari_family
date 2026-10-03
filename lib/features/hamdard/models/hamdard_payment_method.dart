import 'package:flutter/material.dart';

enum HamdardPaymentMethod {
  cash('cash'),
  easypaisa('easypaisa'),
  jazzCash('jazzcash'),
  bankTransfer('bank_transfer');

  final String value;
  const HamdardPaymentMethod(this.value);

  static HamdardPaymentMethod fromString(String? val) {
    if (val == null) return HamdardPaymentMethod.cash;
    switch (val.toLowerCase().replaceAll(' ', '_').trim()) {
      case 'easypaisa':
        return HamdardPaymentMethod.easypaisa;
      case 'jazzcash':
      case 'jazz_cash':
        return HamdardPaymentMethod.jazzCash;
      case 'bank_transfer':
      case 'banktransfer':
      case 'bank':
        return HamdardPaymentMethod.bankTransfer;
      case 'cash':
      default:
        return HamdardPaymentMethod.cash;
    }
  }

  String get labelEn {
    switch (this) {
      case HamdardPaymentMethod.cash:
        return 'Cash';
      case HamdardPaymentMethod.easypaisa:
        return 'Easypaisa';
      case HamdardPaymentMethod.jazzCash:
        return 'JazzCash';
      case HamdardPaymentMethod.bankTransfer:
        return 'Bank Transfer';
    }
  }

  String get labelUr {
    switch (this) {
      case HamdardPaymentMethod.cash:
        return 'نقد';
      case HamdardPaymentMethod.easypaisa:
        return 'ایزی پیسہ';
      case HamdardPaymentMethod.jazzCash:
        return 'جاز کیش';
      case HamdardPaymentMethod.bankTransfer:
        return 'بینک ٹرانسفر';
    }
  }

  String label(bool isUrdu) => isUrdu ? labelUr : labelEn;

  IconData get icon {
    switch (this) {
      case HamdardPaymentMethod.cash:
        return Icons.payments_outlined;
      case HamdardPaymentMethod.easypaisa:
        return Icons.phone_android;
      case HamdardPaymentMethod.jazzCash:
        return Icons.account_balance_wallet_outlined;
      case HamdardPaymentMethod.bankTransfer:
        return Icons.account_balance_outlined;
    }
  }

  Color get color {
    switch (this) {
      case HamdardPaymentMethod.cash:
        return const Color(0xFF10B981); // Emerald
      case HamdardPaymentMethod.easypaisa:
        return const Color(0xFF00A859); // Easypaisa Green
      case HamdardPaymentMethod.jazzCash:
        return const Color(0xFFE61C24); // JazzCash Red
      case HamdardPaymentMethod.bankTransfer:
        return const Color(0xFF3B82F6); // Sapphire Blue
    }
  }
}
