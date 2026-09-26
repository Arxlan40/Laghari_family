import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/features/auth/presentation/widgets/pakistan_phone_field.dart';

void main() {
  group('PakistanPhoneField Validator and Formatter Tests', () {
    test('Validates standard Pakistani mobile numbers', () {
      expect(PakistanPhoneField.validatePakistaniNumber('3001234567'), isNull);
      expect(PakistanPhoneField.validatePakistaniNumber('3129876543'), isNull);
      expect(PakistanPhoneField.validatePakistaniNumber('3455551234'), isNull);
      expect(PakistanPhoneField.validatePakistaniNumber('3330001122'), isNull);
    });

    test('Validates numbers formatted with spaces or dashes', () {
      expect(PakistanPhoneField.validatePakistaniNumber('300 1234567'), isNull);
      expect(PakistanPhoneField.validatePakistaniNumber('300-1234567'), isNull);
    });

    test('Accepts input with 03 prefix and normalizes correctly', () {
      expect(PakistanPhoneField.validatePakistaniNumber('03001234567'), isNull);
      expect(PakistanPhoneField.validatePakistaniNumber('03451234567'), isNull);
    });

    test('Normalizes phone numbers to +92 format', () {
      expect(PakistanPhoneField.normalizeToFullNumber('3001234567'), '+92 3001234567');
      expect(PakistanPhoneField.normalizeToFullNumber('03001234567'), '+92 3001234567');
      expect(PakistanPhoneField.normalizeToFullNumber('923001234567'), '+92 3001234567');
      expect(PakistanPhoneField.normalizeToFullNumber('+92 300 1234567'), '+92 3001234567');
    });

    test('Rejects empty or null phone number', () {
      expect(PakistanPhoneField.validatePakistaniNumber(null), isNotNull);
      expect(PakistanPhoneField.validatePakistaniNumber(''), isNotNull);
      expect(PakistanPhoneField.validatePakistaniNumber('   '), isNotNull);
    });

    test('Rejects numbers with incorrect length', () {
      expect(PakistanPhoneField.validatePakistaniNumber('300123456'), isNotNull); // 9 digits
      expect(PakistanPhoneField.validatePakistaniNumber('30012345678'), isNotNull); // 11 digits
    });

    test('Rejects non-Pakistani mobile network codes', () {
      expect(PakistanPhoneField.validatePakistaniNumber('2001234567'), isNotNull); // Starts with 2
      expect(PakistanPhoneField.validatePakistaniNumber('4001234567'), isNotNull); // Starts with 4
      expect(PakistanPhoneField.validatePakistaniNumber('3601234567'), isNotNull); // Prefix 36 (out of 30-35 range)
      expect(PakistanPhoneField.validatePakistaniNumber('3901234567'), isNotNull); // Prefix 39
    });
  });
}
