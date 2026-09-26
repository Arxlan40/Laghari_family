import '../models/validation_report.dart';
import '../../features/family_tree/models/family_member.dart';

class JsonValidator {
  /// Validates a list of raw dynamic items from JSON.
  /// [existingMemberIds] contains IDs already present in Firestore (if any).
  static ValidationReport validate(
    dynamic rawJson, {
    Set<String>? existingMemberIds,
  }) {
    final report = ValidationReport();

    if (rawJson == null) {
      report.addError(null, 'JSON content is null');
      return report;
    }

    List<dynamic> items;
    if (rawJson is List) {
      items = rawJson;
    } else if (rawJson is Map && rawJson['members'] is List) {
      items = rawJson['members'] as List;
    } else {
      report.addError(null, 'Root JSON must be a list of member objects or contain a "members" array.');
      return report;
    }

    report.totalFound = items.length;

    final existingIds = existingMemberIds ?? <String>{};
    final seenIdsInBatch = <String>{};
    final memberMap = <String, Map<String, dynamic>>{};
    final validMembers = <FamilyMember>[];

    // First pass: Structural validation and duplicate detection
    for (int index = 0; index < items.length; index++) {
      final rawItem = items[index];
      final recordIndexStr = 'Record #${index + 1}';

      if (rawItem is! Map) {
        report.addError(recordIndexStr, 'Item is not a valid JSON map/object.');
        report.invalidRecordsCount++;
        continue;
      }

      final item = Map<String, dynamic>.from(rawItem);
      bool isRecordValid = true;

      // 1. Validate ID
      final rawId = item['id'];
      if (rawId == null || rawId.toString().trim().isEmpty) {
        report.addError(recordIndexStr, 'Missing required field: "id"');
        isRecordValid = false;
      }
      final id = rawId?.toString().trim() ?? '';

      // Check duplicate in file
      if (id.isNotEmpty) {
        if (seenIdsInBatch.contains(id)) {
          report.addError(id, 'Duplicate member ID found in file: "$id"');
          isRecordValid = false;
        } else {
          seenIdsInBatch.add(id);
          memberMap[id] = item;
        }
      }

      // 2. Validate Names
      final nameEn = item['name_en']?.toString().trim() ?? '';
      final nameUr = item['name_ur']?.toString().trim() ?? '';
      if (nameEn.isEmpty && nameUr.isEmpty) {
        report.addError(id.isNotEmpty ? id : recordIndexStr, 'Record must contain at least one of "name_en" or "name_ur".');
        isRecordValid = false;
      }

      // 3. Validate Gender
      final gender = item['gender']?.toString().toLowerCase().trim() ?? '';
      if (gender != 'male' && gender != 'female') {
        report.addError(id.isNotEmpty ? id : recordIndexStr, 'Invalid gender "$gender". Must be "male" or "female".');
        isRecordValid = false;
      }

      // 4. Validate Alive Status
      final aliveStatus = item['alive_status']?.toString().toLowerCase().trim() ?? '';
      if (aliveStatus != 'alive' && aliveStatus != 'deceased' && aliveStatus != 'unknown') {
        report.addError(id.isNotEmpty ? id : recordIndexStr, 'Invalid alive_status "$aliveStatus". Must be "alive", "deceased", or "unknown".');
        isRecordValid = false;
      }

      // 5. Check generation
      final genVal = item['generation'];
      int? generation;
      if (genVal is int) {
        generation = genVal;
      } else if (genVal is String) {
        generation = int.tryParse(genVal);
      }
      generation ??= 0;
      if (generation < 0) {
        report.addError(id.isNotEmpty ? id : recordIndexStr, 'Invalid generation "${item['generation']}". Must be a non-negative integer.');
        isRecordValid = false;
      }

      // 6. Prohibited fields check (mother_id, spouse_id)
      if (item.containsKey('mother_id')) {
        report.addWarning(id.isNotEmpty ? id : recordIndexStr, 'Field "mother_id" is not supported and will be ignored.');
      }
      if (item.containsKey('spouse_id')) {
        report.addWarning(id.isNotEmpty ? id : recordIndexStr, 'Field "spouse_id" is not supported and will be ignored.');
      }

      if (!isRecordValid) {
        report.invalidRecordsCount++;
      }
    }

    // Second pass: Relational integrity (father_id, children_ids, circular references)
    final allKnownIds = <String>{...existingIds, ...seenIdsInBatch};

    for (final entry in memberMap.entries) {
      final id = entry.key;
      final item = entry.value;

      final fatherId = (item['father_id'] != null && item['father_id'].toString().trim().isNotEmpty)
          ? item['father_id'].toString().trim()
          : null;

      // Validate father_id
      if (fatherId != null) {
        if (fatherId == id) {
          report.addError(id, 'Self-referencing father: "$id" cannot be their own father.');
        } else if (!allKnownIds.contains(fatherId)) {
          report.addError(id, 'Invalid father_id: "$fatherId" does not exist in dataset or database.');
        }
      }

      // Validate children_ids
      final rawChildren = item['children_ids'];
      if (rawChildren != null && rawChildren is! List) {
        report.addError(id, 'Invalid "children_ids": must be a JSON array of member IDs.');
      } else if (rawChildren is List) {
        for (final child in rawChildren) {
          final childId = child.toString().trim();
          if (childId.isNotEmpty && !allKnownIds.contains(childId)) {
            report.addWarning(id, 'Child ID "$childId" referenced in children_ids does not exist in dataset or database.');
          }
        }
      }

      // Track new vs existing members
      if (existingIds.contains(id)) {
        report.existingMembersCount++;
      } else {
        report.newMembersCount++;
      }

      try {
        validMembers.add(FamilyMember.fromJson(item));
      } catch (e) {
        report.addError(id, 'Failed to deserialize member: $e');
      }
    }

    // Third pass: Detect circular ancestry cycles
    _detectCycles(memberMap, report);

    report.validMembers = validMembers;
    return report;
  }

  /// Traverses father relationships using Floyd's cycle detection or visited sets.
  static void _detectCycles(Map<String, Map<String, dynamic>> memberMap, ValidationReport report) {
    for (final startId in memberMap.keys) {
      final visited = <String>{};
      String? currentId = startId;

      while (currentId != null && memberMap.containsKey(currentId)) {
        if (visited.contains(currentId)) {
          report.addError(
            startId,
            'Circular ancestry loop detected involving "$startId" and "$currentId".',
          );
          break;
        }
        visited.add(currentId);
        final fatherVal = memberMap[currentId]?['father_id'];
        currentId = (fatherVal != null && fatherVal.toString().trim().isNotEmpty)
            ? fatherVal.toString().trim()
            : null;
      }
    }
  }
}
