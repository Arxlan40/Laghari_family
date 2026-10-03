import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/core/services/app_version_service.dart';
import 'package:laghari_family/features/family_tree/models/family_member.dart';
import 'package:laghari_family/features/family_tree/repositories/family_repository.dart';
import 'package:laghari_family/features/notifications/models/notification_model.dart';
import 'package:laghari_family/features/notifications/repositories/notification_repository.dart';

FamilyMember createMember({
  required String id,
  required String nameEn,
  String nameUr = 'نام',
  String? fatherId,
  String gender = 'male',
  AliveStatus aliveStatus = AliveStatus.alive,
  required int generation,
  List<String> childrenIds = const [],
  String? phoneNumber,
}) {
  return FamilyMember(
    id: id,
    nameEn: nameEn,
    nameUr: nameUr,
    fatherId: fatherId,
    gender: gender,
    aliveStatus: aliveStatus,
    generation: generation,
    childrenIds: childrenIds,
    phoneNumber: phoneNumber,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('1. Duplicate Names In Same Generation Tests', () {
    late FamilyRepository repo;

    setUp(() {
      repo = FamilyRepository(null); // In-memory mode
    });

    test('Two members with identical name in same generation remain distinct and uncrossed', () async {
      // Ayub Khan (Gen 52)
      final ayub = createMember(
        id: 'ayub_khan',
        nameEn: 'Ayub Khan',
        nameUr: 'ایوب خان',
        generation: 52,
      );

      // Ahmed Khan (Gen 52)
      final ahmed = createMember(
        id: 'ahmed_khan',
        nameEn: 'Ahmed Khan',
        nameUr: 'احمد خان',
        generation: 52,
      );

      await repo.saveMember(ayub);
      await repo.saveMember(ahmed);

      // Ilyas Khan son of Ayub Khan (Gen 53)
      final ilyasAyub = createMember(
        id: 'ilyas_son_of_ayub',
        nameEn: 'Ilyas Khan',
        nameUr: 'الیاس خان',
        fatherId: 'ayub_khan',
        generation: 53,
      );

      // Ilyas Khan son of Ahmed Khan (Gen 53)
      final ilyasAhmed = createMember(
        id: 'ilyas_son_of_ahmed',
        nameEn: 'Ilyas Khan',
        nameUr: 'الیاس خان',
        fatherId: 'ahmed_khan',
        generation: 53,
      );

      await repo.saveMember(ilyasAyub);
      await repo.saveMember(ilyasAhmed);

      // Add Child A to Ilyas Khan (son of Ayub)
      final childA = createMember(
        id: 'child_a_uuid',
        nameEn: 'Child A',
        nameUr: 'چائلڈ اے',
        fatherId: 'ilyas_son_of_ayub',
        generation: 54,
      );
      await repo.saveMember(childA);

      // Add Child B to Ilyas Khan (son of Ahmed)
      final childB = createMember(
        id: 'child_b_uuid',
        nameEn: 'Child B',
        nameUr: 'چائلڈ بی',
        fatherId: 'ilyas_son_of_ahmed',
        generation: 54,
      );
      await repo.saveMember(childB);

      // Verify relationships
      final updatedIlyasAyub = (await repo.getMemberById('ilyas_son_of_ayub'))!;
      final updatedIlyasAhmed = (await repo.getMemberById('ilyas_son_of_ahmed'))!;

      expect(updatedIlyasAyub.childrenIds, contains('child_a_uuid'));
      expect(updatedIlyasAyub.childrenIds, isNot(contains('child_b_uuid')));

      expect(updatedIlyasAhmed.childrenIds, contains('child_b_uuid'));
      expect(updatedIlyasAhmed.childrenIds, isNot(contains('child_a_uuid')));

      final fetchedChildA = (await repo.getMemberById('child_a_uuid'))!;
      final fetchedChildB = (await repo.getMemberById('child_b_uuid'))!;

      expect(fetchedChildA.fatherId, 'ilyas_son_of_ayub');
      expect(fetchedChildB.fatherId, 'ilyas_son_of_ahmed');

      // Edit one Ilyas Khan (e.g. phone number and alive status)
      final editedIlyasAyub = updatedIlyasAyub.copyWith(
        phoneNumber: '03001112233',
        aliveStatus: AliveStatus.deceased,
      );
      await repo.saveMember(editedIlyasAyub);

      // Verify the other Ilyas Khan is completely untouched
      final checkIlyasAhmed = (await repo.getMemberById('ilyas_son_of_ahmed'))!;
      expect(checkIlyasAhmed.phoneNumber, isNull);
      expect(checkIlyasAhmed.aliveStatus, isNot(AliveStatus.deceased));
    });
  });

  group('2. Cascading Deletion & 3-Generation Rule Tests', () {
    late FamilyRepository repo;

    setUp(() {
      repo = FamilyRepository(null);
    });

    test('Accurately calculates descendant generation depth', () async {
      // Root (Gen 50)
      final gen0 = createMember(id: 'node_0', nameEn: 'Root', generation: 50);
      // Gen 1 below Root
      final gen1 = createMember(id: 'node_1', nameEn: 'Child', fatherId: 'node_0', generation: 51);
      // Gen 2 below Root
      final gen2 = createMember(id: 'node_2', nameEn: 'Grandchild', fatherId: 'node_1', generation: 52);
      // Gen 3 below Root
      final gen3 = createMember(id: 'node_3', nameEn: 'Great-grandchild', fatherId: 'node_2', generation: 53);

      await repo.saveMember(gen0);
      await repo.saveMember(gen1);
      await repo.saveMember(gen2);
      await repo.saveMember(gen3);

      expect(repo.getDescendantDepth('node_3'), 0);
      expect(repo.getDescendantDepth('node_2'), 1);
      expect(repo.getDescendantDepth('node_1'), 2);
      expect(repo.getDescendantDepth('node_0'), 3);
    });

    test('Admin cannot delete member with more than 3 generations below them; Super Admin can', () async {
      // Build 4 generations below node_0
      final gen0 = createMember(id: 'node_0', nameEn: 'Root', generation: 50);
      final gen1 = createMember(id: 'node_1', nameEn: 'Child', fatherId: 'node_0', generation: 51);
      final gen2 = createMember(id: 'node_2', nameEn: 'Grandchild', fatherId: 'node_1', generation: 52);
      final gen3 = createMember(id: 'node_3', nameEn: 'Great-grandchild', fatherId: 'node_2', generation: 53);
      final gen4 = createMember(id: 'node_4', nameEn: 'Great-great-grandchild', fatherId: 'node_3', generation: 54);

      await repo.saveMember(gen0);
      await repo.saveMember(gen1);
      await repo.saveMember(gen2);
      await repo.saveMember(gen3);
      await repo.saveMember(gen4);

      expect(repo.getDescendantDepth('node_0'), 4);

      // Normal Admin attempt
      expect(repo.canDeleteMember('node_0', isSuperAdmin: false), isFalse);
      expect(
        () => repo.deleteMember('node_0', isSuperAdmin: false),
        throwsA(isA<Exception>()),
      );

      // Super Admin attempt
      expect(repo.canDeleteMember('node_0', isSuperAdmin: true), isTrue);
      await repo.deleteMember('node_0', isSuperAdmin: true);

      // All descendants cascadingly deleted without leaving orphans
      expect(await repo.getMemberById('node_0'), isNull);
      expect(await repo.getMemberById('node_1'), isNull);
      expect(await repo.getMemberById('node_2'), isNull);
      expect(await repo.getMemberById('node_3'), isNull);
      expect(await repo.getMemberById('node_4'), isNull);
    });
  });

  group('3. Notification Read State & Persistence Tests', () {
    late NotificationRepository repo;

    setUp(() {
      repo = NotificationRepository();
    });

    test('Per-user read tracking for direct and broadcast notifications', () async {
      const userA = 'user_aaa';
      const userB = 'user_bbb';

      // Direct notification for userA
      final directNotif = NotificationModel(
        notificationId: 'notif_1',
        userId: userA,
        title: 'Edit Request Approved',
        body: 'Your request was approved',
        type: 'approved',
        createdAt: DateTime.now(),
      );

      // Broadcast notification
      final broadcastNotif = NotificationModel(
        notificationId: 'notif_broadcast',
        userId: 'all_users',
        title: 'Eid Mubarak Announcement',
        body: 'Eid Mubarak to all family members',
        type: 'broadcast',
        createdAt: DateTime.now(),
      );

      await repo.sendNotification(directNotif);
      await repo.sendNotification(broadcastNotif);

      // User A marks all as read
      await repo.markAllAsRead(userA);

      // Check User A status
      final afterA = repo.watchUserNotifications(userA);
      final notifsForA = await afterA.first;

      for (final n in notifsForA) {
        expect(n.isReadFor(userA), isTrue);
      }

      // Check User B status: broadcast should still be UNREAD for user B
      final afterB = repo.watchUserNotifications(userB);
      final notifsForB = await afterB.first;
      final broadcastForB = notifsForB.firstWhere((n) => n.notificationId == 'notif_broadcast');
      expect(broadcastForB.isReadFor(userB), isFalse);
    });
  });

  group('4. Semantic Versioning & Android-Only Update Check Tests', () {
    test('AppVersionService checks update availability accurately', () {
      final v1 = SemanticVersion.parse('1.0.0');
      final v2 = SemanticVersion.parse('1.0.1');
      final v3 = SemanticVersion.parse('2.0.0');

      expect(v2 > v1, isTrue);
      expect(v3 > v2, isTrue);
      expect(v1 < v2, isTrue);
      expect(SemanticVersion.parse('1.0.0') == SemanticVersion.parse('v1.0.0'), isTrue);
    });

    test('RemoteVersionInfo model parses Google Play Store URLs correctly', () {
      final info = RemoteVersionInfo.fromMap({
        'latest_version': '1.0.5',
        'download_url': 'market://details?id=com.laghari.family.laghari_family',
        'force_update': false,
      });

      expect(info.isValid, isTrue);
      expect(info.latestVersion, '1.0.5');
      expect(info.downloadUrl, contains('com.laghari.family.laghari_family'));
    });
  });
}
