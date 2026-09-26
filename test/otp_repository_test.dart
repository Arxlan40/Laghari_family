import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/features/auth/repositories/otp_repository.dart';

void main() {
  group('OtpRepository In-Memory Logic Tests', () {
    late OtpRepository otpRepo;

    setUp(() {
      otpRepo = OtpRepository(); // In-memory mode
    });

    test('Generates a 6-digit numeric OTP', () async {
      final model = await otpRepo.sendOtp(
        email: 'test@example.com',
        signupData: {'fullName': 'Ali Laghari'},
      );

      expect(model.otp.length, 6);
      expect(int.tryParse(model.otp), isNotNull);
      expect(model.verified, isFalse);
      expect(model.attempts, 0);
    });

    test('Successfully verifies correct OTP', () async {
      final model = await otpRepo.sendOtp(
        email: 'verify@example.com',
        signupData: {'fullName': 'Bilal Laghari'},
      );

      final isSuccess = await otpRepo.verifyOtp(
        email: 'verify@example.com',
        enteredCode: model.otp,
      );

      expect(isSuccess, isTrue);
      final active = otpRepo.getActiveOtp('verify@example.com');
      expect(active?.verified, isTrue);
    });

    test('Rejects incorrect OTP and increments attempts', () async {
      final model = await otpRepo.sendOtp(
        email: 'wrong@example.com',
        signupData: {'fullName': 'Tariq Laghari'},
      );

      final wrongCode = model.otp == '111111' ? '222222' : '111111';

      expect(
        () => otpRepo.verifyOtp(email: 'wrong@example.com', enteredCode: wrongCode),
        throwsA(isA<OtpException>()),
      );

      final active = otpRepo.getActiveOtp('wrong@example.com');
      expect(active?.attempts, 1);
    });

    test('Enforces maximum 5 attempts', () async {
      final model = await otpRepo.sendOtp(
        email: 'limit@example.com',
        signupData: {'fullName': 'Zahid Laghari'},
      );

      final wrongCode = model.otp == '999999' ? '888888' : '999999';

      for (int i = 0; i < 5; i++) {
        try {
          await otpRepo.verifyOtp(email: 'limit@example.com', enteredCode: wrongCode);
        } catch (_) {}
      }

      // 6th attempt should throw max attempts exceeded
      expect(
        () => otpRepo.verifyOtp(email: 'limit@example.com', enteredCode: model.otp),
        throwsA(isA<OtpException>()),
      );
    });

    test('Prevents sending new OTP within 60 second cooldown unless forced', () async {
      await otpRepo.sendOtp(
        email: 'cooldown@example.com',
        signupData: {'fullName': 'Kamran Laghari'},
      );

      expect(
        () => otpRepo.sendOtp(
          email: 'cooldown@example.com',
          signupData: {'fullName': 'Kamran Laghari'},
          force: false,
        ),
        throwsA(isA<OtpException>()),
      );

      // Force should bypass cooldown
      final newOtp = await otpRepo.sendOtp(
        email: 'cooldown@example.com',
        signupData: {'fullName': 'Kamran Laghari'},
        force: true,
      );
      expect(newOtp.otp.length, 6);
    });
  });
}
