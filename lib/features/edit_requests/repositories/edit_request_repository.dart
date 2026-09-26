import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laghari_family/core/config/app_config.dart';
import 'package:laghari_family/features/admin/models/audit_log_model.dart';
import 'package:laghari_family/features/admin/repositories/audit_log_repository.dart';
import 'package:laghari_family/features/family_tree/models/family_member.dart';
import 'package:laghari_family/features/family_tree/repositories/family_repository.dart';
import 'package:laghari_family/features/notifications/models/notification_model.dart';
import 'package:laghari_family/features/notifications/repositories/notification_repository.dart';
import 'package:laghari_family/features/auth/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/edit_request.dart';

class EditRequestRepository {
  final FirebaseFirestore? _firestore;
  final FamilyRepository _familyRepo;
  final NotificationRepository _notificationRepo;
  final AuditLogRepository _auditLogRepo;

  final List<EditRequest> _inMemoryRequests = [];
  final StreamController<List<EditRequest>> _requestsStreamController =
      StreamController<List<EditRequest>>.broadcast();

  EditRequestRepository(
    this._firestore,
    this._familyRepo,
    this._notificationRepo,
    this._auditLogRepo,
  ) {
    _initDemoRequests();
  }

  void _initDemoRequests() {
    _inMemoryRequests.addAll([
      EditRequest(
        requestId: 'req_demo_001',
        type: EditRequestType.editMember,
        memberId: 'ghulam_hussain_khan_w',
        targetMemberName: 'Ghulam Hussain Khan',
        requestedBy: 'user_001',
        requestedByName: 'Bilal Tariq Laghari',
        selectedAdminId: 'superadmin_uid',
        selectedAdminName: 'Arsalan Umar (Super Admin)',
        status: RequestStatus.pending,
        changes: {
          'notes': 'Added historical note: Elder of the Derajat branch with ancestral records.',
          'confidence': 'high',
        },
        oldData: {
          'notes': '',
          'confidence': 'low',
        },
        newData: {
          'notes': 'Added historical note: Elder of the Derajat branch with ancestral records.',
          'confidence': 'high',
        },
        reason: 'Adding verified historical citation from family manuscripts.',
        createdAt: DateTime.now().subtract(const Duration(hours: 3)),
      ),
      EditRequest(
        requestId: 'req_demo_002',
        type: EditRequestType.addChild,
        memberId: 'arsalan_umar_laghari',
        targetMemberName: 'Arsalan Umar Laghari',
        requestedBy: 'user_001',
        requestedByName: 'Muhammad Ali',
        selectedAdminId: 'superadmin_uid',
        selectedAdminName: 'Arsalan Umar (Super Admin)',
        status: RequestStatus.pending,
        changes: {
          'name_en': 'Ibrahim Arsalan Laghari',
          'name_ur': 'ابراہیم ارسلان لغاری',
          'father_id': 'arsalan_umar_laghari',
          'gender': 'male',
          'alive_status': 'alive',
          'generation': 59,
          'birth_date': '2025-01-15',
          'notes': 'Newborn family member.',
        },
        oldData: {},
        newData: {
          'name_en': 'Ibrahim Arsalan Laghari',
          'name_ur': 'ابراہیم ارسلان لغاری',
          'father_id': 'arsalan_umar_laghari',
          'gender': 'male',
          'alive_status': 'alive',
        },
        reason: 'Registering newborn child to the branch.',
        createdAt: DateTime.now().subtract(const Duration(hours: 1)),
      ),
    ]);
  }

  bool get _hasLiveFirestore => _firestore != null;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore!.collection(AppConfig.editRequestsCollection);

  /// Submits an edit or add-child request from a normal user
  Future<void> submitRequest(EditRequest request) async {
    final reqWithId = request.requestId.isEmpty
        ? request.copyWith(requestId: const Uuid().v4())
        : request;

    _inMemoryRequests.add(reqWithId);
    _requestsStreamController.add(List.from(_inMemoryRequests));

    if (_hasLiveFirestore) {
      await _collection.doc(reqWithId.requestId).set(reqWithId.toJson());
    }

    // 1. Notify selected Admin specifically if chosen
    final phoneSnippet = reqWithId.requestedByPhone != null && reqWithId.requestedByPhone!.isNotEmpty
        ? ' (📞 ${reqWithId.requestedByPhone})'
        : '';

    if (reqWithId.selectedAdminId != null && reqWithId.selectedAdminId!.isNotEmpty) {
      await _notificationRepo.sendNotification(
        NotificationModel(
          notificationId: const Uuid().v4(),
          userId: reqWithId.selectedAdminId!,
          title: 'Laghari Family: New Request Assigned',
          body: '${reqWithId.requestedByName}$phoneSnippet requested ${reqWithId.type.labelEn} for ${reqWithId.targetMemberName ?? 'a member'}.',
          type: 'new_request',
          createdAt: DateTime.now(),
          metadata: {
            'request_id': reqWithId.requestId,
            'member_id': reqWithId.memberId,
            'user_phone': reqWithId.requestedByPhone,
            'user_name': reqWithId.requestedByName,
          },
        ),
      );
      // Also notify Super Admins for administrative oversight
      await _notificationRepo.sendNotification(
        NotificationModel(
          notificationId: const Uuid().v4(),
          userId: 'all_super_admins',
          title: 'Laghari Family: New Family Tree Request',
          body: '${reqWithId.requestedByName}$phoneSnippet submitted ${reqWithId.type.labelEn} (Assigned to ${reqWithId.selectedAdminName ?? 'Admin'}).',
          type: 'new_request',
          createdAt: DateTime.now(),
          metadata: {
            'request_id': reqWithId.requestId,
            'member_id': reqWithId.memberId,
            'user_phone': reqWithId.requestedByPhone,
            'user_name': reqWithId.requestedByName,
          },
        ),
      );
    } else {
      // Notify all admins
      await _notificationRepo.sendNotification(
        NotificationModel(
          notificationId: const Uuid().v4(),
          userId: 'all_admins',
          title: 'Laghari Family: New Family Tree Request',
          body: '${reqWithId.requestedByName}$phoneSnippet submitted a request: ${reqWithId.type.labelEn}.',
          type: 'new_request',
          createdAt: DateTime.now(),
          metadata: {
            'request_id': reqWithId.requestId,
            'member_id': reqWithId.memberId,
            'user_phone': reqWithId.requestedByPhone,
            'user_name': reqWithId.requestedByName,
          },
        ),
      );
    }
  }

  /// Streams pending requests for administrator review
  Stream<List<EditRequest>> watchPendingRequests({String? adminUid, bool isSuperAdmin = false}) async* {
    List<EditRequest> filterList(List<EditRequest> list) {
      return list.where((r) {
        if (r.status != RequestStatus.pending) return false;
        if (isSuperAdmin) return true;
        if (adminUid == null || adminUid.isEmpty) return true;
        return r.selectedAdminId == null ||
            r.selectedAdminId!.isEmpty ||
            r.selectedAdminId == adminUid;
      }).toList();
    }

    yield filterList(_inMemoryRequests);

    if (_hasLiveFirestore) {
      try {
        await for (final snap in _collection.where('status', isEqualTo: RequestStatus.pending.value).snapshots()) {
          final list = snap.docs
              .map((d) => EditRequest.fromJson(d.data(), documentId: d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          yield filterList(list);
        }
      } catch (e) {
        yield filterList(_inMemoryRequests);
      }
    }
  }

  /// Streams requests submitted by a specific user
  Stream<List<EditRequest>> watchUserRequests(String userId) async* {
    final localList = _inMemoryRequests.where((r) => r.requestedBy == userId).toList();
    yield localList;

    if (_hasLiveFirestore) {
      try {
        await for (final snap in _collection.where('requested_by', isEqualTo: userId).snapshots()) {
          final list = snap.docs
              .map((d) => EditRequest.fromJson(d.data(), documentId: d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          yield list;
        }
      } catch (e) {
        yield localList;
      }
    }
  }

  /// Approves a request, applies changes to the family tree, records an audit log,
  /// and notifies the requester.
  Future<void> approveRequest({
    required String requestId,
    required String reviewerUid,
    required String reviewerName,
    String reviewerRole = 'admin',
    String? reviewerPhone,
  }) async {
    EditRequest? req;

    if (_hasLiveFirestore) {
      final doc = await _collection.doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        req = EditRequest.fromJson(doc.data()!, documentId: doc.id);
      }
    } else {
      final idx = _inMemoryRequests.indexWhere((r) => r.requestId == requestId);
      if (idx != -1) req = _inMemoryRequests[idx];
    }

    if (req == null) throw Exception('Request not found: $requestId');

    String targetMemberName = req.targetMemberName ?? '';

    // Apply the change to Family Member
    if (req.type == EditRequestType.addChild) {
      final newId = req.changes['id'] ??
          (req.changes['name_en'] as String?)?.toLowerCase().replaceAll(' ', '_') ??
          'member_${DateTime.now().millisecondsSinceEpoch}';

      targetMemberName = req.changes['name_en'] ?? targetMemberName;

      final newMember = FamilyMember(
        id: newId.toString(),
        nameEn: req.changes['name_en'] ?? '',
        nameUr: req.changes['name_ur'] ?? '',
        fatherId: req.changes['father_id'] ?? req.memberId,
        gender: req.changes['gender'] ?? 'male',
        aliveStatus: AliveStatus.fromString(req.changes['alive_status']?.toString()),
        generation: int.tryParse(req.changes['generation']?.toString() ?? '1') ?? 1,
        imageUrl: req.changes['image_url'] ?? '',
        phoneNumber: req.changes['phone_number'] ?? req.changes['phoneNumber'],
        bloodGroup: req.changes['blood_group'] ?? req.changes['bloodGroup'],
        profession: req.changes['profession'],
        birthDate: req.changes['birth_date'],
        deathDate: req.changes['death_date'],
        notes: req.changes['notes'],
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await _familyRepo.saveMember(newMember);
    } else if (req.memberId != null) {
      final existing = await _familyRepo.getMemberById(req.memberId!);
      if (existing != null) {
        targetMemberName = existing.nameEn;
        final updatedJson = existing.toJson();
        req.changes.forEach((key, val) {
          if (key != 'mother_id' && key != 'spouse_id') {
            updatedJson[key] = val;
          }
        });
        updatedJson['updated_at'] = DateTime.now().toIso8601String();
        final updated = FamilyMember.fromJson(updatedJson);
        await _familyRepo.saveMember(updated);
      }
    }

    // Update request state
    final updatedReq = req.copyWith(
      status: RequestStatus.approved,
      reviewedAt: DateTime.now(),
      reviewedBy: reviewerUid,
      reviewedByName: reviewerName,
      targetMemberName: targetMemberName,
    );

    if (_hasLiveFirestore) {
      await _collection.doc(requestId).update(updatedReq.toJson());
    } else {
      final idx = _inMemoryRequests.indexWhere((r) => r.requestId == requestId);
      if (idx != -1) _inMemoryRequests[idx] = updatedReq;
    }

    // 1. Record Audit Log for Super Admin history
    await _auditLogRepo.recordLog(
      AuditLogModel(
        logId: const Uuid().v4(),
        action: req.type == EditRequestType.addChild ? 'approved_add_child' : 'approved_edit',
        performedBy: reviewerUid,
        performedByName: reviewerName,
        performedByRole: reviewerRole,
        performedByPhone: reviewerPhone,
        targetMemberId: req.memberId,
        targetMemberName: targetMemberName.isNotEmpty ? targetMemberName : (req.memberId ?? 'Family Member'),
        requestId: requestId,
        requestedBy: req.requestedBy,
        requestedByName: req.requestedByName,
        requestedByPhone: req.requestedByPhone,
        oldData: req.oldData,
        newData: req.newData.isNotEmpty ? req.newData : req.changes,
        timestamp: DateTime.now(),
      ),
    );

    // 2. Send in-app notification to requester
    await _notificationRepo.sendNotification(
      NotificationModel(
        notificationId: const Uuid().v4(),
        userId: req.requestedBy,
        title: req.type == EditRequestType.addChild
            ? 'Laghari Family: Add Child Request Approved'
            : 'Laghari Family: Edit Request Approved',
        body: 'Your request regarding member "${targetMemberName.isNotEmpty ? targetMemberName : (req.memberId ?? 'Family Member')}" has been approved by $reviewerName.',
        type: 'request_approved',
        createdAt: DateTime.now(),
        metadata: {
          'request_id': requestId,
          'member_id': req.memberId,
          'user_phone': req.requestedByPhone,
        },
      ),
    );
  }

  /// Rejects a request with a reason, records audit history, and notifies the requester.
  Future<void> rejectRequest({
    required String requestId,
    required String reviewerUid,
    required String reviewerName,
    String reviewerRole = 'admin',
    String? reviewerPhone,
    required String reason,
  }) async {
    EditRequest? req;

    if (_hasLiveFirestore) {
      final doc = await _collection.doc(requestId).get();
      if (doc.exists && doc.data() != null) {
        req = EditRequest.fromJson(doc.data()!, documentId: doc.id);
      }
    } else {
      final idx = _inMemoryRequests.indexWhere((r) => r.requestId == requestId);
      if (idx != -1) req = _inMemoryRequests[idx];
    }

    if (req == null) throw Exception('Request not found: $requestId');

    final updatedReq = req.copyWith(
      status: RequestStatus.rejected,
      reviewedAt: DateTime.now(),
      reviewedBy: reviewerUid,
      reviewedByName: reviewerName,
      rejectionReason: reason,
    );

    if (_hasLiveFirestore) {
      await _collection.doc(requestId).update(updatedReq.toJson());
    } else {
      final idx = _inMemoryRequests.indexWhere((r) => r.requestId == requestId);
      if (idx != -1) _inMemoryRequests[idx] = updatedReq;
    }

    // 1. Record in Audit Log
    await _auditLogRepo.recordLog(
      AuditLogModel(
        logId: const Uuid().v4(),
        action: 'rejected_request',
        performedBy: reviewerUid,
        performedByName: reviewerName,
        performedByRole: reviewerRole,
        performedByPhone: reviewerPhone,
        targetMemberId: req.memberId,
        targetMemberName: req.targetMemberName ?? req.memberId ?? 'Family Member',
        requestId: requestId,
        requestedBy: req.requestedBy,
        requestedByName: req.requestedByName,
        requestedByPhone: req.requestedByPhone,
        oldData: {'status': 'pending'},
        newData: {'status': 'rejected', 'reason': reason},
        timestamp: DateTime.now(),
      ),
    );

    // 2. Send rejection notification to requester
    await _notificationRepo.sendNotification(
      NotificationModel(
        notificationId: const Uuid().v4(),
        userId: req.requestedBy,
        title: req.type == EditRequestType.addChild
            ? 'Laghari Family: Add Child Request Rejected'
            : 'Laghari Family: Edit Request Rejected',
        body: 'Your request regarding member "${req.targetMemberName ?? req.memberId ?? 'Family Member'}" was rejected. Reason: $reason',
        type: 'request_rejected',
        createdAt: DateTime.now(),
        metadata: {
          'request_id': requestId,
          'member_id': req.memberId,
          'user_phone': req.requestedByPhone,
        },
      ),
    );
  }
}

final editRequestRepositoryProvider = Provider<EditRequestRepository>((ref) {
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  final familyRepo = ref.watch(familyRepositoryProvider);
  final notifRepo = ref.watch(notificationRepositoryProvider);
  final auditRepo = ref.watch(auditLogRepositoryProvider);
  return EditRequestRepository(firestore, familyRepo, notifRepo, auditRepo);
});

final pendingRequestsStreamProvider = StreamProvider<List<EditRequest>>((ref) {
  final repo = ref.watch(editRequestRepositoryProvider);
  final user = ref.watch(currentUserProvider);
  return repo.watchPendingRequests(
    adminUid: user?.uid,
    isSuperAdmin: user?.isSuperAdmin ?? false,
  );
});
