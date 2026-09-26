import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laghari_family/core/config/app_config.dart';
import 'package:laghari_family/features/admin/models/audit_log_model.dart';
import 'package:laghari_family/features/admin/repositories/audit_log_repository.dart';
import 'package:laghari_family/features/auth/providers/auth_provider.dart';
import 'package:uuid/uuid.dart';
import '../models/notification_model.dart';
import '../services/fcm_service.dart';

class NotificationRepository {
  final FirebaseFirestore? _firestore;
  final AuditLogRepository? _auditLogRepo;
  final List<NotificationModel> _inMemoryNotifications = [];
  final StreamController<List<NotificationModel>> _notifStream =
      StreamController<List<NotificationModel>>.broadcast();

  NotificationRepository([this._firestore, this._auditLogRepo]) {
    _initDemoNotifications();
  }

  void _initDemoNotifications() {
    _inMemoryNotifications.addAll([
      NotificationModel(
        notificationId: 'notif_demo_01',
        userId: 'all_admins',
        title: 'New Edit Request',
        body: 'Bilal Tariq Laghari suggested an edit to Ghulam Hussain Khan.',
        type: 'new_request',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
        metadata: {'request_id': 'req_demo_001'},
      ),
      NotificationModel(
        notificationId: 'notif_demo_02',
        userId: 'all_users',
        title: 'Welcome to Laghari Family Tree',
        body: 'Explore historical branches, search elders, and contribute family updates.',
        type: 'broadcast',
        isRead: false,
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      NotificationModel(
        notificationId: 'notif_demo_03',
        userId: 'superadmin_uid',
        title: 'System Initialized',
        body: 'Laghari Family genealogy database successfully loaded.',
        type: 'system',
        isRead: true,
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ]);
  }

  bool get _hasLiveFirestore => _firestore != null;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore!.collection(AppConfig.notificationsCollection);

  /// Sends a notification into Firestore and memory
  Future<void> sendNotification(NotificationModel notification) async {
    final notifWithId = notification.notificationId.isEmpty
        ? notification.copyWith(notificationId: const Uuid().v4())
        : notification;

    _inMemoryNotifications.insert(0, notifWithId);
    _notifStream.add(List.from(_inMemoryNotifications));

    if (_hasLiveFirestore) {
      try {
        await _collection.doc(notifWithId.notificationId).set(notifWithId.toJson());
      } catch (e) {
        debugPrint('Error writing notification to Firestore: $e');
      }
    }
  }

  /// Super Admin broadcasts notification to all registered users and saves to history & audit logs
  Future<void> sendBroadcastNotification({
    required String title,
    required String body,
    String? senderName,
    String? senderUid,
  }) async {
    final notif = NotificationModel(
      notificationId: const Uuid().v4(),
      userId: 'all_users',
      title: title,
      body: body,
      type: 'broadcast',
      isRead: false,
      createdAt: DateTime.now(),
      metadata: {
        'sender': senderName ?? 'Super Admin',
        'sender_uid': senderUid ?? 'super_admin',
      },
    );
    await sendNotification(notif);

    // Trigger instant local notification on current device
    await FcmService.showLocalNotification(
      title: title,
      body: body,
    );

    // Save in audit logs history for Super Admin
    final auditLog = _auditLogRepo;
    if (auditLog != null) {
      await auditLog.recordLog(
        AuditLogModel(
          logId: const Uuid().v4(),
          action: 'broadcast_notification',
          performedBy: senderUid ?? 'super_admin',
          performedByName: senderName ?? 'Super Admin',
          performedByRole: 'super_admin',
          targetMemberId: 'all_users',
          targetMemberName: 'All Registered Users',
          newData: {
            'title': title,
            'message': body,
          },
          details: 'Broadcast notification sent to all registered users.',
          timestamp: DateTime.now(),
        ),
      );
    }
  }

  /// Streams notifications for a user based on role and target audience
  Stream<List<NotificationModel>> watchUserNotifications(
    String userId, {
    bool isAdmin = false,
    bool isSuperAdmin = false,
  }) async* {
    bool matchesFilter(NotificationModel n) {
      if (n.userId == userId || n.userId == 'all_users') return true;
      if (isAdmin && n.userId == 'all_admins') return true;
      if (isSuperAdmin && (n.userId == 'all_super_admins' || n.userId == 'all_admins')) return true;
      return false;
    }

    final localList = _inMemoryNotifications.where(matchesFilter).toList();
    yield localList;

    if (_hasLiveFirestore) {
      try {
        final filters = <Filter>[
          Filter('user_id', isEqualTo: userId),
          Filter('user_id', isEqualTo: 'all_users'),
        ];
        if (isAdmin) {
          filters.add(Filter('user_id', isEqualTo: 'all_admins'));
        }
        if (isSuperAdmin) {
          filters.add(Filter('user_id', isEqualTo: 'all_super_admins'));
        }

        Filter combinedFilter;
        if (filters.length == 2) {
          combinedFilter = Filter.or(filters[0], filters[1]);
        } else if (filters.length == 3) {
          combinedFilter = Filter.or(filters[0], Filter.or(filters[1], filters[2]));
        } else {
          combinedFilter = Filter.or(
            filters[0],
            Filter.or(filters[1], Filter.or(filters[2], filters[3])),
          );
        }

        bool isInitialSnapshot = true;
        await for (final snap in _collection.where(combinedFilter).snapshots()) {
          final list = snap.docs
              .map((d) => NotificationModel.fromJson(d.data(), documentId: d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));

          if (!isInitialSnapshot) {
            for (final change in snap.docChanges) {
              if (change.type == DocumentChangeType.added) {
                final notif = NotificationModel.fromJson(
                  change.doc.data() ?? {},
                  documentId: change.doc.id,
                );
                if (!notif.isRead) {
                  FcmService.showLocalNotification(
                    title: notif.title,
                    body: notif.body,
                  );
                }
              }
            }
          }
          isInitialSnapshot = false;
          yield list;
        }
      } catch (e) {
        debugPrint('Error streaming notifications from Firestore: $e');
      }
    }
  }

  /// Streams history of sent / broadcast notifications
  Stream<List<NotificationModel>> watchSentNotifications() async* {
    List<NotificationModel> getSent() {
      final list = _inMemoryNotifications
          .where((n) => n.type == 'broadcast' || n.userId == 'all_users')
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    }

    yield getSent();

    if (_hasLiveFirestore) {
      try {
        await for (final snap in _collection
            .where('type', isEqualTo: 'broadcast')
            .snapshots()) {
          final list = snap.docs
              .map((d) => NotificationModel.fromJson(d.data(), documentId: d.id))
              .toList();
          list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
          yield list;
        }
      } catch (e) {
        debugPrint('Error watching sent notifications: $e');
      }
    }
  }

  /// Marks a single notification as read
  Future<void> markAsRead(String notificationId) async {
    final idx = _inMemoryNotifications.indexWhere((n) => n.notificationId == notificationId);
    if (idx != -1) {
      _inMemoryNotifications[idx] = _inMemoryNotifications[idx].copyWith(isRead: true);
      _notifStream.add(List.from(_inMemoryNotifications));
    }

    if (_hasLiveFirestore) {
      try {
        await _collection.doc(notificationId).update({'is_read': true});
      } catch (_) {}
    }
  }

  /// Marks all matching notifications as read
  Future<void> markAllAsRead(String userId, {bool isAdmin = false, bool isSuperAdmin = false}) async {
    for (int i = 0; i < _inMemoryNotifications.length; i++) {
      final n = _inMemoryNotifications[i];
      if (n.userId == userId ||
          n.userId == 'all_users' ||
          (isAdmin && n.userId == 'all_admins') ||
          (isSuperAdmin && (n.userId == 'all_super_admins' || n.userId == 'all_admins'))) {
        _inMemoryNotifications[i] = n.copyWith(isRead: true);
      }
    }
    _notifStream.add(List.from(_inMemoryNotifications));

    if (_hasLiveFirestore) {
      try {
        final snap = await _collection.where('user_id', isEqualTo: userId).where('is_read', isEqualTo: false).get();
        final batch = _firestore!.batch();
        for (final doc in snap.docs) {
          batch.update(doc.reference, {'is_read': true});
        }
        await batch.commit();
      } catch (_) {}
    }
  }
}

final notificationRepositoryProvider = Provider<NotificationRepository>((ref) {
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  final auditLogRepo = ref.watch(auditLogRepositoryProvider);
  return NotificationRepository(firestore, auditLogRepo);
});

final userNotificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final currentUser = ref.watch(currentUserProvider);
  if (currentUser == null) return Stream.value([]);
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watchUserNotifications(
    currentUser.uid,
    isAdmin: currentUser.isAdmin,
    isSuperAdmin: currentUser.isSuperAdmin,
  );
});

final sentNotificationsStreamProvider = StreamProvider<List<NotificationModel>>((ref) {
  final repo = ref.watch(notificationRepositoryProvider);
  return repo.watchSentNotifications();
});

final unreadNotificationsCountProvider = Provider<int>((ref) {
  final notifsAsync = ref.watch(userNotificationsStreamProvider);
  return notifsAsync.valueOrNull?.where((n) => !n.isRead).length ?? 0;
});
