import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../models/hamdard_donation.dart';
import '../../repositories/hamdard_repository.dart';

class HamdardReceiptScreen extends StatelessWidget {
  final HamdardDonation donation;

  const HamdardReceiptScreen({super.key, required this.donation});

  void _shareReceiptText(BuildContext context) {
    final dateFormat = DateFormat('dd MMMM yyyy, hh:mm a');
    final text = '''
═════════════════════════════
     HAMDARD LAGHARI
  OFFICIAL DONATION RECEIPT
═════════════════════════════
Receipt ID: ${donation.id.substring(0, donation.id.length >= 8 ? 8 : donation.id.length).toUpperCase()}
Date: ${dateFormat.format(donation.date)}

Donor Name: ${donation.personNameSnapshot}
Father's Name: ${donation.fatherNameSnapshot}
Phone: ${donation.phoneNumberSnapshot}

Amount Received: ${HamdardRepository.formatPkr(donation.amount)}
Payment Method: ${donation.paymentMethod.labelEn}
Description: ${donation.description.isNotEmpty ? donation.description : 'Monthly Contribution'}

Issued by: Hamdard Laghari Community Fund
═════════════════════════════
Thank you for your generous contribution to the Laghari Family community!
''';
    Share.share(text, subject: 'Hamdard Laghari Donation Receipt');
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final dateFormat = DateFormat('dd MMMM yyyy');

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'رسید عطیہ' : 'Donation Receipt'),
        actions: [
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: isUrdu ? 'شیئر کریں' : 'Share Receipt',
            onPressed: () => _shareReceiptText(context),
          ),
        ],
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Column(
              children: [
                // Formal Receipt Card
                Container(
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.gold, width: 1.5),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.gold.withValues(alpha: 0.15),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      // Header Crest & Title
                      Container(
                        width: 58,
                        height: 58,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: AppColors.gold, width: 2),
                          color: isDark ? AppColors.darkCard : AppColors.lightCard,
                        ),
                        child: const Icon(Icons.volunteer_activism, color: AppColors.gold, size: 30),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isUrdu ? 'ہمدرد لغاری' : 'HAMDARD LAGHARI',
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.emerald,
                          letterSpacing: 1.1,
                        ),
                      ),
                      Text(
                        isUrdu ? 'سرکاری رسید عطیہ' : 'Official Donation Receipt',
                        style: TextStyle(
                          fontSize: 12,
                          color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(color: AppColors.gold, thickness: 1),
                      const SizedBox(height: 12),

                      // Receipt Metadata Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isUrdu ? 'رسید نمبر' : 'Receipt No',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              Text(
                                '#${donation.id.substring(0, donation.id.length >= 8 ? 8 : donation.id.length).toUpperCase()}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                isUrdu ? 'تاریخ' : 'Date',
                                style: const TextStyle(fontSize: 10, color: Colors.grey),
                              ),
                              Text(
                                dateFormat.format(donation.date),
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),

                      // Big Amount Highlight Box
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: AppColors.emerald.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Text(
                              isUrdu ? 'وصول شدہ رقم' : 'Amount Received',
                              style: const TextStyle(fontSize: 11, color: AppColors.emerald, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              HamdardRepository.formatPkr(donation.amount),
                              style: const TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.bold,
                                color: AppColors.emerald,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Donor Details Table
                      _buildReceiptRow(isUrdu ? 'عطیہ دہندہ' : 'Donor Name', donation.personNameSnapshot, isDark),
                      _buildReceiptRow(isUrdu ? 'والد کا نام' : "Father's Name", donation.fatherNameSnapshot, isDark),
                      _buildReceiptRow(isUrdu ? 'موبائل نمبر' : 'Phone Number', donation.phoneNumberSnapshot, isDark),
                      _buildReceiptRow(isUrdu ? 'طریقہ ادائیگی' : 'Payment Method', donation.paymentMethod.label(isUrdu), isDark),
                      if (donation.description.isNotEmpty)
                        _buildReceiptRow(isUrdu ? 'تفصیل' : 'Description', donation.description, isDark),
                      if (donation.note.isNotEmpty)
                        _buildReceiptRow(isUrdu ? 'نوٹ' : 'Note', donation.note, isDark),

                      const SizedBox(height: 18),
                      const Divider(thickness: 0.8),
                      const SizedBox(height: 8),

                      // Verification Seal Notice
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.verified, color: AppColors.emerald, size: 16),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              isUrdu
                                  ? 'ہمدرد لغاری کمیونٹی فنڈ کی جانب سے تصدیق شدہ'
                                  : 'Verified by Hamdard Laghari Community Fund',
                              style: TextStyle(
                                fontSize: 10.5,
                                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.share),
                        label: Text(isUrdu ? 'رسید شیئر کریں' : 'Share Receipt'),
                        onPressed: () => _shareReceiptText(context),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        icon: const Icon(Icons.check),
                        label: Text(isUrdu ? 'مکمل' : 'Done'),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReceiptRow(String label, String value, bool isDark) {
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
