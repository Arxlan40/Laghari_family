import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/family_member.dart';
import '../repositories/family_repository.dart';

class FamilyTreeState {
  final String? selectedMemberId;
  final Set<String> expandedNodeIds;
  final String searchQuery;

  const FamilyTreeState({
    this.selectedMemberId,
    this.expandedNodeIds = const {},
    this.searchQuery = '',
  });

  FamilyTreeState copyWith({
    String? selectedMemberId,
    Set<String>? expandedNodeIds,
    String? searchQuery,
  }) {
    return FamilyTreeState(
      selectedMemberId: selectedMemberId ?? this.selectedMemberId,
      expandedNodeIds: expandedNodeIds ?? this.expandedNodeIds,
      searchQuery: searchQuery ?? this.searchQuery,
    );
  }
}

class FamilyTreeNotifier extends Notifier<FamilyTreeState> {
  @override
  FamilyTreeState build() {
    return const FamilyTreeState();
  }

  void selectMember(String memberId) {
    final newExpanded = Set<String>.from(state.expandedNodeIds)..add(memberId);
    state = state.copyWith(
      selectedMemberId: memberId,
      expandedNodeIds: newExpanded,
    );
  }

  void toggleExpanded(String memberId) {
    final newExpanded = Set<String>.from(state.expandedNodeIds);
    if (newExpanded.contains(memberId)) {
      newExpanded.remove(memberId);
    } else {
      newExpanded.add(memberId);
    }
    state = state.copyWith(expandedNodeIds: newExpanded);
  }

  void setExpandedNodes(Set<String> nodeIds) {
    state = state.copyWith(expandedNodeIds: nodeIds);
  }

  void expandNodes(Iterable<String> nodeIds) {
    final newExpanded = Set<String>.from(state.expandedNodeIds)..addAll(nodeIds);
    state = state.copyWith(expandedNodeIds: newExpanded);
  }

  void collapseAll() {
    state = state.copyWith(expandedNodeIds: {});
  }

  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }
}

final familyTreeStateProvider =
    NotifierProvider<FamilyTreeNotifier, FamilyTreeState>(FamilyTreeNotifier.new);

/// Provider to trigger auto-centering and highlighting on a specific member in the tree
final treeFocusTargetProvider = StateProvider<String?>((ref) => null);

/// Map of all members indexed by ID for fast O(1) graph traversal
final familyMembersMapProvider = Provider<Map<String, FamilyMember>>((ref) {
  final membersAsync = ref.watch(familyMembersStreamProvider);
  final map = <String, FamilyMember>{};
  final members = membersAsync.value;
  if (members != null) {
    for (final m in members) {
      map[m.id] = m;
    }
  }
  return map;
});

/// Ancestor lineage path from root down to selected member
final selectedMemberAncestorsProvider = Provider<List<FamilyMember>>((ref) {
  final map = ref.watch(familyMembersMapProvider);
  final state = ref.watch(familyTreeStateProvider);
  final selectedId = state.selectedMemberId ?? (map.isNotEmpty ? map.keys.first : null);
  if (selectedId == null) return [];

  final ancestors = <FamilyMember>[];
  String? currentFatherId = map[selectedId]?.fatherId;

  while (currentFatherId != null && map.containsKey(currentFatherId)) {
    final father = map[currentFatherId]!;
    ancestors.insert(0, father);
    currentFatherId = father.fatherId;
  }
  return ancestors;
});

/// Immediate children of currently selected member
final selectedMemberChildrenProvider = Provider<List<FamilyMember>>((ref) {
  final map = ref.watch(familyMembersMapProvider);
  final state = ref.watch(familyTreeStateProvider);
  final selectedId = state.selectedMemberId ?? (map.isNotEmpty ? map.keys.first : null);
  if (selectedId == null) return [];

  final current = map[selectedId];
  if (current == null) return [];

  return current.childrenIds
      .map((id) => map[id])
      .whereType<FamilyMember>()
      .toList();
});
