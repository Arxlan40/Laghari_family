import 'package:cloud_firestore/cloud_firestore.dart';

class HamdardAuditLog {
  final String id;
  final String action; // 'created_donation', 'edited_donation', 'deleted_donation', 'created_spending', 'edited_spending', 'deleted_spending', 'assigned_hamdard_admin', 'removed_hamdard_admin', 'updated_opening_balance', etc.
  final String recordType; // 'donation', 'spending', 'person', 'role', 'settings'
  final String recordId;
  final String performedBy;
  final String performedByName;
  final DateTime timestamp;
  final Map<String, dynamic>? oldData;
  final Map<String, dynamic>? newData;
  final String? details;

  const HamdardAuditLog({
    required this.id,
    required this.action,
    required this.recordType,
    required this.recordId,
    required this.performedBy,
    required this.performedByName,
    required this.timestamp,
    this.oldData,
    this.newData,
    this.details,
  });

  factory HamdardAuditLog.fromJson(Map<String, dynamic> json, {String? documentId}) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      try {
        final dynamic t = val;
        if (t.toDate != null) return t.toDate() as DateTime;
      } catch (_) {}
      return DateTime.now();
    }

    Map<String, dynamic>? parseMap(dynamic val) {
      if (val is Map) return Map<String, dynamic>.from(val);
      return null;
    }

    return HamdardAuditLog(
      id: documentId ?? (json['id'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      recordType: (json['recordType'] ?? json['record_type'] ?? '').toString(),
      recordId: (json['recordId'] ?? json['record_id'] ?? '').toString(),
      performedBy: (json['performedBy'] ?? json['performed_by'] ?? '').toString(),
      performedByName: (json['performedByName'] ?? json['performed_by_name'] ?? '').toString(),
      timestamp: parseDate(json['timestamp']),
      oldData: parseMap(json['oldData'] ?? json['old_data']),
      newData: parseMap(json['newData'] ?? json['new_data']),
      details: (json['details'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'action': action,
      'record_type': recordType,
      'recordType': recordType,
      'record_id': recordId,
      'recordId': recordId,
      'performed_by': performedBy,
      'performedBy': performedBy,
      'performed_by_name': performedByName,
      'performedByName': performedByName,
      'timestamp': Timestamp.fromDate(timestamp),
      if (oldData != null) 'old_data': oldData,
      if (newData != null) 'new_data': newData,
      if (details != null) 'details': details,
    };
  }
}
