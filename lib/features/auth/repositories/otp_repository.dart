import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/otp_model.dart';

class OtpException implements Exception {
  final String message;
  const OtpException(this.message);

  @override
  String toString() => message;
}

class OtpRepository {
  final FirebaseFirestore? _firestore;
  final Map<String, OtpModel> _inMemoryStore = {};

  OtpRepository([this._firestore]);

  CollectionReference<Map<String, dynamic>>? get _collection =>
      _firestore?.collection('email_verifications');

  /// Generates and sends a 6-digit OTP to the specified email.
  Future<OtpModel> sendOtp({
    required String email,
    required Map<String, dynamic> signupData,
    bool force = false,
  }) async {
    final key = email.toLowerCase().trim();
    final existing = _inMemoryStore[key];

    // 60-second cooldown check to prevent spamming
    if (!force && existing != null && !existing.isExpired) {
      final elapsed = DateTime.now().difference(existing.createdAt).inSeconds;
      if (elapsed < 60) {
        throw OtpException('Please wait ${60 - elapsed}s before requesting a new code.');
      }
    }

    // Cryptographically secure 6-digit number
    final rng = Random.secure();
    final code = (100000 + rng.nextInt(900000)).toString();

    final now = DateTime.now();
    final otpModel = OtpModel(
      email: key,
      otp: code,
      createdAt: now,
      expiresAt: now.add(const Duration(minutes: 10)),
      attempts: 0,
      maxAttempts: 5,
      verified: false,
      signupData: signupData,
    );

    _inMemoryStore[key] = otpModel;

    if (_collection != null) {
      try {
        await _collection!.doc(key).set(otpModel.toJson());
      } catch (e) {
        debugPrint('Firestore save OTP note: $e');
      }

      // Also write to 'mail' collection (Firebase Trigger Email extension standard)
      try {
        await _firestore?.collection('mail').add({
          'to': [key],
          'message': {
            'subject': 'Your Laghari Family Verification Code: $code',
            'text': 'Your Laghari Family verification code is: $code. This code will expire in 10 minutes.',
            'html': '''
              <div style="font-family: Arial, sans-serif; max-width: 520px; margin: 0 auto; padding: 24px; border: 1px solid #e2e8f0; border-radius: 12px; background-color: #ffffff;">
                <h2 style="color: #1A365D; text-align: center; margin-bottom: 8px;">Laghari Family</h2>
                <p style="text-align: center; color: #718096; font-size: 14px; margin-top: 0;">Genealogy & Ancestral Heritage</p>
                <hr style="border: none; border-top: 1px solid #edf2f7; margin: 20px 0;" />
                <p style="color: #2d3748; font-size: 15px;">Hello,</p>
                <p style="color: #4a5568; font-size: 14px; line-height: 1.5;">Thank you for registering. Use the 6-digit verification code below to verify your email address and activate your account:</p>
                <div style="background-color: #f7fafc; border: 1px dashed #cbd5e0; padding: 18px; text-align: center; border-radius: 8px; margin: 24px 0;">
                  <span style="font-size: 32px; font-weight: bold; letter-spacing: 8px; color: #b7791f; font-family: monospace;">$code</span>
                </div>
                <p style="color: #718096; font-size: 12px; text-align: center;">This code will expire in 10 minutes.</p>
              </div>
            ''',
          },
        });
      } catch (e) {
        debugPrint('Firestore mail extension note: $e');
      }
    }

    debugPrint('=======================================');
    debugPrint('EMAIL OTP FOR [$key]: $code');
    debugPrint('=======================================');

    return otpModel;
  }

  /// Verifies the 6-digit OTP entered by the user
  Future<bool> verifyOtp({
    required String email,
    required String enteredCode,
  }) async {
    final key = email.toLowerCase().trim();
    OtpModel? record = _inMemoryStore[key];

    if (_collection != null) {
      try {
        final doc = await _collection!.doc(key).get();
        if (doc.exists && doc.data() != null) {
          record = OtpModel.fromJson(doc.data()!);
        }
      } catch (e) {
        debugPrint('Firestore fetch OTP note: $e');
      }
    }

    if (record == null) {
      throw const OtpException('No verification request found. Please request a new code.');
    }

    if (record.isExpired) {
      throw const OtpException('Verification code has expired. Please request a new code.');
    }

    if (record.hasExceededAttempts) {
      throw const OtpException('Maximum verification attempts exceeded. Please request a new code.');
    }

    if (record.otp != enteredCode.trim()) {
      final updatedAttempts = record.attempts + 1;
      final updated = record.copyWith(attempts: updatedAttempts);
      _inMemoryStore[key] = updated;

      if (_collection != null) {
        try {
          await _collection!.doc(key).update({'attempts': updatedAttempts});
        } catch (_) {}
      }

      final remaining = updated.maxAttempts - updatedAttempts;
      if (remaining <= 0) {
        throw const OtpException('Maximum attempts exceeded. Please request a new code.');
      }
      throw OtpException('Incorrect verification code. $remaining attempt(s) remaining.');
    }

    // Success: mark verified
    final verifiedRecord = record.copyWith(verified: true);
    _inMemoryStore[key] = verifiedRecord;

    if (_collection != null) {
      try {
        await _collection!.doc(key).update({'verified': true});
      } catch (_) {}
    }

    return true;
  }

  OtpModel? getActiveOtp(String email) {
    return _inMemoryStore[email.toLowerCase().trim()];
  }

  void clearOtp(String email) {
    _inMemoryStore.remove(email.toLowerCase().trim());
  }
}

final otpRepositoryProvider = Provider<OtpRepository>((ref) {
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return OtpRepository(firestore);
});
