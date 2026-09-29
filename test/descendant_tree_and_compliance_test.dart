import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/core/config/app_config.dart';
import 'package:laghari_family/core/localization/app_localizations.dart';
import 'package:laghari_family/features/family_tree/models/family_member.dart';
import 'package:laghari_family/features/family_tree/services/descendant_tree_service.dart';

void main() {
  group('DescendantTreeService Tests', () {
    final ancestor = FamilyMember(
      id: 'ancestor_root',
      nameEn: 'Mir Jalal Khan',
      nameUr: 'میر جلال خان',
      gender: 'male',
      aliveStatus: AliveStatus.deceased,
      generation: 1,
      childrenIds: ['jeewan_khan', 'other_branch'],
    );

    final jeewanKhan = FamilyMember(
      id: 'jeewan_khan',
      nameEn: 'Jeewan Khan',
      nameUr: 'جیون خان',
      fatherId: 'ancestor_root',
      gender: 'male',
      aliveStatus: AliveStatus.deceased,
      generation: 2,
      childrenIds: ['child_1', 'child_2'],
    );

    final otherBranch = FamilyMember(
      id: 'other_branch',
      nameEn: 'Other Branch Brother',
      nameUr: 'دوسری شاخ',
      fatherId: 'ancestor_root',
      gender: 'male',
      aliveStatus: AliveStatus.deceased,
      generation: 2,
      childrenIds: ['unrelated_nephew'],
    );

    final unrelatedNephew = FamilyMember(
      id: 'unrelated_nephew',
      nameEn: 'Unrelated Nephew',
      nameUr: 'بھتیجا',
      fatherId: 'other_branch',
      gender: 'male',
      aliveStatus: AliveStatus.alive,
      generation: 3,
    );

    final child1 = FamilyMember(
      id: 'child_1',
      nameEn: 'Child One',
      nameUr: 'پہلا بچہ',
      fatherId: 'jeewan_khan',
      gender: 'male',
      aliveStatus: AliveStatus.deceased,
      generation: 3,
      childrenIds: [],
    );

    final child2 = FamilyMember(
      id: 'child_2',
      nameEn: 'Child Two',
      nameUr: 'دوسرا بچہ',
      fatherId: 'jeewan_khan',
      gender: 'male',
      aliveStatus: AliveStatus.alive,
      generation: 3,
      childrenIds: ['grandchild_1'],
    );

    final grandchild1 = FamilyMember(
      id: 'grandchild_1',
      nameEn: 'Grandchild One',
      nameUr: 'پوتا',
      fatherId: 'child_2',
      gender: 'male',
      aliveStatus: AliveStatus.alive,
      generation: 4,
      childrenIds: [],
    );

    final memberWithNoChildren = FamilyMember(
      id: 'solo_member',
      nameEn: 'Solo Member',
      nameUr: 'اکیلا فرد',
      gender: 'male',
      aliveStatus: AliveStatus.alive,
      generation: 5,
      childrenIds: [],
    );

    final allMembers = <String, FamilyMember>{
      ancestor.id: ancestor,
      jeewanKhan.id: jeewanKhan,
      otherBranch.id: otherBranch,
      unrelatedNephew.id: unrelatedNephew,
      child1.id: child1,
      child2.id: child2,
      grandchild1.id: grandchild1,
      memberWithNoChildren.id: memberWithNoChildren,
    };

    test('getDescendantTree isolates only selected person and their recursive descendants', () {
      final result = DescendantTreeService.getDescendantTree('jeewan_khan', allMembers);

      expect(result, isNotNull);
      // 1. Root must be Jeewan Khan
      expect(result!.root.id, 'jeewan_khan');
      // 2. Root must have fatherId cleared so it renders at the root of the canvas
      expect(result.root.fatherId, isNull);
      // 3. Count direct children
      expect(result.directChildrenCount, 2);
      expect(result.hasChildren, isTrue);
      // 4. Total descendants: child1, child2, grandchild1 = 3
      expect(result.totalDescendantsCount, 3);

      // 5. Must contain Jeewan Khan, Child 1, Child 2, Grandchild 1
      expect(result.membersMap.containsKey('jeewan_khan'), isTrue);
      expect(result.membersMap.containsKey('child_1'), isTrue);
      expect(result.membersMap.containsKey('child_2'), isTrue);
      expect(result.membersMap.containsKey('grandchild_1'), isTrue);

      // 6. Must NOT contain ancestor or other branches
      expect(result.membersMap.containsKey('ancestor_root'), isFalse);
      expect(result.membersMap.containsKey('other_branch'), isFalse);
      expect(result.membersMap.containsKey('unrelated_nephew'), isFalse);
      expect(result.membersMap.containsKey('solo_member'), isFalse);
    });

    test('getDescendantTree returns hasChildren == false when person has no children', () {
      final result = DescendantTreeService.getDescendantTree('solo_member', allMembers);

      expect(result, isNotNull);
      expect(result!.root.id, 'solo_member');
      expect(result.hasChildren, isFalse);
      expect(result.directChildrenCount, 0);
      expect(result.totalDescendantsCount, 0);
      expect(result.membersMap.length, 1);
    });

    test('getDescendantTree returns null for non-existent member id', () {
      final result = DescendantTreeService.getDescendantTree('invalid_id', allMembers);
      expect(result, isNull);
    });
  });

  group('Compliance and Configuration Tests', () {
    test('Official website and privacy policy URLs are configured properly', () {
      expect(AppConfig.officialWebsite, 'https://laghari-family.web.app/');
      expect(
        AppConfig.privacyPolicyUrl,
        'https://www.termsfeed.com/live/3e2e1b33-50aa-4bb5-912a-a7c9f51a1e6c',
      );
    });

    test('Localization keys exist for new features in EN and UR', () {
      final enLoc = AppLocalizations(const Locale('en'));
      final urLoc = AppLocalizations(const Locale('ur'));

      expect(enLoc.translate('see_family_tree'), 'See Family Tree');
      expect(urLoc.translate('see_family_tree'), 'ذاتی شجرہ نسب دیکھیں');

      expect(enLoc.translate('official_website'), 'Official Website');
      expect(urLoc.translate('official_website'), 'سرکاری ویب سائٹ');

      expect(enLoc.translate('privacy_policy'), 'Privacy Policy');
      expect(urLoc.translate('privacy_policy'), 'پرائیویسی پالیسی');

      expect(enLoc.translate('change_password'), 'Change Password');
      expect(urLoc.translate('change_password'), 'پاس ورڈ تبدیل کریں');

      expect(enLoc.translate('delete_account'), 'Delete Account');
      expect(urLoc.translate('delete_account'), 'اکاؤنٹ مستقل حذف کریں');
    });
  });
}
