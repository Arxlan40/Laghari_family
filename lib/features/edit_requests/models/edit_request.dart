enum EditRequestType {
  editMember('edit_member'),
  addChild('add_child'),
  uploadPicture('upload_picture');

  final String value;
  const EditRequestType(this.value);

  static EditRequestType fromString(String? val) {
    if (val == null) return EditRequestType.editMember;
    switch (val.toLowerCase().trim()) {
      case 'add_child':
        return EditRequestType.addChild;
      case 'upload_picture':
        return EditRequestType.uploadPicture;
      case 'edit_member':
      default:
        return EditRequestType.editMember;
    }
  }

  String get labelEn {
    switch (this) {
      case EditRequestType.editMember:
        return 'Edit Member';
      case EditRequestType.addChild:
        return 'Add Child';
      case EditRequestType.uploadPicture:
        return 'Upload Picture';
    }
  }

  String get labelUr {
    switch (this) {
      case EditRequestType.editMember:
        return 'ترمیم کی درخواست';
      case EditRequestType.addChild:
        return 'بچے کے اندراج کی درخواست';
      case EditRequestType.uploadPicture:
        return 'تصویر شامل کرنے کی درخواست';
    }
  }
}

enum RequestStatus {
  pending('pending'),
  approved('approved'),
  rejected('rejected'),
  cancelled('cancelled');

  final String value;
  const RequestStatus(this.value);

  static RequestStatus fromString(String? val) {
    if (val == null) return RequestStatus.pending;
    switch (val.toLowerCase().trim()) {
      case 'approved':
        return RequestStatus.approved;
      case 'rejected':
        return RequestStatus.rejected;
      case 'cancelled':
        return RequestStatus.cancelled;
      case 'pending':
      default:
        return RequestStatus.pending;
    }
  }

  bool get isPending => this == RequestStatus.pending;
  bool get isApproved => this == RequestStatus.approved;
  bool get isRejected => this == RequestStatus.rejected;
  bool get isCancelled => this == RequestStatus.cancelled;

  String get labelEn {
    switch (this) {
      case RequestStatus.pending:
        return 'Pending';
      case RequestStatus.approved:
        return 'Approved';
      case RequestStatus.rejected:
        return 'Rejected';
      case RequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  String get labelUr {
    switch (this) {
      case RequestStatus.pending:
        return 'زیر التواء';
      case RequestStatus.approved:
        return 'منظور شدہ';
      case RequestStatus.rejected:
        return 'مسترد شدہ';
      case RequestStatus.cancelled:
        return 'منسوخ شدہ';
    }
  }
}

class EditRequest {
  final String requestId;
  final EditRequestType type;
  final String? memberId; // Target member ID
  final String? targetMemberName;
  final String requestedBy;
  final String requestedByName;
  final String? selectedAdminId;
  final String? selectedAdminName;
  final RequestStatus status;
  final Map<String, dynamic> changes;
  final Map<String, dynamic> oldData;
  final Map<String, dynamic> newData;
  final String? changesSummary;
  final String reason;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final DateTime? reviewedAt;
  final String? reviewedBy;
  final String? reviewedByName;
  final String? rejectionReason;

  // Convenient Aliases
  String get submittedBy => requestedBy;
  String get submittedByName => requestedByName;
  String? get targetMemberId => memberId;
  String get requestType => type.value;

  const EditRequest({
    required this.requestId,
    required this.type,
    this.memberId,
    this.targetMemberName,
    required this.requestedBy,
    required this.requestedByName,
    this.selectedAdminId,
    this.selectedAdminName,
    this.status = RequestStatus.pending,
    required this.changes,
    this.oldData = const {},
    this.newData = const {},
    this.changesSummary,
    required this.reason,
    required this.createdAt,
    this.updatedAt,
    this.reviewedAt,
    this.reviewedBy,
    this.reviewedByName,
    this.rejectionReason,
  });

  factory EditRequest.fromJson(Map<String, dynamic> json, {String? documentId}) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val == null) return fallback ?? DateTime.now();
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? fallback ?? DateTime.now();
      try {
        final dynamic t = val;
        if (t.toDate != null) return t.toDate() as DateTime;
      } catch (_) {}
      return fallback ?? DateTime.now();
    }

    final rawChanges = (json['changes'] is Map)
        ? Map<String, dynamic>.from(json['changes'] as Map)
        : <String, dynamic>{};

    final rawOld = (json['old_data'] is Map)
        ? Map<String, dynamic>.from(json['old_data'] as Map)
        : ((json['oldData'] is Map) ? Map<String, dynamic>.from(json['oldData'] as Map) : <String, dynamic>{});

    final rawNew = (json['new_data'] is Map)
        ? Map<String, dynamic>.from(json['new_data'] as Map)
        : ((json['newData'] is Map) ? Map<String, dynamic>.from(json['newData'] as Map) : rawChanges);

    return EditRequest(
      requestId: documentId ?? (json['request_id'] ?? json['requestId'] ?? '').toString(),
      type: EditRequestType.fromString((json['type'] ?? json['request_type'] ?? json['requestType'])?.toString()),
      memberId: (json['member_id'] ?? json['target_member_id'] ?? json['targetMemberId'])?.toString(),
      targetMemberName: (json['target_member_name'] ?? json['targetMemberName'])?.toString(),
      requestedBy: (json['requested_by'] ?? json['submitted_by'] ?? json['submittedBy'] ?? '').toString(),
      requestedByName: (json['requested_by_name'] ?? json['submitted_by_name'] ?? json['submittedByName'] ?? '').toString(),
      selectedAdminId: (json['selected_admin_id'] ?? json['selectedAdminId'])?.toString(),
      selectedAdminName: (json['selected_admin_name'] ?? json['selectedAdminName'])?.toString(),
      status: RequestStatus.fromString(json['status']?.toString()),
      changes: rawChanges.isNotEmpty ? rawChanges : rawNew,
      oldData: rawOld,
      newData: rawNew,
      changesSummary: (json['changes_summary'] ?? json['changesSummary'])?.toString(),
      reason: (json['reason'] ?? '').toString(),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: (json['updated_at'] ?? json['updatedAt']) != null
          ? parseDate(json['updated_at'] ?? json['updatedAt'])
          : null,
      reviewedAt: (json['reviewed_at'] ?? json['reviewedAt']) != null
          ? parseDate(json['reviewed_at'] ?? json['reviewedAt'])
          : null,
      reviewedBy: (json['reviewed_by'] ?? json['reviewedBy'])?.toString(),
      reviewedByName: (json['reviewed_by_name'] ?? json['reviewedByName'])?.toString(),
      rejectionReason: (json['rejection_reason'] ?? json['rejectionReason'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'request_id': requestId,
      'type': type.value,
      'request_type': type.value,
      'member_id': memberId,
      'target_member_id': memberId,
      'target_member_name': targetMemberName,
      'requested_by': requestedBy,
      'submitted_by': requestedBy,
      'requested_by_name': requestedByName,
      'submitted_by_name': requestedByName,
      'selected_admin_id': selectedAdminId,
      'selected_admin_name': selectedAdminName,
      'status': status.value,
      'changes': changes,
      'old_data': oldData,
      'new_data': newData,
      'changes_summary': changesSummary,
      'reason': reason,
      'created_at': createdAt.toIso8601String(),
      'updated_at': (updatedAt ?? DateTime.now()).toIso8601String(),
      'reviewed_at': reviewedAt?.toIso8601String(),
      'reviewed_by': reviewedBy,
      'reviewed_by_name': reviewedByName,
      'rejection_reason': rejectionReason,
    };
  }

  EditRequest copyWith({
    String? requestId,
    EditRequestType? type,
    String? memberId,
    String? targetMemberName,
    String? requestedBy,
    String? requestedByName,
    String? selectedAdminId,
    String? selectedAdminName,
    RequestStatus? status,
    Map<String, dynamic>? changes,
    Map<String, dynamic>? oldData,
    Map<String, dynamic>? newData,
    String? changesSummary,
    String? reason,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? reviewedAt,
    String? reviewedBy,
    String? reviewedByName,
    String? rejectionReason,
  }) {
    return EditRequest(
      requestId: requestId ?? this.requestId,
      type: type ?? this.type,
      memberId: memberId ?? this.memberId,
      targetMemberName: targetMemberName ?? this.targetMemberName,
      requestedBy: requestedBy ?? this.requestedBy,
      requestedByName: requestedByName ?? this.requestedByName,
      selectedAdminId: selectedAdminId ?? this.selectedAdminId,
      selectedAdminName: selectedAdminName ?? this.selectedAdminName,
      status: status ?? this.status,
      changes: changes ?? this.changes,
      oldData: oldData ?? this.oldData,
      newData: newData ?? this.newData,
      changesSummary: changesSummary ?? this.changesSummary,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      reviewedAt: reviewedAt ?? this.reviewedAt,
      reviewedBy: reviewedBy ?? this.reviewedBy,
      reviewedByName: reviewedByName ?? this.reviewedByName,
      rejectionReason: rejectionReason ?? this.rejectionReason,
    );
  }
}
