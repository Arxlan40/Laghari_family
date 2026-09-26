import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/core/utils/json_validator.dart';
import 'package:laghari_family/features/family_tree/models/family_member.dart';

void main() {
  group('JsonValidator Tests', () {
    test('Validates the seed family_tree.json successfully', () {
      final file = File('assets/data/family_tree.json');
      expect(file.existsSync(), isTrue);

      final content = file.readAsStringSync();
      final dynamic raw = jsonDecode(content);

      final report = JsonValidator.validate(raw);

      expect(report.isValid, isTrue, reason: 'Errors: ${report.errors}');
      expect(report.totalFound, greaterThan(30));
      expect(report.validMembers.length, equals(report.totalFound));

      // Check no prohibited fields in any member
      for (final m in report.validMembers) {
        expect(m.id.isNotEmpty, isTrue);
        expect(m.gender, anyOf('male', 'female'));
        expect(m.aliveStatus, anyOf(AliveStatus.alive, AliveStatus.deceased, AliveStatus.unknown));
      }
    });

    test('Detects duplicate IDs', () {
      final json = [
        {
          'id': 'person_1',
          'name_en': 'Person One',
          'gender': 'male',
          'alive_status': 'alive',
          'generation': 1,
        },
        {
          'id': 'person_1', // duplicate
          'name_en': 'Person One Again',
          'gender': 'male',
          'alive_status': 'alive',
          'generation': 1,
        }
      ];

      final report = JsonValidator.validate(json);
      expect(report.isValid, isFalse);
      expect(report.errors.any((e) => e.message.contains('Duplicate')), isTrue);
    });

    test('Detects circular ancestry loops', () {
      final json = [
        {
          'id': 'person_a',
          'name_en': 'Person A',
          'father_id': 'person_b',
          'gender': 'male',
          'alive_status': 'deceased',
          'generation': 1,
        },
        {
          'id': 'person_b',
          'name_en': 'Person B',
          'father_id': 'person_a', // circular!
          'gender': 'male',
          'alive_status': 'deceased',
          'generation': 2,
        }
      ];

      final report = JsonValidator.validate(json);
      expect(report.isValid, isFalse);
      expect(report.errors.any((e) => e.message.contains('Circular')), isTrue);
    });

    test('Detects invalid alive_status', () {
      final json = [
        {
          'id': 'person_x',
          'name_en': 'Person X',
          'gender': 'male',
          'alive_status': 'maybe', // invalid!
          'generation': 1,
        }
      ];

      final report = JsonValidator.validate(json);
      expect(report.isValid, isFalse);
      expect(report.errors.any((e) => e.message.contains('Invalid alive_status')), isTrue);
    });
  });
}
