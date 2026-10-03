import 'package:cloud_firestore/cloud_firestore.dart';
import 'hamdard_payment_method.dart';

class HamdardDonation {
  final String id;
  final String personId;
  final String personNameSnapshot;
  final String fatherNameSnapshot;
  final String phoneNumberSnapshot;
  final int amount; // Stored as integer PKR
  final HamdardPaymentMethod paymentMethod;
  final DateTime date;
  final String description;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String createdByName;
  final String? updatedBy;
  final String? updatedByName;

  const HamdardDonation({
    required this.id,
    required this.personId,
    required this.personNameSnapshot,
    required this.fatherNameSnapshot,
    required this.phoneNumberSnapshot,
    required this.amount,
    required this.paymentMethod,
    required this.date,
    this.description = '',
    this.note = '',
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.createdByName = '',
    this.updatedBy,
    this.updatedByName,
  });

  factory HamdardDonation.fromJson(Map<String, dynamic> json, {String? documentId}) {
    DateTime parseDate(dynamic val, [DateTime? fallback]) {
      if (val == null) return fallback ?? DateTime.now();
      if (val is DateTime) return val;
      if (val is Timestamp) return val.toDate();
      if (val is String) {
        final parsed = DateTime.tryParse(val);
        if (parsed != null) return parsed;
      }
      try {
        final dynamic t = val;
        if (t.toDate != null) return t.toDate() as DateTime;
      } catch (_) {}
      return fallback ?? DateTime.now();
    }

    final rawAmount = json['amount'];
    int parsedAmount = 0;
    if (rawAmount is num) {
      parsedAmount = rawAmount.toInt();
    } else if (rawAmount is String) {
      parsedAmount = int.tryParse(rawAmount.replaceAll(',', '').trim()) ?? 0;
    }

    return HamdardDonation(
      id: documentId ?? (json['id'] ?? '').toString(),
      personId: (json['personId'] ?? json['person_id'] ?? '').toString(),
      personNameSnapshot: (json['personNameSnapshot'] ?? json['person_name_snapshot'] ?? '').toString(),
      fatherNameSnapshot: (json['fatherNameSnapshot'] ?? json['father_name_snapshot'] ?? '').toString(),
      phoneNumberSnapshot: (json['phoneNumberSnapshot'] ?? json['phone_number_snapshot'] ?? '').toString(),
      amount: parsedAmount,
      paymentMethod: HamdardPaymentMethod.fromString(json['paymentMethod'] ?? json['payment_method']),
      date: parseDate(json['date']),
      description: (json['description'] ?? '').toString(),
      note: (json['note'] ?? '').toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at'], null),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at'], null),
      createdBy: (json['createdBy'] ?? json['created_by'] ?? '').toString(),
      createdByName: (json['createdByName'] ?? json['created_by_name'] ?? '').toString(),
      updatedBy: (json['updatedBy'] ?? json['updated_by'])?.toString(),
      updatedByName: (json['updatedByName'] ?? json['updated_by_name'])?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'person_id': personId,
      'personId': personId,
      'person_name_snapshot': personNameSnapshot,
      'personNameSnapshot': personNameSnapshot,
      'father_name_snapshot': fatherNameSnapshot,
      'fatherNameSnapshot': fatherNameSnapshot,
      'phone_number_snapshot': phoneNumberSnapshot,
      'phoneNumberSnapshot': phoneNumberSnapshot,
      'amount': amount,
      'payment_method': paymentMethod.value,
      'paymentMethod': paymentMethod.value,
      'date': Timestamp.fromDate(date),
      'description': description,
      'note': note,
      'created_at': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
      'updated_at': updatedAt != null ? Timestamp.fromDate(updatedAt!) : FieldValue.serverTimestamp(),
      'created_by': createdBy,
      'created_by_name': createdByName,
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedByName != null) 'updated_by_name': updatedByName,
    };
  }

  HamdardDonation copyWith({
    String? id,
    String? personId,
    String? personNameSnapshot,
    String? fatherNameSnapshot,
    String? phoneNumberSnapshot,
    int? amount,
    HamdardPaymentMethod? paymentMethod,
    DateTime? date,
    String? description,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? createdByName,
    String? updatedBy,
    String? updatedByName,
  }) {
    return HamdardDonation(
      id: id ?? this.id,
      personId: personId ?? this.personId,
      personNameSnapshot: personNameSnapshot ?? this.personNameSnapshot,
      fatherNameSnapshot: fatherNameSnapshot ?? this.fatherNameSnapshot,
      phoneNumberSnapshot: phoneNumberSnapshot ?? this.phoneNumberSnapshot,
      amount: amount ?? this.amount,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      date: date ?? this.date,
      description: description ?? this.description,
      note: note ?? this.note,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      createdBy: createdBy ?? this.createdBy,
      createdByName: createdByName ?? this.createdByName,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedByName: updatedByName ?? this.updatedByName,
    );
  }
}
