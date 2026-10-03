import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../models/hamdard_audit_log.dart';
import '../../providers/hamdard_providers.dart';

class HamdardAuditLogScreen extends ConsumerStatefulWidget {
  const HamdardAuditLogScreen({super.key});

  @override
  ConsumerState<HamdardAuditLogScreen> createState() => _HamdardAuditLogScreenState();
}

class _HamdardAuditLogScreenState extends ConsumerState<HamdardAuditLogScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');
  String _filterType = 'all';

  /// Recursively sanitizes data maps/lists for display:
  /// - Converts Timestamp and DateTime to ISO strings
  /// - Omits massive Base64 strings to prevent canvas freeze/crash
  /// - Handles null and complex nested structures safely
  static dynamic _sanitizeForDisplay(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value.toIso8601String();
    if (value is Timestamp) return value.toDate().toIso8601String();
    if (value is Map) {
      final sanitized = <String, dynamic>{};
      for (final entry in value.entries) {
        sanitized[entry.key.toString()] = _sanitizeForDisplay(entry.value);
      }
      return sanitized;
    }
    if (value is List) {
      return value.map(_sanitizeForDisplay).toList();
    }
    if (value is String) {
      // Omit large base64 image data (e.g. data:image/... or huge encoded strings)
      if (value.startsWith('data:image') ||
          (value.length > 250 && !value.contains(' ') && RegExp(r'^[A-Za-z0-9+/=]+$').hasMatch(value))) {
        return '[Base64 image data omitted - ${value.length} bytes]';
      }
      return value;
    }
    return value.toString();
  }

  static String _formatJsonSafely(Map<String, dynamic>? data) {
    if (data == null || data.isEmpty) return 'No data recorded';
    try {
      final sanitized = _sanitizeForDisplay(data);
      const encoder = JsonEncoder.withIndent('  ');
      return encoder.convert(sanitized);
    } catch (e) {
      try {
        final buffer = StringBuffer();
        data.forEach((k, v) {
          final cleanVal = (v is String && v.length > 150) ? '[Data omitted]' : v.toString();
          buffer.writeln('$k: $cleanVal');
        });
        return buffer.toString();
      } catch (_) {
        return 'Data preview unavailable';
      }
    }
  }

  void _showLogDetailsDialog(HamdardAuditLog log) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final actionTitle = log.action.isNotEmpty
        ? log.action.replaceAll('_', ' ').toUpperCase()
        : 'FINANCIAL ACTION';

    final performedByText = log.performedByName.isNotEmpty
        ? (log.performedBy.isNotEmpty ? '${log.performedByName} (${log.performedBy})' : log.performedByName)
        : (log.performedBy.isNotEmpty ? log.performedBy : 'Unknown');

    final recordTypeText = log.recordType.isNotEmpty ? log.recordType.toUpperCase() : 'NOT SPECIFIED';
    final recordIdText = log.recordId.isNotEmpty ? log.recordId : 'Record ID not available';

    final oldDataFormatted = _formatJsonSafely(log.oldData);
    final newDataFormatted = _formatJsonSafely(log.newData);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            const Icon(Icons.history_edu, color: AppColors.gold, size: 24),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                actionTitle,
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildDetailRow('Timestamp', _dateFormat.format(log.timestamp)),
                _buildDetailRow('Performed By', performedByText),
                _buildDetailRow('Record Type', recordTypeText),
                _buildDetailRow('Record ID', recordIdText),
                if (log.details != null && log.details!.isNotEmpty)
                  _buildDetailRow('Details', log.details!),
                const Divider(height: 20),

                // Previous Data
                if (log.oldData != null && log.oldData!.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'PREVIOUS DATA (OLD):',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.danger),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        tooltip: 'Copy Previous Data',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: oldDataFormatted));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Previous data copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
                    ),
                    child: SelectableText(
                      oldDataFormatted,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // New / Updated Data
                if (log.newData != null && log.newData!.isNotEmpty) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'NEW / UPDATED DATA:',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.emerald),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy, size: 14),
                        tooltip: 'Copy New Data',
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: newDataFormatted));
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Updated data copied to clipboard')),
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.emerald.withValues(alpha: 0.3)),
                    ),
                    child: SelectableText(
                      newDataFormatted,
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10.5),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('ok')),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isUrdu = loc.isUrdu;
    final auditLogsState = ref.watch(hamdardAuditLogsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'مالیاتی آڈٹ ٹریل' : 'Financial Audit Trail'),
      ),
      body: Column(
        children: [
          // Filter Chips (All, Donation, Spending, Person, Role, Settings)
          Padding(
            padding: const EdgeInsets.all(16),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildTypeChip('all', isUrdu ? 'تمام لاگز' : 'All Logs'),
                  const SizedBox(width: 8),
                  _buildTypeChip('donation', isUrdu ? 'عطیات' : 'Donations'),
                  const SizedBox(width: 8),
                  _buildTypeChip('spending', isUrdu ? 'اخراجات' : 'Spending'),
                  const SizedBox(width: 8),
                  _buildTypeChip('person', isUrdu ? 'افراد' : 'People'),
                  const SizedBox(width: 8),
                  _buildTypeChip('role', isUrdu ? 'کردار' : 'Roles'),
                  const SizedBox(width: 8),
                  _buildTypeChip('settings', isUrdu ? 'میزان' : 'Settings'),
                ],
              ),
            ),
          ),

          Expanded(
            child: auditLogsState.when(
              loading: () => const Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: AppColors.gold),
                    SizedBox(height: 12),
                    Text('Loading audit trail...'),
                  ],
                ),
              ),
              error: (err, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                      const SizedBox(height: 12),
                      Text(
                        isUrdu ? 'آڈٹ ریکارڈ لوڈ کرنے میں خرابی' : 'Unable to load audit logs.',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      Text(err.toString(), style: const TextStyle(fontSize: 11, color: Colors.grey), textAlign: TextAlign.center),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: AppColors.gold, foregroundColor: Colors.black87),
                        onPressed: () => ref.invalidate(hamdardAuditLogsStreamProvider),
                        icon: const Icon(Icons.refresh, size: 16),
                        label: Text(isUrdu ? 'دوبارہ کوشش کریں' : 'Retry'),
                      ),
                    ],
                  ),
                ),
              ),
              data: (logs) {
                final filtered = logs.where((l) {
                  if (_filterType == 'all') return true;
                  return l.recordType.toLowerCase() == _filterType;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.history_toggle_off, size: 54, color: Colors.grey.withValues(alpha: 0.4)),
                        const SizedBox(height: 12),
                        Text(
                          isUrdu ? 'کوئی آڈٹ لاگ دستیاب نہیں' : 'No audit records found.',
                          style: TextStyle(
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                  itemCount: filtered.length,
                  itemBuilder: (ctx, i) {
                    final log = filtered[i];
                    Color actionColor = AppColors.info;
                    IconData actionIcon = Icons.info_outline;

                    if (log.action.startsWith('created') || log.action.startsWith('added')) {
                      actionColor = AppColors.emerald;
                      actionIcon = Icons.add_circle_outline;
                    } else if (log.action.startsWith('edited') || log.action.startsWith('updated') || log.action.contains('link')) {
                      actionColor = AppColors.gold;
                      actionIcon = Icons.edit_note;
                    } else if (log.action.startsWith('deleted') || log.action.startsWith('removed')) {
                      actionColor = AppColors.danger;
                      actionIcon = Icons.delete_outline;
                    } else if (log.action.contains('admin')) {
                      actionColor = Colors.purple;
                      actionIcon = Icons.admin_panel_settings_outlined;
                    }

                    final actorName = log.performedByName.isNotEmpty ? log.performedByName : 'Unknown Actor';
                    final titleText = (log.details != null && log.details!.isNotEmpty)
                        ? log.details!
                        : log.action.replaceAll('_', ' ');

                    return Card(
                      color: isDark ? AppColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 1,
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: actionColor.withValues(alpha: 0.15),
                          child: Icon(actionIcon, color: actionColor, size: 20),
                        ),
                        title: Text(
                          titleText,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        subtitle: Text(
                          '$actorName • ${_dateFormat.format(log.timestamp)}',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: const Icon(Icons.chevron_right, size: 18),
                        onTap: () => _showLogDetailsDialog(log),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTypeChip(String type, String label) {
    final isSelected = _filterType == type;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: AppColors.gold,
      labelStyle: TextStyle(
        color: isSelected ? Colors.black87 : (isDark ? Colors.white70 : Colors.black87),
        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        fontSize: 11.5,
      ),
      onSelected: (_) => setState(() => _filterType = type),
    );
  }
}
