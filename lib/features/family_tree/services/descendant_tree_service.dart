import '../models/family_member.dart';

/// Service to build a scoped descendant tree for a specific family member.
class DescendantTreeResult {
  final FamilyMember root;
  final Map<String, FamilyMember> membersMap;
  final int directChildrenCount;
  final int totalDescendantsCount;

  const DescendantTreeResult({
    required this.root,
    required this.membersMap,
    required this.directChildrenCount,
    required this.totalDescendantsCount,
  });

  bool get hasChildren => directChildrenCount > 0;
}

class DescendantTreeService {
  /// Builds a isolated family tree dataset containing only [rootMemberId] as the root
  /// and all of their recursive descendants (children, grandchildren, etc.).
  ///
  /// Does NOT modify the main family tree data source.
  static DescendantTreeResult? getDescendantTree(
    String rootMemberId,
    Map<String, FamilyMember> allMembers,
  ) {
    final originalRoot = allMembers[rootMemberId];
    if (originalRoot == null) return null;

    final scopedMap = <String, FamilyMember>{};

    // 1. Make selected member the root (disconnecting from ancestors for this isolated tree)
    final scopedRoot = FamilyMember(
      id: originalRoot.id,
      nameEn: originalRoot.nameEn,
      nameUr: originalRoot.nameUr,
      fatherId: null, // Clear fatherId so this person is the root of the tree
      gender: originalRoot.gender,
      aliveStatus: originalRoot.aliveStatus,
      generation: originalRoot.generation,
      childrenIds: originalRoot.childrenIds,
      imageUrl: originalRoot.imageUrl,
      phoneNumber: originalRoot.phoneNumber,
      bloodGroup: originalRoot.bloodGroup,
      profession: originalRoot.profession,
      birthDate: originalRoot.birthDate,
      deathDate: originalRoot.deathDate,
      notes: originalRoot.notes,
      confidence: originalRoot.confidence,
      section: originalRoot.section,
      lineColor: originalRoot.lineColor,
      createdAt: originalRoot.createdAt,
      updatedAt: originalRoot.updatedAt,
    );
    scopedMap[scopedRoot.id] = scopedRoot;

    // 2. Recursively collect all descendants
    final queue = <String>[scopedRoot.id];
    int descendantsCount = 0;

    while (queue.isNotEmpty) {
      final currentParentId = queue.removeAt(0);
      final currentParent = allMembers[currentParentId];
      if (currentParent == null) continue;

      final candidateChildren = <String>{...currentParent.childrenIds};
      for (final m in allMembers.values) {
        if (m.fatherId == currentParentId) {
          candidateChildren.add(m.id);
        }
      }

      for (final childId in candidateChildren) {
        final child = allMembers[childId];
        if (child != null && !scopedMap.containsKey(child.id)) {
          // Include this descendant in the scoped map
          scopedMap[child.id] = child;
          descendantsCount++;
          queue.add(child.id);
        }
      }
    }

    final directChildrenSet = <String>{...originalRoot.childrenIds};
    for (final m in allMembers.values) {
      if (m.fatherId == originalRoot.id) {
        directChildrenSet.add(m.id);
      }
    }
    final directChildrenCount = directChildrenSet
        .where((id) => allMembers.containsKey(id))
        .length;

    return DescendantTreeResult(
      root: scopedRoot,
      membersMap: scopedMap,
      directChildrenCount: directChildrenCount,
      totalDescendantsCount: descendantsCount,
    );
  }
}
