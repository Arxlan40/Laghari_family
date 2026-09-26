import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laghari_family/core/config/app_config.dart';
import 'package:uuid/uuid.dart';
import '../models/audit_log_model.dart';

class AuditLogRepository {
  final FirebaseFirestore? _firestore;
  final List<AuditLogModel> _inMemoryLogs = [];
  final StreamController<List<AuditLogModel>> _logsStreamController =
      StreamController<List<AuditLogModel>>.broadcast();

  AuditLogRepository([this._firestore]) {
    _initDemoLogs();
  }

  void _initDemoLogs() {
    _inMemoryLogs.addAll([
      AuditLogModel(
        logId: 'log_seed_001',
        action: 'approved_edit',
        performedBy: 'superadmin_uid',
        performedByName: 'Arsalan Umar Laghari',
        performedByRole: 'super_admin',
        targetMemberId: 'jaffer_khan_laghari',
        targetMemberName: 'Dr. Jaffer Khan Laghari',
        requestedBy: 'user_001',
        requestedByName: 'Muhammad Ali',
        oldData: {
          'profession': 'Teacher',
        },
        newData: {
          'profession': 'Doctor',
        },
        timestamp: DateTime.now().subtract(const Duration(hours: 5)),
      ),
      AuditLogModel(
        logId: 'log_seed_002',
        action: 'direct_add_child',
        performedBy: 'admin_001',
        performedByName: 'Tariq Laghari',
        performedByRole: 'admin',
        targetMemberId: 'ibrahim_laghari',
        targetMemberName: 'Ibrahim Laghari',
        oldData: {},
        newData: {
          'name_en': 'Ibrahim Laghari',
          'name_ur': 'ابراہیم لغاری',
          'father_id': 'malbo_khan',
          'gender': 'male',
        },
        timestamp: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  bool get _hasLiveFirestore => _firestore != null;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore!.collection(AppConfig.auditLogsCollection);

  /// Records an administrative action in audit history
  Future<void> recordLog(AuditLogModel log) async {
    final logWithId = log.logId.isEmpty
        ? AuditLogModel(
            logId: const Uuid().v4(),
            action: log.action,
            performedBy: log.performedBy,
            performedByName: log.performedByName,
            performedByRole: log.performedByRole,
            targetMemberId: log.targetMemberId,
            targetMemberName: log.targetMemberName,
            requestId: log.requestId,
            requestedBy: log.requestedBy,
            requestedByName: log.requestedByName,
            oldData: log.oldData,
            newData: log.newData,
            timestamp: log.timestamp,
          )
        : log;

    _inMemoryLogs.insert(0, logWithId);
    _logsStreamController.add(List.from(_inMemoryLogs));

    if (_hasLiveFirestore) {
      try {
        await _collection.doc(logWithId.logId).set(logWithId.toJson());
      } catch (e) {
        debugPrint('Error recording audit log in Firestore: $e');
      }
    }
  }

  /// Streams audit logs for Super Admin inspection
  Stream<List<AuditLogModel>> watchAuditLogs() async* {
    yield List.from(_inMemoryLogs);

    if (_hasLiveFirestore) {
      try {
        await for (final snap in _collection.orderBy('timestamp', descending: true).snapshots()) {
          final list = snap.docs
              .map((d) => AuditLogModel.fromJson(d.data(), documentId: d.id))
              .toList();
          yield list;
        }
      } catch (e) {
        debugPrint('Error streaming audit logs from Firestore: $e');
        yield List.from(_inMemoryLogs);
      }
    }
  }
}

final auditLogRepositoryProvider = Provider<AuditLogRepository>((ref) {
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return AuditLogRepository(firestore);
});

final auditLogsStreamProvider = StreamProvider<List<AuditLogModel>>((ref) {
  final repo = ref.watch(auditLogRepositoryProvider);
  return repo.watchAuditLogs();
});
