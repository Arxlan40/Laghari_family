import 'dart:async';
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import '../../../core/config/app_config.dart';
import '../models/hamdard_audit_log.dart';
import '../models/hamdard_donation.dart';
import '../models/hamdard_person.dart';
import '../models/hamdard_spending.dart';

class HamdardImportSummary {
  final int totalRecords;
  final int newAdded;
  final int alreadyExisted;
  final int invalidRecords;
  final List<String> errorMessages;

  const HamdardImportSummary({
    required this.totalRecords,
    required this.newAdded,
    required this.alreadyExisted,
    required this.invalidRecords,
    this.errorMessages = const [],
  });
}

class HamdardRepository {
  final FirebaseFirestore? _firestore;

  FirebaseFirestore? get activeFirestore {
    if (_firestore != null) return _firestore;
    try {
      return FirebaseFirestore.instance;
    } catch (_) {
      return null;
    }
  }

  // In-memory data structures for fast UI, testing, and offline resilience
  final List<HamdardPerson> _inMemoryPeople = [];
  final List<HamdardDonation> _inMemoryDonations = [];
  final List<HamdardSpending> _inMemorySpending = [];
  final List<HamdardAuditLog> _inMemoryAuditLogs = [];
  int _inMemoryOpeningBalance = 0;

  final StreamController<List<HamdardPerson>> _peopleStream = StreamController<List<HamdardPerson>>.broadcast();
  final StreamController<List<HamdardDonation>> _donationsStream = StreamController<List<HamdardDonation>>.broadcast();
  final StreamController<List<HamdardSpending>> _spendingStream = StreamController<List<HamdardSpending>>.broadcast();
  final StreamController<List<HamdardAuditLog>> _auditLogsStream = StreamController<List<HamdardAuditLog>>.broadcast();
  final StreamController<int> _openingBalanceStream = StreamController<int>.broadcast();

  HamdardRepository([this._firestore]);

  static final NumberFormat _pkrFormatter = NumberFormat('#,##0', 'en_US');

  /// Formats PKR amount with thousand separators: e.g. Rs. 5,000
  static String formatPkr(int amount) {
    if (amount < 0) {
      return '-Rs. ${_pkrFormatter.format(-amount)}';
    }
    return 'Rs. ${_pkrFormatter.format(amount)}';
  }

  // -------------------------------------------------------------
  // OPENING BALANCE & SETTINGS
  // -------------------------------------------------------------
  Stream<int> watchOpeningBalance() async* {
    yield _inMemoryOpeningBalance;
    final fs = activeFirestore;
    if (fs != null) {
      yield* fs
          .collection(AppConfig.hamdardSettingsCollection)
          .doc(AppConfig.hamdardFinancialSettingsDoc)
          .snapshots()
          .map((snap) {
        if (snap.exists && snap.data() != null) {
          final val = snap.data()!['opening_balance'];
          if (val is num) {
            _inMemoryOpeningBalance = val.toInt();
          }
        }
        return _inMemoryOpeningBalance;
      });
    } else {
      yield* _openingBalanceStream.stream;
    }
  }

  Future<int> getOpeningBalance() async {
    final fs = activeFirestore;
    if (fs != null) {
      try {
        final doc = await fs
            .collection(AppConfig.hamdardSettingsCollection)
            .doc(AppConfig.hamdardFinancialSettingsDoc)
            .get();
        if (doc.exists && doc.data() != null) {
          final val = doc.data()!['opening_balance'];
          if (val is num) {
            _inMemoryOpeningBalance = val.toInt();
          }
        }
      } catch (e) {
        debugPrint('Error getting Hamdard opening balance: $e');
      }
    }
    return _inMemoryOpeningBalance;
  }

  /// Super Admin ONLY: updates opening balance and writes an audit log
  Future<void> setOpeningBalance(
    int amount, {
    required String performedBy,
    required String performedByName,
    String reason = '',
  }) async {
    final oldBalance = _inMemoryOpeningBalance;
    _inMemoryOpeningBalance = amount;
    _openingBalanceStream.add(amount);

    final fs = activeFirestore;
    if (fs != null) {
      await fs
          .collection(AppConfig.hamdardSettingsCollection)
          .doc(AppConfig.hamdardFinancialSettingsDoc)
          .set({
        'opening_balance': amount,
        'updated_by': performedBy,
        'updated_by_name': performedByName,
        'updated_at': FieldValue.serverTimestamp(),
        'reason': reason,
      }, SetOptions(merge: true));
    }

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'updated_opening_balance',
      recordType: 'settings',
      recordId: AppConfig.hamdardFinancialSettingsDoc,
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: DateTime.now(),
      oldData: {'opening_balance': oldBalance},
      newData: {'opening_balance': amount, 'reason': reason},
      details: 'Super Admin updated opening balance to ${formatPkr(amount)}',
    ));
  }

  // -------------------------------------------------------------
  // HAMDARD PEOPLE MANAGEMENT
  // -------------------------------------------------------------
  Stream<List<HamdardPerson>> watchPeople() async* {
    yield List.from(_inMemoryPeople);
    final fs = activeFirestore;
    if (fs != null) {
      yield* fs.collection(AppConfig.hamdardPeopleCollection).snapshots().map((snap) {
        final list = snap.docs.map((d) => HamdardPerson.fromJson(d.data(), documentId: d.id)).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _inMemoryPeople
          ..clear()
          ..addAll(list);
        return list;
      });
    } else {
      yield* _peopleStream.stream;
    }
  }

  Future<List<HamdardPerson>> getPeople() async {
    final fs = activeFirestore;
    if (fs != null) {
      try {
        final snap = await fs.collection(AppConfig.hamdardPeopleCollection).get();
        final list = snap.docs.map((d) => HamdardPerson.fromJson(d.data(), documentId: d.id)).toList();
        list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _inMemoryPeople
          ..clear()
          ..addAll(list);
        return list;
      } catch (e) {
        debugPrint('Error getting Hamdard people from Firestore: $e');
      }
    }
    return List.from(_inMemoryPeople);
  }

  Future<HamdardPerson?> getPerson(String id) async {
    final fs = activeFirestore;
    if (fs != null) {
      try {
        final doc = await fs.collection(AppConfig.hamdardPeopleCollection).doc(id).get();
        if (doc.exists && doc.data() != null) {
          return HamdardPerson.fromJson(doc.data()!, documentId: doc.id);
        }
      } catch (e) {
        debugPrint('Error getting Hamdard person: $e');
      }
    }
    try {
      return _inMemoryPeople.firstWhere((p) => p.id == id);
    } catch (_) {
      return null;
    }
  }

  Future<HamdardPerson> savePerson(
    HamdardPerson person, {
    required String performedBy,
    required String performedByName,
  }) async {
    final fs = activeFirestore;
    final now = DateTime.now();
    final personId = person.id.isNotEmpty ? person.id : const Uuid().v4();
    final isNew = person.id.isEmpty || !_inMemoryPeople.any((p) => p.id == person.id);

    final personToSave = person.copyWith(
      id: personId,
      createdAt: isNew ? (person.createdAt ?? now) : person.createdAt,
      updatedAt: now,
    );

    if (fs != null) {
      await fs
          .collection(AppConfig.hamdardPeopleCollection)
          .doc(personId)
          .set(personToSave.toJson(), SetOptions(merge: true));
    }

    final index = _inMemoryPeople.indexWhere((p) => p.id == personId);
    if (index >= 0) {
      final oldPerson = _inMemoryPeople[index];
      _inMemoryPeople[index] = personToSave;
      await recordAuditLog(HamdardAuditLog(
        id: const Uuid().v4(),
        action: 'edited_person',
        recordType: 'person',
        recordId: personId,
        performedBy: performedBy,
        performedByName: performedByName,
        timestamp: now,
        oldData: oldPerson.toJson(),
        newData: personToSave.toJson(),
        details: 'Edited donor profile: ${personToSave.name}',
      ));
    } else {
      _inMemoryPeople.add(personToSave);
      await recordAuditLog(HamdardAuditLog(
        id: const Uuid().v4(),
        action: 'created_person',
        recordType: 'person',
        recordId: personId,
        performedBy: performedBy,
        performedByName: performedByName,
        timestamp: now,
        oldData: null,
        newData: personToSave.toJson(),
        details: 'Added new Hamdard person: ${personToSave.name}',
      ));
    }

    _peopleStream.add(List.from(_inMemoryPeople));
    return personToSave;
  }

  Future<void> deletePerson(
    String personId, {
    required String performedBy,
    required String performedByName,
  }) async {
    final person = await getPerson(personId);
    final fs = activeFirestore;
    if (fs != null) {
      await fs.collection(AppConfig.hamdardPeopleCollection).doc(personId).delete();
    }
    _inMemoryPeople.removeWhere((p) => p.id == personId);
    _peopleStream.add(List.from(_inMemoryPeople));

    if (person != null) {
      await recordAuditLog(HamdardAuditLog(
        id: const Uuid().v4(),
        action: 'deleted_person',
        recordType: 'person',
        recordId: personId,
        performedBy: performedBy,
        performedByName: performedByName,
        timestamp: DateTime.now(),
        oldData: person.toJson(),
        newData: null,
        details: 'Deleted Hamdard person: ${person.name}',
      ));
    }
  }

  /// Links a Hamdard person to an existing family tree member by UUID.
  /// Preserves the Hamdard person's ID and all historical transactions!
  Future<HamdardPerson> linkPersonToFamilyMember({
    required String personId,
    required String familyMemberId,
    String? profileImageUrl,
    String? bloodGroup,
    String? profession,
    String? gender,
    required String performedBy,
    required String performedByName,
  }) async {
    final person = await getPerson(personId);
    if (person == null) throw StateError('Person not found: $personId');

    final oldData = person.toJson();
    final updated = person.copyWith(
      sourceType: 'family_tree',
      familyMemberId: familyMemberId,
      profileImageUrl: profileImageUrl ?? person.profileImageUrl,
      bloodGroup: bloodGroup ?? person.bloodGroup,
      profession: profession ?? person.profession,
      gender: gender ?? person.gender,
      updatedAt: DateTime.now(),
    );

    final fs = activeFirestore;
    if (fs != null) {
      await fs
          .collection(AppConfig.hamdardPeopleCollection)
          .doc(personId)
          .set(updated.toJson(), SetOptions(merge: true));
    }

    final index = _inMemoryPeople.indexWhere((p) => p.id == personId);
    if (index >= 0) {
      _inMemoryPeople[index] = updated;
    }
    _peopleStream.add(List.from(_inMemoryPeople));

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'linked_family_member',
      recordType: 'person',
      recordId: personId,
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: DateTime.now(),
      oldData: oldData,
      newData: updated.toJson(),
      details: 'Linked ${person.name} to Family Member ID: $familyMemberId',
    ));

    return updated;
  }

  /// Unlinks a Hamdard person from the family tree, reverting to manual source.
  /// Preserves the Hamdard person's ID and all historical transactions!
  Future<HamdardPerson> unlinkPersonFromFamilyMember({
    required String personId,
    required String performedBy,
    required String performedByName,
  }) async {
    final person = await getPerson(personId);
    if (person == null) throw StateError('Person not found: $personId');

    final oldData = person.toJson();
    final updated = person.copyWith(
      sourceType: 'manual',
      clearFamilyMemberId: true,
      updatedAt: DateTime.now(),
    );

    final fs = activeFirestore;
    if (fs != null) {
      await fs
          .collection(AppConfig.hamdardPeopleCollection)
          .doc(personId)
          .set(updated.toJson(), SetOptions(merge: true));
    }

    final index = _inMemoryPeople.indexWhere((p) => p.id == personId);
    if (index >= 0) {
      _inMemoryPeople[index] = updated;
    }
    _peopleStream.add(List.from(_inMemoryPeople));

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'unlinked_family_member',
      recordType: 'person',
      recordId: personId,
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: DateTime.now(),
      oldData: oldData,
      newData: updated.toJson(),
      details: 'Unlinked ${person.name} from Family Tree',
    ));

    return updated;
  }

  // -------------------------------------------------------------
  // DONATION RECORDS
  // -------------------------------------------------------------
  Stream<List<HamdardDonation>> watchDonations() async* {
    yield List.from(_inMemoryDonations);
    final fs = activeFirestore;
    if (fs != null) {
      yield* fs
          .collection(AppConfig.hamdardDonationsCollection)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((d) => HamdardDonation.fromJson(d.data(), documentId: d.id)).toList();
        _inMemoryDonations
          ..clear()
          ..addAll(list);
        return list;
      });
    } else {
      yield* _donationsStream.stream;
    }
  }

  Future<List<HamdardDonation>> getDonations() async {
    final fs = activeFirestore;
    if (fs != null) {
      try {
        final snap = await fs
            .collection(AppConfig.hamdardDonationsCollection)
            .orderBy('date', descending: true)
            .get();
        final list = snap.docs.map((d) => HamdardDonation.fromJson(d.data(), documentId: d.id)).toList();
        _inMemoryDonations
          ..clear()
          ..addAll(list);
        return list;
      } catch (e) {
        debugPrint('Error getting Hamdard donations: $e');
      }
    }
    return List.from(_inMemoryDonations);
  }

  Future<HamdardDonation> addDonation(
    HamdardDonation donation, {
    required String performedBy,
    required String performedByName,
  }) async {
    final fs = activeFirestore;
    final now = DateTime.now();
    final donationId = donation.id.isNotEmpty ? donation.id : const Uuid().v4();

    final toSave = donation.copyWith(
      id: donationId,
      createdAt: now,
      updatedAt: now,
      createdBy: performedBy,
      createdByName: performedByName,
    );

    if (fs != null) {
      await fs
          .collection(AppConfig.hamdardDonationsCollection)
          .doc(donationId)
          .set(toSave.toJson());
    }

    _inMemoryDonations.insert(0, toSave);
    _donationsStream.add(List.from(_inMemoryDonations));

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'created_donation',
      recordType: 'donation',
      recordId: donationId,
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: now,
      oldData: null,
      newData: toSave.toJson(),
      details: 'Recorded donation: ${formatPkr(toSave.amount)} from ${toSave.personNameSnapshot} via ${toSave.paymentMethod.labelEn}',
    ));

    return toSave;
  }

  Future<HamdardDonation> editDonation(
    HamdardDonation newDonation,
    HamdardDonation oldDonation, {
    required String performedBy,
    required String performedByName,
  }) async {
    final fs = activeFirestore;
    final now = DateTime.now();

    final toSave = newDonation.copyWith(
      updatedAt: now,
      updatedBy: performedBy,
      updatedByName: performedByName,
    );

    if (fs != null) {
      await fs
          .collection(AppConfig.hamdardDonationsCollection)
          .doc(toSave.id)
          .set(toSave.toJson(), SetOptions(merge: true));
    }

    final index = _inMemoryDonations.indexWhere((d) => d.id == toSave.id);
    if (index >= 0) {
      _inMemoryDonations[index] = toSave;
    } else {
      _inMemoryDonations.insert(0, toSave);
    }
    _donationsStream.add(List.from(_inMemoryDonations));

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'edited_donation',
      recordType: 'donation',
      recordId: toSave.id,
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: now,
      oldData: oldDonation.toJson(),
      newData: toSave.toJson(),
      details: 'Edited donation: Old ${formatPkr(oldDonation.amount)} (${oldDonation.paymentMethod.labelEn}) -> New ${formatPkr(toSave.amount)} (${toSave.paymentMethod.labelEn})',
    ));

    return toSave;
  }

  Future<void> deleteDonation(
    HamdardDonation donation, {
    required String performedBy,
    required String performedByName,
  }) async {
    final fs = activeFirestore;
    if (fs != null) {
      await fs.collection(AppConfig.hamdardDonationsCollection).doc(donation.id).delete();
    }

    _inMemoryDonations.removeWhere((d) => d.id == donation.id);
    _donationsStream.add(List.from(_inMemoryDonations));

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'deleted_donation',
      recordType: 'donation',
      recordId: donation.id,
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: DateTime.now(),
      oldData: donation.toJson(),
      newData: null,
      details: 'Deleted donation: ${formatPkr(donation.amount)} from ${donation.personNameSnapshot}',
    ));
  }

  // -------------------------------------------------------------
  // SPENDING RECORDS
  // -------------------------------------------------------------
  Stream<List<HamdardSpending>> watchSpending() async* {
    yield List.from(_inMemorySpending);
    final fs = activeFirestore;
    if (fs != null) {
      yield* fs
          .collection(AppConfig.hamdardSpendingCollection)
          .orderBy('date', descending: true)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((d) => HamdardSpending.fromJson(d.data(), documentId: d.id)).toList();
        _inMemorySpending
          ..clear()
          ..addAll(list);
        return list;
      });
    } else {
      yield* _spendingStream.stream;
    }
  }

  Future<List<HamdardSpending>> getSpending() async {
    final fs = activeFirestore;
    if (fs != null) {
      try {
        final snap = await fs
            .collection(AppConfig.hamdardSpendingCollection)
            .orderBy('date', descending: true)
            .get();
        final list = snap.docs.map((d) => HamdardSpending.fromJson(d.data(), documentId: d.id)).toList();
        _inMemorySpending
          ..clear()
          ..addAll(list);
        return list;
      } catch (e) {
        debugPrint('Error getting Hamdard spending: $e');
      }
    }
    return List.from(_inMemorySpending);
  }

  Future<HamdardSpending> addSpending(
    HamdardSpending spending, {
    required String performedBy,
    required String performedByName,
  }) async {
    final fs = activeFirestore;
    final now = DateTime.now();
    final spendingId = spending.id.isNotEmpty ? spending.id : const Uuid().v4();

    final toSave = spending.copyWith(
      id: spendingId,
      createdAt: now,
      updatedAt: now,
      createdBy: performedBy,
      createdByName: performedByName,
    );

    if (fs != null) {
      await fs
          .collection(AppConfig.hamdardSpendingCollection)
          .doc(spendingId)
          .set(toSave.toJson());
    }

    _inMemorySpending.insert(0, toSave);
    _spendingStream.add(List.from(_inMemorySpending));

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'created_spending',
      recordType: 'spending',
      recordId: spendingId,
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: now,
      oldData: null,
      newData: toSave.toJson(),
      details: 'Recorded spending: ${formatPkr(toSave.amount)} for ${toSave.category.labelEn} to ${toSave.recipientName}',
    ));

    return toSave;
  }

  Future<HamdardSpending> editSpending(
    HamdardSpending newSpending,
    HamdardSpending oldSpending, {
    required String performedBy,
    required String performedByName,
  }) async {
    final fs = activeFirestore;
    final now = DateTime.now();

    final toSave = newSpending.copyWith(
      updatedAt: now,
      updatedBy: performedBy,
      updatedByName: performedByName,
    );

    if (fs != null) {
      await fs
          .collection(AppConfig.hamdardSpendingCollection)
          .doc(toSave.id)
          .set(toSave.toJson(), SetOptions(merge: true));
    }

    final index = _inMemorySpending.indexWhere((s) => s.id == toSave.id);
    if (index >= 0) {
      _inMemorySpending[index] = toSave;
    } else {
      _inMemorySpending.insert(0, toSave);
    }
    _spendingStream.add(List.from(_inMemorySpending));

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'edited_spending',
      recordType: 'spending',
      recordId: toSave.id,
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: now,
      oldData: oldSpending.toJson(),
      newData: toSave.toJson(),
      details: 'Edited spending: Old ${formatPkr(oldSpending.amount)} (${oldSpending.category.labelEn}) -> New ${formatPkr(toSave.amount)} (${toSave.category.labelEn})',
    ));

    return toSave;
  }

  Future<void> deleteSpending(
    HamdardSpending spending, {
    required String performedBy,
    required String performedByName,
  }) async {
    final fs = activeFirestore;
    if (fs != null) {
      await fs.collection(AppConfig.hamdardSpendingCollection).doc(spending.id).delete();
    }

    _inMemorySpending.removeWhere((s) => s.id == spending.id);
    _spendingStream.add(List.from(_inMemorySpending));

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'deleted_spending',
      recordType: 'spending',
      recordId: spending.id,
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: DateTime.now(),
      oldData: spending.toJson(),
      newData: null,
      details: 'Deleted spending: ${formatPkr(spending.amount)} for ${spending.category.labelEn} to ${spending.recipientName}',
    ));
  }

  // -------------------------------------------------------------
  // AUDIT LOGGING
  // -------------------------------------------------------------
  Stream<List<HamdardAuditLog>> watchAuditLogs() async* {
    yield List.from(_inMemoryAuditLogs);
    final fs = activeFirestore;
    if (fs != null) {
      yield* fs
          .collection(AppConfig.hamdardAuditLogsCollection)
          .orderBy('timestamp', descending: true)
          .snapshots()
          .map((snap) {
        final list = snap.docs.map((d) => HamdardAuditLog.fromJson(d.data(), documentId: d.id)).toList();
        _inMemoryAuditLogs
          ..clear()
          ..addAll(list);
        return list;
      });
    } else {
      yield* _auditLogsStream.stream;
    }
  }

  Future<void> recordAuditLog(HamdardAuditLog log) async {
    _inMemoryAuditLogs.insert(0, log);
    _auditLogsStream.add(List.from(_inMemoryAuditLogs));

    final fs = activeFirestore;
    if (fs != null) {
      try {
        await fs
            .collection(AppConfig.hamdardAuditLogsCollection)
            .doc(log.id)
            .set(log.toJson());
      } catch (e) {
        debugPrint('Error recording Hamdard audit log: $e');
      }
    }
  }

  // -------------------------------------------------------------
  // JSON IMPORT / EXPORT
  // -------------------------------------------------------------
  /// Imports Hamdard people from JSON.
  /// Validation rules:
  /// - JSON must be a list of maps.
  /// - Each item must contain name and valid phone number.
  /// - Match existing using phone number: if phone already exists, do NOT duplicate.
  /// - Independent: does NOT link to family tree.
  Future<HamdardImportSummary> importPeopleFromJson(
    String jsonString, {
    required String performedBy,
    required String performedByName,
  }) async {
    final existingPeople = await getPeople();
    final existingPhones = <String, HamdardPerson>{};
    for (final p in existingPeople) {
      final normalized = HamdardPerson.normalizePhone(p.phoneNumber);
      if (normalized.isNotEmpty) {
        existingPhones[normalized] = p;
      }
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(jsonString);
    } catch (e) {
      return HamdardImportSummary(
        totalRecords: 0,
        newAdded: 0,
        alreadyExisted: 0,
        invalidRecords: 1,
        errorMessages: ['Invalid JSON format: $e'],
      );
    }

    if (decoded is! List) {
      return const HamdardImportSummary(
        totalRecords: 0,
        newAdded: 0,
        alreadyExisted: 0,
        invalidRecords: 1,
        errorMessages: ['JSON root must be an array of donor objects.'],
      );
    }

    int totalRecords = decoded.length;
    int newAdded = 0;
    int alreadyExisted = 0;
    int invalidRecords = 0;
    final List<String> errors = [];
    final List<HamdardPerson> toInsert = [];

    for (int i = 0; i < decoded.length; i++) {
      final item = decoded[i];
      if (item is! Map) {
        invalidRecords++;
        errors.add('Record #${i + 1} is not a valid JSON object.');
        continue;
      }

      final name = (item['name'] ?? '').toString().trim();
      final fatherName = (item['fatherName'] ?? item['father_name'] ?? '').toString().trim();
      final rawPhone = (item['phoneNumber'] ?? item['phone_number'] ?? item['phone'])?.toString().trim() ?? '';
      final normalizedPhone = HamdardPerson.normalizePhone(rawPhone);

      if (name.isEmpty) {
        invalidRecords++;
        errors.add('Record #${i + 1} is missing a name.');
        continue;
      }

      if (normalizedPhone.isEmpty) {
        invalidRecords++;
        errors.add('Record #${i + 1} ($name) is missing a phone number.');
        continue;
      }

      if (existingPhones.containsKey(normalizedPhone)) {
        alreadyExisted++;
        continue;
      }

      final person = HamdardPerson(
        id: const Uuid().v4(),
        name: name,
        fatherName: fatherName,
        phoneNumber: normalizedPhone,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      existingPhones[normalizedPhone] = person;
      toInsert.add(person);
      newAdded++;
    }

    // Commit to Firestore in batches if live
    final fs = activeFirestore;
    if (fs != null && toInsert.isNotEmpty) {
      const batchSize = 450;
      for (var i = 0; i < toInsert.length; i += batchSize) {
        final chunk = toInsert.sublist(i, (i + batchSize > toInsert.length) ? toInsert.length : i + batchSize);
        final batch = fs.batch();
        for (final p in chunk) {
          final docRef = fs.collection(AppConfig.hamdardPeopleCollection).doc(p.id);
          batch.set(docRef, p.toJson());
        }
        await batch.commit();
      }
    }

    _inMemoryPeople.addAll(toInsert);
    _peopleStream.add(List.from(_inMemoryPeople));

    await recordAuditLog(HamdardAuditLog(
      id: const Uuid().v4(),
      action: 'imported_people_json',
      recordType: 'person',
      recordId: 'batch_import_${DateTime.now().millisecondsSinceEpoch}',
      performedBy: performedBy,
      performedByName: performedByName,
      timestamp: DateTime.now(),
      newData: {
        'total': totalRecords,
        'new_added': newAdded,
        'already_existed': alreadyExisted,
        'invalid': invalidRecords,
      },
      details: 'Super Admin imported $newAdded new people from JSON ($alreadyExisted existing, $invalidRecords invalid).',
    ));

    return HamdardImportSummary(
      totalRecords: totalRecords,
      newAdded: newAdded,
      alreadyExisted: alreadyExisted,
      invalidRecords: invalidRecords,
      errorMessages: errors,
    );
  }

  /// Exports Hamdard data into JSON for safe backup.
  Future<String> exportBackupJson() async {
    final people = await getPeople();
    final donations = await getDonations();
    final spending = await getSpending();
    final openingBalance = await getOpeningBalance();

    final exportData = {
      'exported_at': DateTime.now().toIso8601String(),
      'version': '1.0',
      'opening_balance': openingBalance,
      'people': people.map((p) => p.toJson()).toList(),
      'donations': donations.map((d) => d.toJson()).toList(),
      'spending': spending.map((s) => s.toJson()).toList(),
    };

    return const JsonEncoder.withIndent('  ').convert(exportData);
  }
}
