import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/features/admin/models/audit_log_model.dart';
import 'package:laghari_family/features/admin/repositories/audit_log_repository.dart';

void main() {
  group('AuditLogModel Tests', () {
    test('Serializes and deserializes AuditLogModel correctly', () {
      final now = DateTime(2026, 9, 26, 15, 30);
      final log = AuditLogModel(
        logId: 'log_001',
        action: 'approved_request',
        performedBy: 'admin_123',
        performedByName: 'Arsalan Umar',
        performedByRole: 'super_admin',
        targetMemberId: 'jaffer_khan_laghari',
        targetMemberName: 'Jaffer Khan Laghari',
        requestId: 'req_001',
        requestedBy: 'user_456',
        requestedByName: 'Muhammad Ali',
        oldData: {'profession': 'Teacher'},
        newData: {'profession': 'Doctor'},
        details: 'Verified by elder council',
        timestamp: now,
      );

      final json = log.toJson();
      expect(json['log_id'], 'log_001');
      expect(json['action'], 'approved_request');
      expect(json['performed_by'], 'admin_123');
      expect(json['performed_by_name'], 'Arsalan Umar');
      expect(json['performed_by_role'], 'super_admin');
      expect(json['target_member_name'], 'Jaffer Khan Laghari');
      expect(json['requested_by_name'], 'Muhammad Ali');
      expect(json['old_data']['profession'], 'Teacher');
      expect(json['new_data']['profession'], 'Doctor');
      expect(json['details'], 'Verified by elder council');

      final fromJson = AuditLogModel.fromJson(json);
      expect(fromJson.logId, 'log_001');
      expect(fromJson.action, 'approved_request');
      expect(fromJson.performedByName, 'Arsalan Umar');
      expect(fromJson.targetMemberName, 'Jaffer Khan Laghari');
      expect(fromJson.requestedByName, 'Muhammad Ali');
      expect(fromJson.oldData['profession'], 'Teacher');
      expect(fromJson.newData['profession'], 'Doctor');
      expect(fromJson.details, 'Verified by elder council');
    });

    test('AuditLogRepository in-memory logging and streaming', () async {
      final repo = AuditLogRepository();
      final stream = repo.watchAuditLogs();

      final initialLogs = await stream.first;
      expect(initialLogs, isNotEmpty);

      final newLog = AuditLogModel(
        logId: 'test_log_999',
        action: 'direct_delete',
        performedBy: 'admin_007',
        performedByName: 'Admin Seven',
        performedByRole: 'admin',
        targetMemberId: 'test_member',
        targetMemberName: 'Test Member',
        oldData: {'deleted': false},
        newData: {'deleted': true},
        timestamp: DateTime.now(),
      );

      await repo.recordLog(newLog);

      final updatedLogs = await repo.watchAuditLogs().first;
      expect(updatedLogs.any((l) => l.logId == 'test_log_999'), isTrue);
      expect(updatedLogs.first.logId, 'test_log_999');
    });
  });
}
