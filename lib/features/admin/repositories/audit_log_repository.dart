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

  AuditLogRepository([this._firestore]);

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
    if (_inMemoryLogs.isNotEmpty) {
      yield List.from(_inMemoryLogs);
    }

    if (_hasLiveFirestore) {
      try {
        await for (final snap in _collection.orderBy('timestamp', descending: true).snapshots()) {
          final list = snap.docs
              .map((d) => AuditLogModel.fromJson(d.data(), documentId: d.id))
              .toList();
          _inMemoryLogs.clear();
          _inMemoryLogs.addAll(list);
          yield list;
        }
      } catch (e) {
        debugPrint('Error streaming audit logs from Firestore: $e');
        if (_inMemoryLogs.isNotEmpty) {
          yield List.from(_inMemoryLogs);
        } else {
          rethrow;
        }
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
