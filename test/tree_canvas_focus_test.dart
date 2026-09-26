import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/features/family_tree/providers/family_tree_providers.dart';

void main() {
  group('Family Tree Navigation & State Tests', () {
    test('treeFocusTargetProvider is null by default and updates with target member ID', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(treeFocusTargetProvider), isNull);

      container.read(treeFocusTargetProvider.notifier).state = 'ghulam_mohammad';
      expect(container.read(treeFocusTargetProvider), equals('ghulam_mohammad'));

      container.read(treeFocusTargetProvider.notifier).state = null;
      expect(container.read(treeFocusTargetProvider), isNull);
    });

    test('Expanding ancestors updates familyTreeStateProvider expansion state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initialState = container.read(familyTreeStateProvider);
      expect(initialState.selectedMemberId, isNull);
      expect(initialState.expandedNodeIds, isEmpty);

      // Select member
      container.read(familyTreeStateProvider.notifier).selectMember('awais_khan');
      final selectedState = container.read(familyTreeStateProvider);
      expect(selectedState.selectedMemberId, equals('awais_khan'));
      expect(selectedState.expandedNodeIds.contains('awais_khan'), isTrue);

      // Expand multiple ancestors
      container.read(familyTreeStateProvider.notifier).expandNodes(['root_1', 'parent_1']);
      final expandedState = container.read(familyTreeStateProvider);
      expect(expandedState.expandedNodeIds.contains('root_1'), isTrue);
      expect(expandedState.expandedNodeIds.contains('parent_1'), isTrue);

      // Collapse all
      container.read(familyTreeStateProvider.notifier).collapseAll();
      expect(container.read(familyTreeStateProvider).expandedNodeIds, isEmpty);
    });

    test('Search query updates in familyTreeStateProvider', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(familyTreeStateProvider.notifier).setSearchQuery('Awais');
      expect(container.read(familyTreeStateProvider).searchQuery, equals('Awais'));
    });
  });
}
