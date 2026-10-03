import 'dart:convert';
import 'package:flutter/material.dart';
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

  void _showLogDetailsDialog(HamdardAuditLog log) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    const encoder = JsonEncoder.withIndent('  ');

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
                log.action.replaceAll('_', ' ').toUpperCase(),
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
                _buildDetailRow('Performed By', '${log.performedByName} (${log.performedBy})'),
                _buildDetailRow('Record Type', log.recordType.toUpperCase()),
                _buildDetailRow('Record ID', log.recordId),
                if (log.details != null && log.details!.isNotEmpty)
                  _buildDetailRow('Details', log.details!),
                const Divider(height: 16),
                if (log.oldData != null) ...[
                  const Text('PREVIOUS DATA (OLD):',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.danger)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      encoder.convert(log.oldData),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                if (log.newData != null) ...[
                  const Text('NEW / UPDATED DATA:',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.emerald)),
                  const SizedBox(height: 4),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurface : AppColors.lightCard,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      encoder.convert(log.newData),
                      style: const TextStyle(fontFamily: 'monospace', fontSize: 10),
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
          // Filter Chips (All, Donation, Spending, Role, Settings)
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
                  _buildTypeChip('role', isUrdu ? 'کردار' : 'Roles'),
                  const SizedBox(width: 8),
                  _buildTypeChip('settings', isUrdu ? 'میزان' : 'Settings'),
                ],
              ),
            ),
          ),

          Expanded(
            child: auditLogsState.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(child: Text('Error: $err')),
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

                    if (log.action.startsWith('created')) {
                      actionColor = AppColors.emerald;
                      actionIcon = Icons.add_circle_outline;
                    } else if (log.action.startsWith('edited')) {
                      actionColor = AppColors.gold;
                      actionIcon = Icons.edit_note;
                    } else if (log.action.startsWith('deleted')) {
                      actionColor = AppColors.danger;
                      actionIcon = Icons.delete_outline;
                    } else if (log.action.contains('admin')) {
                      actionColor = Colors.purple;
                      actionIcon = Icons.admin_panel_settings_outlined;
                    }

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
                          log.details ?? log.action.replaceAll('_', ' '),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13.5),
                        ),
                        subtitle: Text(
                          '${log.performedByName} • ${_dateFormat.format(log.timestamp)}',
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
