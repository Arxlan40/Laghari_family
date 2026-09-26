class AuditLogModel {
  final String logId;
  final String action;
  final String performedBy;
  final String performedByName;
  final String performedByRole;
  final String? performedByPhone;
  final String? targetMemberId;
  final String? targetMemberName;
  final String? requestId;
  final String? requestedBy;
  final String? requestedByName;
  final String? requestedByPhone;
  final Map<String, dynamic> oldData;
  final Map<String, dynamic> newData;
  final String? details;
  final DateTime timestamp;

  const AuditLogModel({
    required this.logId,
    required this.action,
    required this.performedBy,
    required this.performedByName,
    required this.performedByRole,
    this.performedByPhone,
    this.targetMemberId,
    this.targetMemberName,
    this.requestId,
    this.requestedBy,
    this.requestedByName,
    this.requestedByPhone,
    this.oldData = const {},
    this.newData = const {},
    this.details,
    required this.timestamp,
  });

  String get actionTitle {
    switch (action) {
      case 'approved_edit':
      case 'approved_request':
        return 'Approved Edit Request';
      case 'approved_add_child':
        return 'Approved Add Child Request';
      case 'rejected_request':
        return 'Rejected Request';
      case 'direct_add_child':
        return 'Added Child (Direct)';
      case 'direct_edit':
        return 'Edited Family Member (Direct)';
      case 'direct_delete':
        return 'Deleted Member (Direct)';
      case 'broadcast_notification':
        return 'Sent Notification to All Users';
      default:
        return action.replaceAll('_', ' ').toUpperCase();
    }
  }

  factory AuditLogModel.fromJson(Map<String, dynamic> json, {String? documentId}) {
    DateTime parseDate(dynamic val) {
      if (val == null) return DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? DateTime.now();
      try {
        final dynamic t = val;
        if (t.toDate != null) return t.toDate() as DateTime;
      } catch (_) {}
      return DateTime.now();
    }

    return AuditLogModel(
      logId: documentId ?? (json['log_id'] ?? json['logId'] ?? '').toString(),
      action: (json['action'] ?? '').toString(),
      performedBy: (json['performed_by'] ?? json['performedBy'] ?? '').toString(),
      performedByName: (json['performed_by_name'] ?? json['performedByName'] ?? 'Admin').toString(),
      performedByRole: (json['performed_by_role'] ?? json['performedByRole'] ?? 'admin').toString(),
      performedByPhone: (json['performed_by_phone'] ?? json['performedByPhone'] ?? json['phone'])?.toString(),
      targetMemberId: json['target_member_id']?.toString() ?? json['targetMemberId']?.toString(),
      targetMemberName: json['target_member_name']?.toString() ?? json['targetMemberName']?.toString(),
      requestId: json['request_id']?.toString() ?? json['requestId']?.toString(),
      requestedBy: json['requested_by']?.toString() ?? json['requestedBy']?.toString(),
      requestedByName: json['requested_by_name']?.toString() ?? json['requestedByName']?.toString(),
      requestedByPhone: (json['requested_by_phone'] ?? json['requestedByPhone'])?.toString(),
      oldData: json['old_data'] is Map
          ? Map<String, dynamic>.from(json['old_data'] as Map)
          : (json['oldData'] is Map ? Map<String, dynamic>.from(json['oldData'] as Map) : const {}),
      newData: json['new_data'] is Map
          ? Map<String, dynamic>.from(json['new_data'] as Map)
          : (json['newData'] is Map ? Map<String, dynamic>.from(json['newData'] as Map) : const {}),
      details: json['details']?.toString(),
      timestamp: parseDate(json['timestamp'] ?? json['created_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'log_id': logId,
      'action': action,
      'performed_by': performedBy,
      'performed_by_name': performedByName,
      'performed_by_role': performedByRole,
      'performed_by_phone': performedByPhone,
      'target_member_id': targetMemberId,
      'target_member_name': targetMemberName,
      'request_id': requestId,
      'requested_by': requestedBy,
      'requested_by_name': requestedByName,
      'requested_by_phone': requestedByPhone,
      'old_data': oldData,
      'new_data': newData,
      'details': details,
      'timestamp': timestamp.toIso8601String(),
    };
  }
}
