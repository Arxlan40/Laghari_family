import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/features/auth/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    test('Parses complete user JSON with bloodGroup, gender, and profession', () {
      final json = {
        'uid': 'user_123',
        'name': 'Arsalan Umar',
        'father_name': 'Umar Farooq',
        'email': 'arsalan@example.com',
        'address': 'Jhang, Punjab',
        'phone': '03001234567',
        'bloodGroup': 'B+',
        'gender': 'Male',
        'profession': 'Software Engineer',
        'role': 'user',
        'status': 'active',
      };

      final user = UserModel.fromJson(json);

      expect(user.uid, 'user_123');
      expect(user.name, 'Arsalan Umar');
      expect(user.bloodGroup, 'B+');
      expect(user.gender, 'Male');
      expect(user.profession, 'Software Engineer');
      expect(user.role, UserRole.user);
      expect(user.status, AccountStatus.active);
    });

    test('Provides fallback defaults when bloodGroup, gender, and profession are missing', () {
      // Historical or minimal user without new fields
      final json = {
        'uid': 'legacy_user',
        'name': 'Legacy Member',
        'email': 'legacy@example.com',
      };

      final user = UserModel.fromJson(json);

      expect(user.bloodGroup, 'Unknown');
      expect(user.gender, 'Prefer not to say');
      expect(user.profession, '');
    });

    test('Serializes to JSON with both bloodGroup and blood_group keys', () {
      const user = UserModel(
        uid: 'user_456',
        name: 'Dr. Jaffer',
        fatherName: 'Father',
        email: 'jaffer@example.com',
        address: 'District Jhang',
        bloodGroup: 'O+',
        gender: 'Male',
        profession: 'Physician',
      );

      final json = user.toJson();

      expect(json['bloodGroup'], 'O+');
      expect(json['blood_group'], 'O+');
      expect(json['gender'], 'Male');
      expect(json['profession'], 'Physician');
    });
  });
}
