import 'dart:convert';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/models/validation_report.dart';
import '../../../../core/utils/json_validator.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../../family_tree/repositories/family_repository.dart';

class JsonExportImportScreen extends ConsumerStatefulWidget {
  const JsonExportImportScreen({super.key});

  @override
  ConsumerState<JsonExportImportScreen> createState() =>
      _JsonExportImportScreenState();
}

class _JsonExportImportScreenState
    extends ConsumerState<JsonExportImportScreen> {
  bool _isProcessing = false;

  Future<void> _handleExport() async {
    setState(() => _isProcessing = true);
    try {
      final jsonStr = await ref.read(familyRepositoryProvider).exportToJson();

      if (mounted) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Export Family Tree JSON'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Current Firestore genealogy database has been serialized to JSON.',
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  height: 140,
                  child: SingleChildScrollView(
                    child: Text(
                      jsonStr,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: jsonStr));
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('JSON copied to clipboard!')),
                  );
                },
                icon: const Icon(Icons.copy, size: 16),
                label: const Text('Copy JSON'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                  Share.share(
                    jsonStr,
                    subject: 'laghari_family_tree_backup.json',
                  );
                },
                icon: const Icon(Icons.share, size: 16),
                label: const Text('Share / Save File'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Export failed: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleImport() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
        withData: true,
      );

      if (result == null || result.files.single.bytes == null) return;

      setState(() => _isProcessing = true);
      final jsonBytes = result.files.single.bytes!;
      final jsonString = utf8.decode(jsonBytes);
      final dynamic decoded = jsonDecode(jsonString);

      final currentMembers = await ref.read(familyRepositoryProvider).getAllMembers();
      final existingIds = currentMembers.map((m) => m.id).toSet();

      final report = JsonValidator.validate(decoded, existingMemberIds: existingIds);

      if (!mounted) return;

      // Show summary dialog matching Requirement 8
      _showImportSummaryDialog(report, jsonString);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to read JSON: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _showImportSummaryDialog(ValidationReport report, String rawJson) {
    final loc = AppLocalizations.of(context);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Family Tree Import Summary'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildStatTile('Members found:', '${report.totalFound}'),
              _buildStatTile('New members:', '${report.newMembersCount}', color: AppColors.emeraldLight),
              _buildStatTile('Existing members:', '${report.existingMembersCount}', color: AppColors.goldLight),
              _buildStatTile('Invalid records:', '${report.errors.length + report.invalidRecordsCount}',
                  color: (report.errors.isNotEmpty || report.invalidRecordsCount > 0)
                      ? AppColors.danger
                      : AppColors.textLightSecondary),
              const SizedBox(height: 16),
              if (report.errors.isNotEmpty) ...[
                const Text(
                  'Validation Errors:',
                  style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.danger, fontSize: 13),
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.danger.withValues(alpha: 0.5)),
                  ),
                  height: 100,
                  child: ListView.builder(
                    itemCount: report.errors.length,
                    itemBuilder: (_, idx) => Text(
                      '• ${report.errors[idx].toString()}',
                      style: const TextStyle(fontSize: 11, color: AppColors.danger),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              Text(
                report.isValid
                    ? 'All records validated successfully. Do you want to merge this data into Cloud Firestore?'
                    : 'The file contains critical errors. Please resolve them before importing into the database.',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: report.isValid ? AppColors.emerald : Colors.grey,
            ),
            onPressed: report.isValid
                ? () async {
                    Navigator.pop(ctx);
                    setState(() => _isProcessing = true);
                    try {
                      await ref.read(familyRepositoryProvider).importFromJson(rawJson);
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            backgroundColor: AppColors.emerald,
                            content: Text('Successfully imported and updated Firestore family tree!'),
                          ),
                        );
                      }
                    } catch (e) {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Import error: $e')),
                        );
                      }
                    } finally {
                      if (mounted) setState(() => _isProcessing = false);
                    }
                  }
                : null,
            child: const Text('Import'),
          ),
        ],
      ),
    );
  }

  Widget _buildStatTile(String label, String value, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: AppColors.textLightSecondary)),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color ?? AppColors.textLightPrimary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser?.isSuperAdmin != true) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.translate('export_data'))),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.gpp_bad, size: 64, color: AppColors.danger),
              const SizedBox(height: 16),
              Text(
                loc.isUrdu
                    ? 'یہ سیکشن صرف سپر ایڈمن کے لیے مخصوص ہے۔'
                    : 'This section is restricted to Super Admin only.',
                style: const TextStyle(fontSize: 16, color: AppColors.textLightSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('export_data')),
      ),
      body: _isProcessing
          ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
          : Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Export Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cloud_download, color: AppColors.emerald, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                loc.translate('export_data'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.translate('export_json_desc'),
                            style: const TextStyle(color: AppColors.textLightSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton.icon(
                            onPressed: _handleExport,
                            icon: const Icon(Icons.download, size: 18),
                            label: Text(loc.translate('export_data')),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Import Card
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.cloud_upload, color: AppColors.gold, size: 28),
                              const SizedBox(width: 12),
                              Text(
                                loc.translate('import_data'),
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc.translate('import_json_desc'),
                            style: const TextStyle(color: AppColors.textLightSecondary, fontSize: 13),
                          ),
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: _handleImport,
                            icon: const Icon(Icons.file_upload, size: 18),
                            label: Text(loc.translate('import_data')),
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
