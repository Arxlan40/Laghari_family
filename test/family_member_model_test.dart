import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/features/family_tree/models/family_member.dart';

void main() {
  group('FamilyMember Model Tests', () {
    test('Parses complete JSON with phoneNumber, bloodGroup, and profession', () {
      final json = {
        'id': 'member_001',
        'name_en': 'Arsalan Umar Laghari',
        'name_ur': 'ارسلان عمر لغاری',
        'father_id': 'father_001',
        'gender': 'male',
        'alive_status': 'alive',
        'generation': 55,
        'children_ids': ['child_001', 'child_002'],
        'phoneNumber': '03001234567',
        'bloodGroup': 'B+',
        'profession': 'Software Engineer',
      };

      final member = FamilyMember.fromJson(json);

      expect(member.id, 'member_001');
      expect(member.nameEn, 'Arsalan Umar Laghari');
      expect(member.phoneNumber, '03001234567');
      expect(member.displayPhoneNumber, '03001234567');
      expect(member.bloodGroup, 'B+');
      expect(member.displayBloodGroup, 'B+');
      expect(member.profession, 'Software Engineer');
      expect(member.displayProfession, 'Software Engineer');
      expect(member.isMale, isTrue);
      expect(member.isFemale, isFalse);
    });

    test('Parses snake_case JSON variants (phone_number, mobile_number, blood_group, occupation)', () {
      final json = {
        'id': 'member_002',
        'name': 'Ali Laghari',
        'gender': 'male',
        'phone_number': '03009876543',
        'blood_group': 'O+',
        'occupation': 'Doctor',
      };

      final member = FamilyMember.fromJson(json);

      expect(member.nameEn, 'Ali Laghari');
      expect(member.phoneNumber, '03009876543');
      expect(member.bloodGroup, 'O+');
      expect(member.profession, 'Doctor');
    });

    test('Maintains complete backward compatibility when fields are missing or empty', () {
      // Historical or existing JSON with NO phone, blood group, or profession
      final json = {
        'id': 'ancestor_001',
        'name_en': 'Mir Chakar Khan Laghari',
        'name_ur': 'میر چاکر خان لغاری',
        'gender': 'male',
        'generation': 1,
        'mobile_number': '',
        'blood_group': '',
      };

      final member = FamilyMember.fromJson(json);

      expect(member.phoneNumber, isNull);
      expect(member.bloodGroup, isNull);
      expect(member.profession, isNull);

      // Must display "Unknown" without crashing
      expect(member.displayPhoneNumber, 'Unknown');
      expect(member.displayBloodGroup, 'Unknown');
      expect(member.displayProfession, 'Unknown');
    });

    test('Serializes to JSON with both camelCase and snake_case keys', () {
      const member = FamilyMember(
        id: 'member_003',
        nameEn: 'Fatima Laghari',
        nameUr: 'فاطمہ لغاری',
        gender: 'female',
        aliveStatus: AliveStatus.alive,
        generation: 54,
        phoneNumber: '03111222333',
        bloodGroup: 'A+',
        profession: 'Professor',
      );

      final json = member.toJson();

      expect(json['phoneNumber'], '03111222333');
      expect(json['phone_number'], '03111222333');
      expect(json['bloodGroup'], 'A+');
      expect(json['blood_group'], 'A+');
      expect(json['profession'], 'Professor');
      expect(member.isFemale, isTrue);
    });

    test('copyWith updates individual fields correctly', () {
      const original = FamilyMember(
        id: 'm1',
        nameEn: 'Original',
        nameUr: 'اصل',
        gender: 'male',
        aliveStatus: AliveStatus.alive,
        generation: 50,
      );

      final updated = original.copyWith(
        phoneNumber: '03211112233',
        bloodGroup: 'AB+',
        profession: 'Farmer',
      );

      expect(updated.phoneNumber, '03211112233');
      expect(updated.bloodGroup, 'AB+');
      expect(updated.profession, 'Farmer');
      expect(original.phoneNumber, isNull);
    });
  });
}
