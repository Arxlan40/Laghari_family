import 'dart:convert';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:laghari_family/core/config/app_config.dart';
import 'package:laghari_family/core/models/validation_report.dart';
import 'package:laghari_family/core/utils/json_validator.dart';
import '../models/family_member.dart';

class FamilyRepository {
  final FirebaseFirestore? _firestore;

  // In-memory cache & fallback when running in offline/demo mode
  final Map<String, FamilyMember> _inMemoryStore = {};
  final Set<String> _deletedMemberIds = {};
  bool _localLoaded = false;
  Future<void>? _loadingFuture;

  FamilyRepository([FirebaseFirestore? firestore]) : _firestore = firestore;

  bool get _hasLiveFirestore => _firestore != null;

  CollectionReference<Map<String, dynamic>> get _membersCollection =>
      _firestore!.collection(AppConfig.familyMembersCollection);

  CollectionReference<Map<String, dynamic>> get _deletedMembersCollection =>
      _firestore!.collection('deleted_members');

  DocumentReference<Map<String, dynamic>> get _appSettingsDoc =>
      _firestore!.collection(AppConfig.settingsCollection).doc(AppConfig.appSettingsDoc);

  /// Loads permanently deleted member IDs from SharedPreferences and Firestore
  Future<void> _loadDeletedMemberIds() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final localDeleted = prefs.getStringList('deleted_member_ids') ?? [];
      _deletedMemberIds.addAll(localDeleted);

      if (_hasLiveFirestore) {
        try {
          final snap = await _deletedMembersCollection.get();
          for (final doc in snap.docs) {
            _deletedMemberIds.add(doc.id);
          }
          await prefs.setStringList('deleted_member_ids', _deletedMemberIds.toList());
        } catch (e) {
          debugPrint('Firestore deleted_members fetch note: $e');
        }
      }
    } catch (e) {
      debugPrint('Error loading deleted member IDs: $e');
    }
  }

  /// Loads family tree from local storage file or bundled assets immediately.
  Future<void> _loadLocalData() async {
    if (_localLoaded && _inMemoryStore.isNotEmpty) return;
    if (_loadingFuture != null) {
      await _loadingFuture;
      return;
    }

    _loadingFuture = _doLoadLocalData();
    await _loadingFuture;
    _loadingFuture = null;
  }

  Future<void> _doLoadLocalData() async {
    await _loadDeletedMemberIds();
    try {
      String? jsonStr;
      if (!kIsWeb) {
        try {
          final dir = await getApplicationDocumentsDirectory();
          final localFile = File('${dir.path}/family_tree_local.json');
          if (await localFile.exists()) {
            final content = await localFile.readAsString();
            if (content.trim().isNotEmpty) {
              jsonStr = content;
            }
          }
        } catch (e) {
          debugPrint('Error accessing local family tree file: $e');
        }
      } else {
        try {
          final prefs = await SharedPreferences.getInstance();
          jsonStr = prefs.getString('family_tree_local_json');
        } catch (e) {
          debugPrint('Error reading SharedPreferences for family tree: $e');
        }
      }

      // If local cache doesn't exist yet or was empty, load from bundled assets
      if (jsonStr == null || jsonStr.trim().isEmpty) {
        jsonStr = await rootBundle.loadString('assets/data/family_tree.json');
      }

      final dynamic raw = jsonDecode(jsonStr);
      final report = JsonValidator.validate(raw);
      for (final member in report.validMembers) {
        // Never restore members that were deleted
        if (_deletedMemberIds.contains(member.id)) continue;
        _inMemoryStore[member.id] = member;
      }
      _localLoaded = true;

      _normalizeStore();

      // Ensure local file cache is populated for future instant access
      await _saveToLocalFile();
    } catch (e) {
      debugPrint('Error loading local family tree: $e');
    }
  }

  /// Persists current in-memory store to local JSON file or SharedPreferences
  Future<void> _saveToLocalFile() async {
    try {
      if (_inMemoryStore.isEmpty) return;
      final membersList = _inMemoryStore.values.map((m) => m.toJson()).toList();
      final jsonStr = jsonEncode(membersList);

      if (!kIsWeb) {
        final dir = await getApplicationDocumentsDirectory();
        final localFile = File('${dir.path}/family_tree_local.json');
        await localFile.writeAsString(jsonStr);
      } else {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('family_tree_local_json', jsonStr);
      }
    } catch (e) {
      debugPrint('Error saving local family tree file: $e');
    }
  }

  /// Ensures Firestore is seeded with family members if collection is empty.
  Future<void> ensureInitialDataImported() async {
    // 1. Always load local data first so memory is never empty
    await _loadLocalData();

    if (!_hasLiveFirestore) return;

    try {
      // 2. Check if Firestore actually contains family members (don't rely only on settings flag)
      final existingDocs = await _membersCollection.limit(1).get();
      if (existingDocs.docs.isNotEmpty) {
        debugPrint('Initial family tree already imported in Firestore.');
        return;
      }

      // 3. Collection is empty; seed in batches to respect 500-write limit
      debugPrint('Firestore family_members is empty. Seeding from local store...');
      await _seedAllToFirestore();
    } catch (e) {
      debugPrint('Error in ensureInitialDataImported: $e');
    }
  }

  Future<void> _seedAllToFirestore() async {
    if (!_hasLiveFirestore) return;
    if (_inMemoryStore.isEmpty) {
      await _loadLocalData();
    }

    final members = _inMemoryStore.values.toList();
    if (members.isEmpty) return;

    try {
      // Batch in chunks of 400 writes
      for (var i = 0; i < members.length; i += 400) {
        final end = (i + 400 < members.length) ? i + 400 : members.length;
        final chunk = members.sublist(i, end);
        final batch = _firestore!.batch();
        for (final member in chunk) {
          final docRef = _membersCollection.doc(member.id);
          batch.set(docRef, member.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      }

      await _appSettingsDoc.set({
        AppConfig.initialImportKey: true,
        AppConfig.dataVersionKey: 1,
        'imported_at': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      debugPrint('Successfully seeded ${members.length} members into Firestore.');
    } catch (e) {
      debugPrint('Error seeding family tree to Firestore: $e');
    }
  }

  /// Streams the entire list of family members.
  /// Yields local data IMMEDIATELY for ultra-fast startup, then streams Firestore updates.
  Stream<List<FamilyMember>> watchAllMembers() async* {
    if (!_localLoaded || _inMemoryStore.isEmpty) {
      await _loadLocalData();
    }

    // Immediately yield local data so UI opens instantly
    if (_inMemoryStore.isNotEmpty) {
      yield _inMemoryStore.values.toList();
    }

    if (_hasLiveFirestore) {
      try {
        await for (final snapshot in _membersCollection.snapshots()) {
          if (snapshot.docs.isNotEmpty) {
            final liveIds = <String>{};
            for (final doc in snapshot.docs) {
              if (_deletedMemberIds.contains(doc.id)) continue;
              try {
                final member = FamilyMember.fromJson(doc.data());
                _inMemoryStore[member.id] = member;
                liveIds.add(member.id);
              } catch (e) {
                debugPrint('Error parsing Firestore member ${doc.id}: $e');
              }
            }
            // Actively remove any in-memory store members not in Firestore or in deleted list
            _inMemoryStore.removeWhere((id, _) => !liveIds.contains(id) || _deletedMemberIds.contains(id));
            _saveToLocalFile();
            yield _inMemoryStore.values.toList();
          } else {
            // Firestore returned empty snapshot; trigger background seed and continue showing local data
            debugPrint('Firestore family_members snapshot is empty. Triggering seed...');
            ensureInitialDataImported();
            yield _inMemoryStore.values.toList();
          }
        }
      } catch (error) {
        debugPrint('Firestore watchAllMembers note: $error. Using local memory store.');
        yield _inMemoryStore.values.toList();
      }
    }
  }

  /// Fetches all family members once from memory/local storage and Firestore.
  Future<List<FamilyMember>> getAllMembers() async {
    if (_inMemoryStore.isEmpty) {
      await _loadLocalData();
    }

    if (_hasLiveFirestore) {
      try {
        final snap = await _membersCollection.get();
        if (snap.docs.isNotEmpty) {
          final liveIds = <String>{};
          for (final d in snap.docs) {
            if (_deletedMemberIds.contains(d.id)) continue;
            try {
              final m = FamilyMember.fromJson(d.data());
              _inMemoryStore[m.id] = m;
              liveIds.add(m.id);
            } catch (_) {}
          }
          _inMemoryStore.removeWhere((id, _) => !liveIds.contains(id) || _deletedMemberIds.contains(id));
          await _saveToLocalFile();
        }
      } catch (e) {
        debugPrint('Firestore fetch error: $e');
      }
    }

    return _inMemoryStore.values.toList();
  }

  /// Fetches a single family member by ID.
  Future<FamilyMember?> getMemberById(String id) async {
    if (_deletedMemberIds.contains(id)) return null;
    if (_inMemoryStore.isEmpty) {
      await _loadLocalData();
    }

    if (_inMemoryStore.containsKey(id)) {
      return _inMemoryStore[id];
    }

    if (_hasLiveFirestore) {
      try {
        final doc = await _membersCollection.doc(id).get();
        if (doc.exists && doc.data() != null) {
          final member = FamilyMember.fromJson(doc.data()!);
          _inMemoryStore[member.id] = member;
          return member;
        }
      } catch (e) {
        debugPrint('Error getting member $id from Firestore: $e');
      }
    }
    return null;
  }

  /// Normalizes store to guarantee data integrity:
  /// 1. Stable non-empty IDs for every member.
  /// 2. Bidirectional parent-child relationship consistency without cross-linking.
  /// 3. Removes deleted or dangling IDs.
  void _normalizeStore() {
    final toRemove = <String>[];
    final toAdd = <FamilyMember>[];

    for (final member in _inMemoryStore.values) {
      if (member.id.trim().isEmpty) {
        final newId = 'member_${const Uuid().v4()}';
        toRemove.add(member.id);
        toAdd.add(member.copyWith(id: newId));
      }
    }

    for (final id in toRemove) {
      _inMemoryStore.remove(id);
    }
    for (final m in toAdd) {
      _inMemoryStore[m.id] = m;
    }

    // Bidirectional sync: Ensure every child whose fatherId is set is in father's childrenIds,
    // and no father's childrenIds contains children pointing to a different father.
    for (final member in _inMemoryStore.values.toList()) {
      if (member.fatherId != null && member.fatherId!.isNotEmpty) {
        final father = _inMemoryStore[member.fatherId!];
        if (father != null && !father.childrenIds.contains(member.id)) {
          _inMemoryStore[father.id] = father.copyWith(
            childrenIds: [...father.childrenIds, member.id],
          );
        }
      }
    }

    // Clean up any cross-linked or non-existent children
    for (final entry in _inMemoryStore.entries.toList()) {
      final fatherId = entry.key;
      final father = entry.value;
      final cleanChildren = <String>[];
      for (final cid in father.childrenIds) {
        final child = _inMemoryStore[cid];
        if (child != null && child.fatherId == fatherId) {
          if (!cleanChildren.contains(cid)) {
            cleanChildren.add(cid);
          }
        }
      }
      if (cleanChildren.length != father.childrenIds.length) {
        _inMemoryStore[fatherId] = father.copyWith(childrenIds: cleanChildren);
      }
    }
  }

  /// Returns the maximum depth of descendants below [memberId].
  /// 0 = no children
  /// 1 = has direct children, but none of them have children
  /// 2 = has grandchildren
  /// 3 = has great-grandchildren
  /// 4+ = has great-great-grandchildren or deeper
  int getDescendantDepth(String memberId, {Map<String, FamilyMember>? customMap, Set<String>? visited}) {
    final map = customMap ?? _inMemoryStore;
    visited ??= <String>{};
    if (visited.contains(memberId)) return 0;
    visited.add(memberId);

    final member = map[memberId];
    if (member == null) return 0;

    final children = map.values.where((m) =>
      m.id != memberId &&
      (m.fatherId == memberId || member.childrenIds.contains(m.id))
    ).toList();

    if (children.isEmpty) return 0;

    int maxChildDepth = 0;
    for (final child in children) {
      final depth = getDescendantDepth(child.id, customMap: map, visited: visited);
      if (depth > maxChildDepth) {
        maxChildDepth = depth;
      }
    }
    return 1 + maxChildDepth;
  }

  /// Returns the set of all recursive descendant IDs below [memberId].
  Set<String> getAllDescendantIds(String memberId, {Map<String, FamilyMember>? customMap}) {
    final map = customMap ?? _inMemoryStore;
    final descendants = <String>{};
    final queue = <String>[memberId];
    final visited = <String>{memberId};

    while (queue.isNotEmpty) {
      final currentId = queue.removeAt(0);
      final currentMember = map[currentId];
      final children = map.values.where((m) =>
        m.id != currentId &&
        (m.fatherId == currentId || (currentMember?.childrenIds.contains(m.id) ?? false)) &&
        !visited.contains(m.id)
      ).toList();

      for (final child in children) {
        visited.add(child.id);
        descendants.add(child.id);
        queue.add(child.id);
      }
    }
    return descendants;
  }

  /// Determines whether [memberId] can be deleted according to role and descendant depth.
  /// Rule:
  /// - Admin: Can only delete a member with 3 generations or fewer below them (depth <= 3).
  /// - Super Admin: Can delete even when member has more than 3 generations below them.
  bool canDeleteMember(String memberId, {required bool isSuperAdmin, Map<String, FamilyMember>? customMap}) {
    if (isSuperAdmin) return true;
    final depth = getDescendantDepth(memberId, customMap: customMap);
    return depth <= 3;
  }

  /// Saves or updates a member in memory, local storage file, and Firestore.
  /// Strictly prevents duplicate identities and cross-linking.
  Future<void> saveMember(FamilyMember member) async {
    _deletedMemberIds.remove(member.id);
    if (_inMemoryStore.isEmpty) {
      await _loadLocalData();
    }

    final existingMember = _inMemoryStore[member.id];
    final oldFatherId = existingMember?.fatherId;

    // 1. Update member in memory
    _inMemoryStore[member.id] = member;

    // 2. If father changed, remove from old father's childrenIds
    if (oldFatherId != null && oldFatherId != member.fatherId && _inMemoryStore.containsKey(oldFatherId)) {
      final oldFather = _inMemoryStore[oldFatherId]!;
      final updated = oldFather.childrenIds.where((cid) => cid != member.id).toList();
      _inMemoryStore[oldFatherId] = oldFather.copyWith(childrenIds: updated);
    }

    // 3. If member has father, ensure child is in father's children_ids in memory
    if (member.fatherId != null && member.fatherId!.isNotEmpty) {
      final father = _inMemoryStore[member.fatherId!];
      if (father != null && !father.childrenIds.contains(member.id)) {
        final updatedChildren = [...father.childrenIds, member.id];
        _inMemoryStore[father.id] = father.copyWith(childrenIds: updatedChildren);
      }
    }

    // 4. Ensure no other member mistakenly holds member.id in childrenIds
    for (final other in _inMemoryStore.values) {
      if (other.id != member.fatherId && other.childrenIds.contains(member.id)) {
        final filtered = other.childrenIds.where((cid) => cid != member.id).toList();
        _inMemoryStore[other.id] = other.copyWith(childrenIds: filtered);
      }
    }

    // 5. Persist to local JSON file cache
    await _saveToLocalFile();

    // 6. Update in live Firestore
    if (_hasLiveFirestore) {
      try {
        final batch = _firestore!.batch();
        batch.set(
          _membersCollection.doc(member.id),
          member.toJson(),
          SetOptions(merge: true),
        );
        batch.delete(_deletedMembersCollection.doc(member.id));

        if (oldFatherId != null && oldFatherId.trim().isNotEmpty && oldFatherId != member.fatherId) {
          final oldDoc = await _membersCollection.doc(oldFatherId.trim()).get();
          if (oldDoc.exists && oldDoc.data() != null) {
            final oldFather = FamilyMember.fromJson(oldDoc.data()!);
            final updated = oldFather.childrenIds.where((cid) => cid != member.id).toList();
            batch.update(_membersCollection.doc(oldFatherId.trim()), {
              'children_ids': updated,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        }

        if (member.fatherId != null && member.fatherId!.trim().isNotEmpty) {
          final fatherDoc = await _membersCollection.doc(member.fatherId!.trim()).get();
          if (fatherDoc.exists && fatherDoc.data() != null) {
            final father = FamilyMember.fromJson(fatherDoc.data()!);
            if (!father.childrenIds.contains(member.id)) {
              final updatedChildren = [...father.childrenIds, member.id];
              batch.update(_membersCollection.doc(father.id), {
                'children_ids': updatedChildren,
                'updated_at': DateTime.now().toIso8601String(),
              });
            }
          }
        }

        await batch.commit();
      } catch (e) {
        debugPrint('Error saving member to Firestore: $e');
      }
    }
  }

  /// Cascadingly deletes a member and ALL of their descendants.
  /// Enforces the 3-generation depth limit for normal Admins.
  Future<void> deleteMember(String id, {bool isSuperAdmin = false}) async {
    final cleanId = id.trim();
    if (cleanId.isEmpty) return;

    if (_inMemoryStore.isEmpty) {
      await _loadLocalData();
    }

    final depth = getDescendantDepth(cleanId);
    if (!isSuperAdmin && depth > 3) {
      throw Exception(
        'Admins can only delete members with 3 generations or fewer below them. '
        'This member has $depth generations of descendants. Only a Super Admin can delete this branch.',
      );
    }

    final descendantIds = getAllDescendantIds(cleanId);
    final allIdsToDelete = {cleanId, ...descendantIds}
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toSet();

    // 1. Mark permanently deleted in cache & SharedPreferences
    _deletedMemberIds.addAll(allIdsToDelete);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setStringList('deleted_member_ids', _deletedMemberIds.toList());
    } catch (_) {}

    final member = _inMemoryStore[cleanId];

    // 2. Remove member and all descendants from in-memory store
    for (final delId in allIdsToDelete) {
      _inMemoryStore.remove(delId);
    }

    // 3. Remove deleted member from father's childrenIds in memory
    if (member?.fatherId != null && _inMemoryStore.containsKey(member!.fatherId)) {
      final father = _inMemoryStore[member.fatherId!];
      if (father != null) {
        final updatedChildren = father.childrenIds.where((cid) => !allIdsToDelete.contains(cid)).toList();
        _inMemoryStore[father.id] = father.copyWith(childrenIds: updatedChildren);
      }
    }

    // Clean any other member that holds any deleted ID
    for (final entry in _inMemoryStore.entries) {
      if (entry.value.childrenIds.any((cid) => allIdsToDelete.contains(cid))) {
        final cleanChildren = entry.value.childrenIds.where((cid) => !allIdsToDelete.contains(cid)).toList();
        _inMemoryStore[entry.key] = entry.value.copyWith(childrenIds: cleanChildren);
      }
    }

    // 4. Persist updated in-memory state to local storage
    await _saveToLocalFile();

    // 5. Update Firestore
    if (_hasLiveFirestore) {
      try {
        final batch = _firestore!.batch();

        for (final delId in allIdsToDelete) {
          batch.delete(_membersCollection.doc(delId));
          batch.set(_deletedMembersCollection.doc(delId), {
            'deleted_at': FieldValue.serverTimestamp(),
            'member_id': delId,
          }, SetOptions(merge: true));
        }

        // Update father document in Firestore if father is not being deleted
        final fatherId = member?.fatherId?.trim();
        if (fatherId != null && fatherId.isNotEmpty && !allIdsToDelete.contains(fatherId)) {
          final fatherDoc = await _membersCollection.doc(fatherId).get();
          if (fatherDoc.exists && fatherDoc.data() != null) {
            final father = FamilyMember.fromJson(fatherDoc.data()!);
            final updatedChildren = father.childrenIds.where((cid) => !allIdsToDelete.contains(cid)).toList();
            batch.update(_membersCollection.doc(father.id), {
              'children_ids': updatedChildren,
              'updated_at': DateTime.now().toIso8601String(),
            });
          }
        }

        await batch.commit();
        debugPrint('Successfully cascadingly deleted ${allIdsToDelete.length} members from Firestore.');
      } catch (e) {
        debugPrint('Error cascading deleting members from Firestore: $e');
        rethrow;
      }
    }
  }

  /// Exports the latest family data into formatted JSON string.
  Future<String> exportToJson() async {
    final members = await getAllMembers();
    final jsonList = members.map((m) => m.toJson()).toList();
    const encoder = JsonEncoder.withIndent('  ');
    return encoder.convert(jsonList);
  }

  /// Imports validated members from external JSON into local storage and Firestore.
  Future<ValidationReport> importFromJson(String rawJsonStr) async {
    final dynamic decoded = jsonDecode(rawJsonStr);
    final currentMembers = await getAllMembers();
    final existingIds = currentMembers.map((m) => m.id).toSet();

    final report = JsonValidator.validate(decoded, existingMemberIds: existingIds);
    if (!report.isValid) {
      return report;
    }

    for (final member in report.validMembers) {
      _inMemoryStore[member.id] = member;
    }
    await _saveToLocalFile();

    if (_hasLiveFirestore) {
      final members = report.validMembers;
      for (var i = 0; i < members.length; i += 400) {
        final end = (i + 400 < members.length) ? i + 400 : members.length;
        final chunk = members.sublist(i, end);
        final batch = _firestore!.batch();
        for (final member in chunk) {
          final docRef = _membersCollection.doc(member.id);
          batch.set(docRef, member.toJson(), SetOptions(merge: true));
        }
        await batch.commit();
      }
    }

    return report;
  }
}

final familyRepositoryProvider = Provider<FamilyRepository>((ref) {
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  final repo = FamilyRepository(firestore);
  repo.ensureInitialDataImported();
  return repo;
});

final familyMembersStreamProvider = StreamProvider<List<FamilyMember>>((ref) {
  final repo = ref.watch(familyRepositoryProvider);
  return repo.watchAllMembers();
});
