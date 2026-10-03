import 'dart:io';
import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import '../models/hamdard_donation.dart';
import '../models/hamdard_financial_summary.dart';
import '../models/hamdard_payment_method.dart';
import '../models/hamdard_spending.dart';
import '../models/hamdard_spending_category.dart';
import '../providers/hamdard_providers.dart';
import '../repositories/hamdard_repository.dart';

class HamdardPdfService {
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  /// Builds a high-quality multi-page PDF document
  static Future<Uint8List> generatePdfBytes({
    required String periodTitle,
    required HamdardFinancialSummary summary,
    required List<HamdardDonation> donations,
    required List<HamdardSpending> spending,
    required List<HamdardPersonStats> donorStats,
  }) async {
    final pdf = pw.Document();

    final emeraldColor = PdfColor.fromHex('#047857');
    final goldColor = PdfColor.fromHex('#B45309');
    final darkHeader = PdfColor.fromHex('#1E293B');
    final lightGrey = PdfColor.fromHex('#F1F5F9');

    // Page 1: Title, Executive Summary, Payment Breakdown, Category Breakdown
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            crossAxisAlignment: pw.CrossAxisAlignment.center,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'HAMDARD LAGHARI',
                    style: pw.TextStyle(
                      fontSize: 22,
                      fontWeight: pw.FontWeight.bold,
                      color: emeraldColor,
                    ),
                  ),
                  pw.Text(
                    'Donation & Spending Financial Report',
                    style: pw.TextStyle(
                      fontSize: 13,
                      fontWeight: pw.FontWeight.bold,
                      color: darkHeader,
                    ),
                  ),
                  pw.SizedBox(height: 3),
                  pw.Text(
                    'Laghari Family Community Fund | All amounts in PKR',
                    style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.end,
                children: [
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: pw.BoxDecoration(
                      color: emeraldColor,
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      periodTitle.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.white,
                      ),
                    ),
                  ),
                  pw.SizedBox(height: 4),
                  pw.Text(
                    'Generated: ${DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          ),
          pw.Divider(thickness: 1.5, color: goldColor),
          pw.SizedBox(height: 12),

          // Financial Executive Summary Cards
          pw.Text('FINANCIAL SUMMARY', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: darkHeader)),
          pw.SizedBox(height: 8),
          pw.Row(
            children: [
              _buildMetricBox('Total Collection', HamdardRepository.formatPkr(summary.totalDonations), emeraldColor),
              pw.SizedBox(width: 10),
              _buildMetricBox('Total Spending', HamdardRepository.formatPkr(summary.totalSpending), PdfColor.fromHex('#EF4444')),
              pw.SizedBox(width: 10),
              _buildMetricBox('Net Balance', HamdardRepository.formatPkr(summary.currentBalance), goldColor),
            ],
          ),
          pw.SizedBox(height: 8),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: pw.BoxDecoration(
              color: lightGrey,
              borderRadius: pw.BorderRadius.circular(6),
            ),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Opening Balance: ${HamdardRepository.formatPkr(summary.openingBalance)}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Total Donors: ${summary.totalDonors}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('Donated This Month: ${summary.donorsDonatedThisMonth}', style: const pw.TextStyle(fontSize: 9)),
                pw.Text('No Donation This Month: ${summary.donorsNotDonatedThisMonth}', style: const pw.TextStyle(fontSize: 9)),
              ],
            ),
          ),
          pw.SizedBox(height: 18),

          // Payment Method Summary & Spending Categories Summary side-by-side
          pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Payment Methods Table
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('PAYMENT METHOD SUMMARY', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkHeader)),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: lightGrey),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Method', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Donations', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Spending', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          ],
                        ),
                        for (final method in HamdardPaymentMethod.values)
                          pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(method.labelEn, style: const pw.TextStyle(fontSize: 8.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(HamdardRepository.formatPkr(summary.paymentMethodDonations[method] ?? 0), style: const pw.TextStyle(fontSize: 8.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(HamdardRepository.formatPkr(summary.paymentMethodSpending[method] ?? 0), style: const pw.TextStyle(fontSize: 8.5))),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(width: 14),
              // Spending Categories Table
              pw.Expanded(
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text('SPENDING BY CATEGORY', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkHeader)),
                    pw.SizedBox(height: 6),
                    pw.Table(
                      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
                      children: [
                        pw.TableRow(
                          decoration: pw.BoxDecoration(color: lightGrey),
                          children: [
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Category', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('Amount', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                            pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text('% Share', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          ],
                        ),
                        for (final cat in HamdardSpendingCategory.values)
                          pw.TableRow(
                            children: [
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(cat.labelEn, style: const pw.TextStyle(fontSize: 8.5))),
                              pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(HamdardRepository.formatPkr(summary.categorySpending[cat] ?? 0), style: const pw.TextStyle(fontSize: 8.5))),
                              pw.Padding(
                                padding: const pw.EdgeInsets.all(5),
                                child: pw.Text(
                                  summary.totalSpending > 0
                                      ? '${(((summary.categorySpending[cat] ?? 0) / summary.totalSpending) * 100).toStringAsFixed(1)}%'
                                      : '0.0%',
                                  style: const pw.TextStyle(fontSize: 8.5),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 18),

          // Spending Records Section
          pw.Text('DETAILED SPENDING RECORDS (${spending.length})', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkHeader)),
          pw.SizedBox(height: 6),
          if (spending.isEmpty)
            pw.Text('No spending recorded for this period.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightGrey),
                  children: [
                    _cellHeader('Date'),
                    _cellHeader('Recipient'),
                    _cellHeader('Father Name'),
                    _cellHeader('Phone'),
                    _cellHeader('Category'),
                    _cellHeader('Method'),
                    _cellHeader('Amount'),
                  ],
                ),
                for (final s in spending)
                  pw.TableRow(
                    children: [
                      _cellText(_dateFormat.format(s.date)),
                      _cellText(s.recipientName),
                      _cellText(s.recipientFatherName),
                      _cellText(s.recipientPhoneNumber),
                      _cellText(s.category.labelEn),
                      _cellText(s.paymentMethod.labelEn),
                      _cellText(HamdardRepository.formatPkr(s.amount), alignRight: true),
                    ],
                  ),
              ],
            ),
          pw.SizedBox(height: 18),

          // Donation Records Section
          pw.Text('DONATION TRANSACTIONS (${donations.length})', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkHeader)),
          pw.SizedBox(height: 6),
          if (donations.isEmpty)
            pw.Text('No donations recorded for this period.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightGrey),
                  children: [
                    _cellHeader('Date'),
                    _cellHeader('Donor Name'),
                    _cellHeader('Father Name'),
                    _cellHeader('Phone'),
                    _cellHeader('Method'),
                    _cellHeader('Amount'),
                  ],
                ),
                for (final d in donations)
                  pw.TableRow(
                    children: [
                      _cellText(_dateFormat.format(d.date)),
                      _cellText(d.personNameSnapshot),
                      _cellText(d.fatherNameSnapshot),
                      _cellText(d.phoneNumberSnapshot),
                      _cellText(d.paymentMethod.labelEn),
                      _cellText(HamdardRepository.formatPkr(d.amount), alignRight: true),
                    ],
                  ),
              ],
            ),
          pw.SizedBox(height: 18),

          // Donor Participation Summary
          pw.Text('DONOR PARTICIPATION SUMMARY (${donorStats.length})', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold, color: darkHeader)),
          pw.SizedBox(height: 6),
          if (donorStats.isEmpty)
            pw.Text('No donors in registry.', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600))
          else
            pw.Table(
              border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: lightGrey),
                  children: [
                    _cellHeader('Donor Name'),
                    _cellHeader('Father Name'),
                    _cellHeader('Phone'),
                    _cellHeader('This Month'),
                    _cellHeader('This Year'),
                    _cellHeader('All-Time Total'),
                  ],
                ),
                for (final stat in donorStats)
                  pw.TableRow(
                    children: [
                      _cellText(stat.person.name),
                      _cellText(stat.person.fatherName),
                      _cellText(stat.person.phoneNumber),
                      _cellText(HamdardRepository.formatPkr(stat.thisMonthTotal), alignRight: true),
                      _cellText(HamdardRepository.formatPkr(stat.thisYearTotal), alignRight: true),
                      _cellText(HamdardRepository.formatPkr(stat.allTimeTotal), alignRight: true),
                    ],
                  ),
              ],
            ),
        ],
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildMetricBox(String title, String value, PdfColor color) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: color, width: 1.2),
          borderRadius: pw.BorderRadius.circular(6),
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(title, style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  static pw.Widget _cellHeader(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(text, style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold)),
    );
  }

  static pw.Widget _cellText(String text, {bool alignRight = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(5),
      child: pw.Text(
        text,
        textAlign: alignRight ? pw.TextAlign.right : pw.TextAlign.left,
        style: const pw.TextStyle(fontSize: 8),
      ),
    );
  }

  /// Exports PDF to file and presents standard share sheet
  static Future<File> exportAndSharePdf({
    required String periodTitle,
    required HamdardFinancialSummary summary,
    required List<HamdardDonation> donations,
    required List<HamdardSpending> spending,
    required List<HamdardPersonStats> donorStats,
  }) async {
    final pdfBytes = await generatePdfBytes(
      periodTitle: periodTitle,
      summary: summary,
      donations: donations,
      spending: spending,
      donorStats: donorStats,
    );

    final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
    final filename = 'hamdard_report_$timestamp.pdf';
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsBytes(pdfBytes);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'Hamdard Laghari Financial Report ($filename)',
    );

    return file;
  }
}
