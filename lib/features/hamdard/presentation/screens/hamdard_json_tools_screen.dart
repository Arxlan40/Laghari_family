import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';

class HamdardJsonToolsScreen extends ConsumerStatefulWidget {
  const HamdardJsonToolsScreen({super.key});

  @override
  ConsumerState<HamdardJsonToolsScreen> createState() => _HamdardJsonToolsScreenState();
}

class _HamdardJsonToolsScreenState extends ConsumerState<HamdardJsonToolsScreen> {
  final _jsonInputCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _jsonInputCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickJsonFile() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );
      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final text = await file.readAsString();
        setState(() => _jsonInputCtrl.text = text);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error picking file: $e')),
        );
      }
    }
  }

  Future<void> _executeImport() async {
    final text = _jsonInputCtrl.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please paste JSON or pick a JSON file first.')),
      );
      return;
    }

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() => _isLoading = true);

    final summary = await ref.read(hamdardRepositoryProvider).importPeopleFromJson(
      text,
      performedBy: currentUser.uid,
      performedByName: currentUser.name,
    );

    if (!mounted) return;
    setState(() {
      _isLoading = false;
    });

    _showSummaryDialog(summary);
  }

  void _showSummaryDialog(HamdardImportSummary summary) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(
              summary.newAdded > 0 ? Icons.check_circle : Icons.info_outline,
              color: summary.newAdded > 0 ? AppColors.emerald : AppColors.gold,
            ),
            const SizedBox(width: 10),
            Text(loc.isUrdu ? 'درآمدگی مکمل ہو گئی' : 'Import Complete'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildStatRow('Total records', '${summary.totalRecords}'),
            _buildStatRow('New people added', '${summary.newAdded}', color: AppColors.emerald),
            _buildStatRow('Already existed', '${summary.alreadyExisted}', color: AppColors.gold),
            _buildStatRow('Invalid records', '${summary.invalidRecords}', color: AppColors.danger),
            if (summary.errorMessages.isNotEmpty) ...[
              const SizedBox(height: 12),
              const Text('Errors / Notes:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11)),
              const SizedBox(height: 4),
              ...summary.errorMessages.take(4).map(
                    (msg) => Text('• $msg', style: const TextStyle(fontSize: 10, color: AppColors.danger)),
                  ),
            ],
          ],
        ),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('ok')),
          ),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13)),
          Text(
            value,
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color),
          ),
        ],
      ),
    );
  }

  Future<void> _exportBackup() async {
    setState(() => _isLoading = true);
    try {
      final jsonString = await ref.read(hamdardRepositoryProvider).exportBackupJson();
      final timestamp = DateFormat('yyyyMMdd_HHmmss').format(DateTime.now());
      final filename = 'hamdard_laghari_backup_$timestamp.json';

      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/$filename');
      await file.writeAsString(jsonString);

      await Share.shareXFiles(
        [XFile(file.path)],
        text: 'Hamdard Laghari Complete Data Backup ($filename)',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: AppColors.danger, content: Text('Error exporting backup: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'بیک اپ اور درآمدگی' : 'JSON Backup & Import'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Export Backup Card
            Card(
              color: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.download_for_offline, color: AppColors.gold, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          isUrdu ? 'ہمدرد ڈیٹا کا بیک اپ حاصل کریں' : 'Export Full Hamdard Backup',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUrdu
                          ? 'تمام ہمدرد افراد، عطیات، اور اخراجات کا جامع JSON بیک اپ فائل محفوظ کریں۔'
                          : 'Download full Hamdard donors registry and transaction history safely without sensitive authentication tokens.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.gold,
                        foregroundColor: Colors.black87,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.file_download),
                      label: Text(isUrdu ? 'JSON فائل ڈاؤن لوڈ کریں' : 'Export JSON Backup'),
                      onPressed: _isLoading ? null : _exportBackup,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Import Donors JSON Card
            Card(
              color: isDark ? AppColors.darkSurface : Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.upload_file, color: AppColors.emerald, size: 24),
                        const SizedBox(width: 10),
                        Text(
                          isUrdu ? 'ہمدرد افراد کی JSON سے درآمدگی' : 'Import Donors From JSON',
                          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      isUrdu
                          ? 'موبائل نمبر کی بنیاد پر ڈپلیکیٹ افراد کو خود بخود چیک کیا جائے گا۔ نیا شخص شامل ہو گا اور پہلے سے موجود شخص دوبارہ نہیں بنے گا۔'
                          : 'Automatically validates phone numbers and checks duplicates. Existing phone numbers will not be duplicated. No link to family tree.',
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          icon: const Icon(Icons.folder_open, size: 18),
                          label: Text(isUrdu ? 'فائل منتخب کریں' : 'Pick File'),
                          onPressed: _pickJsonFile,
                        ),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () {
                            _jsonInputCtrl.text = '''[
  {
    "name": "Muhammad Khan",
    "fatherName": "Ahmed Khan",
    "phoneNumber": "03001234567"
  },
  {
    "name": "Ali Khan",
    "fatherName": "Umar Khan",
    "phoneNumber": "03111234567"
  }
]''';
                          },
                          child: const Text('Insert Sample JSON'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _jsonInputCtrl,
                      maxLines: 8,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Paste JSON array here...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.emerald,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.cloud_upload),
                      label: Text(isUrdu ? 'درآمدگی شروع کریں' : 'Import Donors'),
                      onPressed: _isLoading ? null : _executeImport,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
