import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../notifications/presentation/widgets/notification_badge_icon.dart';
import '../../models/audit_log_model.dart';
import '../../repositories/audit_log_repository.dart';

class AuditLogScreen extends ConsumerStatefulWidget {
  const AuditLogScreen({super.key});

  @override
  ConsumerState<AuditLogScreen> createState() => _AuditLogScreenState();
}

class _AuditLogScreenState extends ConsumerState<AuditLogScreen> {
  String _selectedFilter = 'all'; // all, approved_request, direct_edit, direct_add_child, direct_delete, rejected_request
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final auditLogsAsync = ref.watch(auditLogsStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('audit_log')),
        actions: const [
          NotificationBadgeIcon(),
        ],
      ),
      body: Column(
        children: [
          // Filter Chips and Search Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: const BoxDecoration(
              color: AppColors.darkSurface,
              border: Border(bottom: BorderSide(color: AppColors.darkBorder, width: 0.8)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search field
                TextField(
                  onChanged: (val) => setState(() => _searchQuery = val.toLowerCase().trim()),
                  decoration: InputDecoration(
                    hintText: isUrdu ? 'ایڈمن یا رکن کے نام سے تلاش کریں...' : 'Search by Admin or Member name...',
                    prefixIcon: const Icon(Icons.search, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 10),
                // Filter chips
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildFilterChip('all', isUrdu ? 'تمام' : 'All'),
                      const SizedBox(width: 8),
                      _buildFilterChip('approved_request', isUrdu ? 'منظوریاں' : 'Approved'),
                      const SizedBox(width: 8),
                      _buildFilterChip('direct_add_child', isUrdu ? 'اضافہ اولاد' : 'Add Child'),
                      const SizedBox(width: 8),
                      _buildFilterChip('direct_edit', isUrdu ? 'ترمیمات' : 'Direct Edit'),
                      const SizedBox(width: 8),
                      _buildFilterChip('direct_delete', isUrdu ? 'حذف' : 'Deleted'),
                      const SizedBox(width: 8),
                      _buildFilterChip('rejected_request', isUrdu ? 'مسترد شدہ' : 'Rejected'),
                      const SizedBox(width: 8),
                      _buildFilterChip('broadcast_notification', isUrdu ? 'اعلانات' : 'Broadcasts'),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Audit Logs List
          Expanded(
            child: auditLogsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: AppColors.emerald)),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    'Error loading audit logs: $err',
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
              ),
              data: (logs) {
                final filtered = logs.where((log) {
                  if (_selectedFilter != 'all' && log.action != _selectedFilter) {
                    return false;
                  }
                  if (_searchQuery.isNotEmpty) {
                    final admin = log.performedByName.toLowerCase();
                    final member = (log.targetMemberName ?? '').toLowerCase();
                    final requester = (log.requestedByName ?? '').toLowerCase();
                    return admin.contains(_searchQuery) ||
                        member.contains(_searchQuery) ||
                        requester.contains(_searchQuery);
                  }
                  return true;
                }).toList();

                if (filtered.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.history_toggle_off, size: 64, color: AppColors.textLightSecondary),
                        const SizedBox(height: 16),
                        Text(
                          isUrdu ? 'کوئی لاگ ریکارڈ دستیاب نہیں۔' : 'No audit log records found.',
                          style: const TextStyle(color: AppColors.textLightSecondary, fontSize: 16),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final log = filtered[index];
                    return _buildAuditLogCard(log, loc, isUrdu);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label, style: TextStyle(fontSize: 12, color: isSelected ? Colors.black : null)),
      selectedColor: AppColors.gold,
      onSelected: (_) => setState(() => _selectedFilter = value),
    );
  }

  Widget _buildAuditLogCard(AuditLogModel log, AppLocalizations loc, bool isUrdu) {
    Color actionColor;
    String actionLabel;
    IconData actionIcon;

    switch (log.action) {
      case 'approved_request':
        actionColor = AppColors.emerald;
        actionLabel = isUrdu ? 'درخواست منظور کی گئی' : 'Approved Request';
        actionIcon = Icons.check_circle;
        break;
      case 'rejected_request':
        actionColor = AppColors.danger;
        actionLabel = isUrdu ? 'درخواست مسترد کی گئی' : 'Rejected Request';
        actionIcon = Icons.cancel;
        break;
      case 'direct_add_child':
        actionColor = AppColors.gold;
        actionLabel = isUrdu ? 'براہ راست بچہ شامل کیا گیا' : 'Added Child';
        actionIcon = Icons.person_add;
        break;
      case 'direct_delete':
        actionColor = Colors.redAccent;
        actionLabel = isUrdu ? 'رکن حذف کیا گیا' : 'Deleted Member';
        actionIcon = Icons.delete_forever;
        break;
      case 'broadcast_notification':
        actionColor = Colors.deepOrangeAccent;
        actionLabel = isUrdu ? 'نوٹیفکیشن براڈکاسٹ' : 'Broadcast Notification';
        actionIcon = Icons.campaign;
        break;
      case 'direct_edit':
      default:
        actionColor = Colors.blueAccent;
        actionLabel = isUrdu ? 'براہ راست ترمیم کی گئی' : 'Direct Edit';
        actionIcon = Icons.edit;
        break;
    }

    final dateStr =
        '${log.timestamp.day} ${_monthName(log.timestamp.month, isUrdu)} ${log.timestamp.year} • ${log.timestamp.hour.toString().padLeft(2, '0')}:${log.timestamp.minute.toString().padLeft(2, '0')}';

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Action Badge & Timestamp
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: actionColor.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: actionColor, width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(actionIcon, size: 14, color: actionColor),
                      const SizedBox(width: 6),
                      Text(
                        actionLabel,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: actionColor,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  dateStr,
                  style: const TextStyle(fontSize: 11, color: AppColors.textLightSecondary),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Performed By (Admin)
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, size: 16, color: AppColors.gold),
                const SizedBox(width: 6),
                Text(
                  '${isUrdu ? "ایڈمن" : "Admin"}: ',
                  style: const TextStyle(fontSize: 13, color: AppColors.textLightSecondary),
                ),
                Text(
                  log.performedByName,
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.darkBackground,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    log.performedByRole.toUpperCase(),
                    style: const TextStyle(fontSize: 9, color: AppColors.gold, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),

            // Requester (if request was approved/rejected)
            if (log.requestedByName != null && log.requestedByName!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16, color: AppColors.textLightSecondary),
                  const SizedBox(width: 6),
                  Text(
                    '${isUrdu ? "درخواست گزار" : "Requested By"}: ',
                    style: const TextStyle(fontSize: 13, color: AppColors.textLightSecondary),
                  ),
                  Text(
                    log.requestedByName!,
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],

            // Target Member
            if (log.targetMemberName != null && log.targetMemberName!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.account_tree_outlined, size: 16, color: AppColors.emerald),
                  const SizedBox(width: 6),
                  Text(
                    '${isUrdu ? "رکن" : "Member"}: ',
                    style: const TextStyle(fontSize: 13, color: AppColors.textLightSecondary),
                  ),
                  Expanded(
                    child: Text(
                      log.targetMemberName!,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AppColors.emeraldLight),
                    ),
                  ),
                ],
              ),
            ],

            // Details string (e.g. parent name for added child)
            if (log.details != null && log.details!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                log.details!,
                style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary, fontStyle: FontStyle.italic),
              ),
            ],

            // Changed Values Diff (oldData vs newData)
            if (log.action == 'broadcast_notification') ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.darkBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.deepOrangeAccent.withValues(alpha: 0.3)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      log.newData['title']?.toString() ?? '',
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      log.newData['body']?.toString() ?? '',
                      style: const TextStyle(fontSize: 12, color: AppColors.textLightSecondary),
                    ),
                  ],
                ),
              ),
            ] else if (log.newData.isNotEmpty) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.darkBackground,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.darkBorder),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: log.newData.entries.map((entry) {
                    final key = entry.key;
                    final newVal = entry.value;
                    final oldVal = log.oldData[key];

                    // If deletion
                    if (key == 'deleted' && newVal == true) {
                      return Text(
                        isUrdu ? 'رکن کو مکمل طور پر حذف کر دیا گیا۔' : 'Member was deleted from family tree.',
                        style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                      );
                    }

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$key: ',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.goldLight),
                          ),
                          if (oldVal != null) ...[
                            Text(
                              '$oldVal',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.danger,
                                decoration: TextDecoration.lineThrough,
                              ),
                            ),
                            const Text(' → ', style: TextStyle(fontSize: 12)),
                          ],
                          Expanded(
                            child: Text(
                              '$newVal',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.emeraldLight,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _monthName(int month, bool isUrdu) {
    const en = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const ur = ['', 'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'];
    if (month >= 1 && month <= 12) {
      return isUrdu ? ur[month] : en[month];
    }
    return '';
  }
}
