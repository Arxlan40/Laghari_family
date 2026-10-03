import 'dart:io';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/hamdard_donation.dart';
import '../models/hamdard_spending.dart';

class HamdardCsvService {
  static final DateFormat _dateFormat = DateFormat('yyyy-MM-dd HH:mm');

  /// Escapes fields in compliance with RFC 4180
  static String _escapeCsv(dynamic value) {
    if (value == null) return '';
    final str = value.toString();
    if (str.contains(',') || str.contains('"') || str.contains('\n') || str.contains('\r')) {
      return '"${str.replaceAll('"', '""')}"';
    }
    return str;
  }

  /// Generates CSV content combining donations and spending records sorted chronologically
  static String generateCsv({
    required List<HamdardDonation> donations,
    required List<HamdardSpending> spending,
  }) {
    final buffer = StringBuffer();

    // CSV Header Row
    final headers = [
      'Date',
      'Type',
      'Person/Recipient',
      'Father Name',
      'Phone Number',
      'Amount (PKR)',
      'Payment Method',
      'Category',
      'Description',
      'Note',
      'Created By',
    ];
    buffer.writeln(headers.map(_escapeCsv).join(','));

    // Combine and sort by date descending
    final List<Map<String, dynamic>> rows = [];

    for (final d in donations) {
      rows.add({
        'date': d.date,
        'type': 'Donation',
        'person': d.personNameSnapshot,
        'father': d.fatherNameSnapshot,
        'phone': d.phoneNumberSnapshot,
        'amount': d.amount,
        'payment': d.paymentMethod.labelEn,
        'category': 'Donation Collection',
        'desc': d.description,
        'note': d.note,
        'createdBy': d.createdByName.isNotEmpty ? d.createdByName : d.createdBy,
      });
    }

    for (final s in spending) {
      rows.add({
        'date': s.date,
        'type': 'Spending',
        'person': s.recipientName,
        'father': s.recipientFatherName,
        'phone': s.recipientPhoneNumber,
        'amount': s.amount,
        'payment': s.paymentMethod.labelEn,
        'category': s.category.labelEn,
        'desc': s.description,
        'note': s.note,
        'createdBy': s.createdByName.isNotEmpty ? s.createdByName : s.createdBy,
      });
    }

    rows.sort((a, b) => (b['date'] as DateTime).compareTo(a['date'] as DateTime));

    for (final row in rows) {
      final line = [
        _dateFormat.format(row['date'] as DateTime),
        row['type'],
        row['person'],
        row['father'],
        row['phone'],
        row['amount'],
        row['payment'],
        row['category'],
        row['desc'],
        row['note'],
        row['createdBy'],
      ];
      buffer.writeln(line.map(_escapeCsv).join(','));
    }

    return buffer.toString();
  }

  /// Exports CSV to device storage and triggers share sheet
  static Future<File> exportAndShareCsv({
    required List<HamdardDonation> donations,
    required List<HamdardSpending> spending,
    String? filenamePrefix,
  }) async {
    final csvContent = generateCsv(donations: donations, spending: spending);
    final prefix = filenamePrefix ?? 'hamdard_financial_report';
    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = '${prefix}_$timestamp.csv';

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(csvContent);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Hamdard Laghari Financial Report ($filename)',
    );

    return file;
  }
}
