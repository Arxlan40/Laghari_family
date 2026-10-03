import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:laghari_family/core/config/app_config.dart';
import 'package:laghari_family/core/services/crashlytics_service.dart';
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

  NotificationRepository([this._firestore, this._auditLogRepo]);

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

          if (isInitialSnapshot) {
            CrashlyticsService.instance.log('User notifications loaded: count=${list.length}');
          }

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
  Future<void> markAsRead(String notificationId, {String? userId}) async {
    final idx = _inMemoryNotifications.indexWhere((n) => n.notificationId == notificationId);
    if (idx != -1) {
      final current = _inMemoryNotifications[idx];
      final newReadBy = List<String>.from(current.readBy);
      if (userId != null && !newReadBy.contains(userId)) {
        newReadBy.add(userId);
      }
      _inMemoryNotifications[idx] = current.copyWith(
        isRead: (userId == null || current.userId == userId) ? true : current.isRead,
        readBy: newReadBy,
      );
      _notifStream.add(List.from(_inMemoryNotifications));
    }

    if (_hasLiveFirestore) {
      try {
        final updateData = <String, dynamic>{};
        if (userId != null) {
          updateData['read_by'] = FieldValue.arrayUnion([userId]);
        }
        updateData['is_read'] = true;
        await _collection.doc(notificationId).update(updateData);
      } catch (_) {}
    }
  }

  /// Marks all notifications belonging to the user as read (including broadcast)
  Future<void> markAllAsRead(String userId, {bool isAdmin = false, bool isSuperAdmin = false}) async {
    bool matchesUser(NotificationModel n) {
      if (n.userId == userId || n.userId == 'all_users') return true;
      if (isAdmin && n.userId == 'all_admins') return true;
      if (isSuperAdmin && (n.userId == 'all_super_admins' || n.userId == 'all_admins')) return true;
      return false;
    }

    for (int i = 0; i < _inMemoryNotifications.length; i++) {
      final n = _inMemoryNotifications[i];
      if (matchesUser(n)) {
        final newReadBy = List<String>.from(n.readBy);
        if (!newReadBy.contains(userId)) newReadBy.add(userId);
        _inMemoryNotifications[i] = n.copyWith(
          isRead: n.userId == userId ? true : n.isRead,
          readBy: newReadBy,
        );
      }
    }
    _notifStream.add(List.from(_inMemoryNotifications));

    if (_hasLiveFirestore) {
      try {
        // 1. Direct user notifications: update is_read = true and read_by
        final userSnap = await _collection
            .where('user_id', isEqualTo: userId)
            .where('is_read', isEqualTo: false)
            .get();
        if (userSnap.docs.isNotEmpty) {
          final batch = _firestore!.batch();
          for (final doc in userSnap.docs) {
            batch.update(doc.reference, {
              'is_read': true,
              'read_by': FieldValue.arrayUnion([userId]),
            });
          }
          await batch.commit();
        }

        // 2. Broadcast / audience notifications: add userId to read_by array
        final broadcastAudiences = <String>['all_users'];
        if (isAdmin) broadcastAudiences.add('all_admins');
        if (isSuperAdmin) broadcastAudiences.add('all_super_admins');

        for (final audience in broadcastAudiences) {
          final snap = await _collection
              .where('user_id', isEqualTo: audience)
              .get();
          if (snap.docs.isNotEmpty) {
            final batch = _firestore!.batch();
            bool hasUpdates = false;
            for (final doc in snap.docs) {
              final data = doc.data();
              final readByList = data['read_by'] as List? ?? [];
              if (!readByList.contains(userId)) {
                batch.update(doc.reference, {
                  'read_by': FieldValue.arrayUnion([userId]),
                });
                hasUpdates = true;
              }
            }
            if (hasUpdates) {
              await batch.commit();
            }
          }
        }
      } catch (e) {
        debugPrint('Error marking all notifications read in Firestore: $e');
      }
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

final badgeClearedOptimisticallyProvider = StateProvider<bool>((ref) => false);

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
  final isCleared = ref.watch(badgeClearedOptimisticallyProvider);
  final currentUser = ref.watch(currentUserProvider);

  if (currentUser == null) return 0;
  final currentUserId = currentUser.uid;

  final actualUnread = notifsAsync.valueOrNull
          ?.where((n) => !n.isReadFor(currentUserId))
          .length ??
      0;

  // Safely reset optimistic badge flag whenever new notifications arrive
  ref.listen<AsyncValue<List<NotificationModel>>>(userNotificationsStreamProvider, (prev, next) {
    final prevCount = prev?.valueOrNull?.where((n) => !n.isReadFor(currentUserId)).length ?? 0;
    final nextCount = next.valueOrNull?.where((n) => !n.isReadFor(currentUserId)).length ?? 0;
    if (nextCount > prevCount) {
      ref.read(badgeClearedOptimisticallyProvider.notifier).state = false;
    }
  });

  if (isCleared && actualUnread > 0) {
    return 0;
  }
  return actualUnread;
});
