import 'package:cloud_firestore/cloud_firestore.dart';
import 'hamdard_payment_method.dart';
import 'hamdard_spending_category.dart';

class HamdardSpending {
  final String id;
  final String recipientName;
  final String recipientFatherName;
  final String recipientPhoneNumber;
  final int amount; // Stored as integer PKR
  final DateTime date;
  final HamdardPaymentMethod paymentMethod;
  final HamdardSpendingCategory category;
  final String description;
  final String note;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String createdBy;
  final String createdByName;
  final String? updatedBy;
  final String? updatedByName;

  const HamdardSpending({
    required this.id,
    required this.recipientName,
    required this.recipientFatherName,
    required this.recipientPhoneNumber,
    required this.amount,
    required this.date,
    required this.paymentMethod,
    required this.category,
    this.description = '',
    this.note = '',
    this.createdAt,
    this.updatedAt,
    this.createdBy = '',
    this.createdByName = '',
    this.updatedBy,
    this.updatedByName,
  });

  factory HamdardSpending.fromJson(Map<String, dynamic> json, {String? documentId}) {
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

    return HamdardSpending(
      id: documentId ?? (json['id'] ?? '').toString(),
      recipientName: (json['recipientName'] ?? json['recipient_name'] ?? '').toString(),
      recipientFatherName: (json['recipientFatherName'] ?? json['recipient_father_name'] ?? '').toString(),
      recipientPhoneNumber: (json['recipientPhoneNumber'] ?? json['recipient_phone_number'] ?? '').toString(),
      amount: parsedAmount,
      date: parseDate(json['date']),
      paymentMethod: HamdardPaymentMethod.fromString(json['paymentMethod'] ?? json['payment_method']),
      category: HamdardSpendingCategory.fromString(json['category']),
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
      'recipient_name': recipientName,
      'recipientName': recipientName,
      'recipient_father_name': recipientFatherName,
      'recipientFatherName': recipientFatherName,
      'recipient_phone_number': recipientPhoneNumber,
      'recipientPhoneNumber': recipientPhoneNumber,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'payment_method': paymentMethod.value,
      'paymentMethod': paymentMethod.value,
      'category': category.value,
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

  HamdardSpending copyWith({
    String? id,
    String? recipientName,
    String? recipientFatherName,
    String? recipientPhoneNumber,
    int? amount,
    DateTime? date,
    HamdardPaymentMethod? paymentMethod,
    HamdardSpendingCategory? category,
    String? description,
    String? note,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? createdBy,
    String? createdByName,
    String? updatedBy,
    String? updatedByName,
  }) {
    return HamdardSpending(
      id: id ?? this.id,
      recipientName: recipientName ?? this.recipientName,
      recipientFatherName: recipientFatherName ?? this.recipientFatherName,
      recipientPhoneNumber: recipientPhoneNumber ?? this.recipientPhoneNumber,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      paymentMethod: paymentMethod ?? this.paymentMethod,
      category: category ?? this.category,
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
