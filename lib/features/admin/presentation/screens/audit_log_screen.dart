import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../family_tree/providers/family_tree_providers.dart';
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
              loading: () => Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: AppColors.emerald),
                    const SizedBox(height: 16),
                    Text(
                      isUrdu ? 'تاریخچہ لوڈ ہو رہا ہے...' : 'Loading History...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                        color: AppColors.textLightSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              error: (err, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.error_outline, size: 54, color: AppColors.danger),
                      const SizedBox(height: 14),
                      Text(
                        isUrdu ? 'تاریخچہ لوڈ نہیں ہو سکا۔' : 'Unable to load history.',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isUrdu ? 'براہ کرم دوبارہ کوشش کریں۔' : 'Please try again.',
                        style: const TextStyle(fontSize: 13, color: AppColors.textLightSecondary),
                      ),
                      const SizedBox(height: 16),
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.emerald,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () => ref.invalidate(auditLogsStreamProvider),
                        icon: const Icon(Icons.refresh, size: 18),
                        label: Text(isUrdu ? 'دوبارہ کوشش کریں' : 'Retry'),
                      ),
                    ],
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

                    final isOldImage = _isBase64ImageData(key, oldVal);
                    final isNewImage = _isBase64ImageData(key, newVal);
                    final keyLabel = _formatKeyLabel(key, isUrdu);
                    final oldDisplay = _formatAuditValue(key, oldVal, isUrdu);
                    final newDisplay = _formatAuditValue(key, newVal, isUrdu);

                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (isOldImage || isNewImage)
                            const Padding(
                              padding: EdgeInsets.only(right: 4, top: 1),
                              child: Icon(Icons.image_outlined, size: 14, color: AppColors.goldLight),
                            ),
                          Text(
                            '$keyLabel: ',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.goldLight),
                          ),
                          if (oldVal != null) ...[
                            Flexible(
                              child: Text(
                                oldDisplay,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.danger,
                                  decoration: TextDecoration.lineThrough,
                                ),
                              ),
                            ),
                            const Text(' → ', style: TextStyle(fontSize: 12)),
                          ],
                          Expanded(
                            child: Text(
                              newDisplay,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
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
            ] else if (log.action.contains('delete')) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                ),
                child: Text(
                  isUrdu
                      ? 'رکن اور ان کی متعلقہ تمام اولادیں شجرہ نسب سے مستقل طور پر خارج کر دی گئیں۔'
                      : 'Member and all descendants permanently deleted from family tree.',
                  style: const TextStyle(fontSize: 12, color: AppColors.danger, fontWeight: FontWeight.w600),
                ),
              ),
            ],

            // "View Profile" action button
            if (log.action != 'broadcast_notification' &&
                ((log.targetMemberId != null && log.targetMemberId!.isNotEmpty) ||
                 (log.newData['id'] != null && log.newData['id'].toString().isNotEmpty) ||
                 (log.newData['member_id'] != null && log.newData['member_id'].toString().isNotEmpty))) ...[
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.emeraldLight,
                    side: BorderSide(color: AppColors.emerald.withValues(alpha: 0.5)),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    padding: const EdgeInsets.symmetric(vertical: 9),
                  ),
                  icon: const Icon(Icons.person_outline, size: 16),
                  label: Text(
                    isUrdu ? 'پروفائل دیکھیں' : 'View Profile',
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                  onPressed: () => _navigateToMemberProfile(log, isUrdu),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _navigateToMemberProfile(AuditLogModel log, bool isUrdu) {
    String? targetId;
    if (log.action.contains('add_child')) {
      final childId = log.newData['id']?.toString() ?? log.newData['member_id']?.toString();
      if (childId != null && childId.isNotEmpty) {
        targetId = childId;
      }
    }
    targetId ??= log.targetMemberId;

    if (targetId == null || targetId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            isUrdu
                ? 'اس لاگ ریکارڈ میں رکن کی شناخت دستیاب نہیں ہے۔'
                : 'Member identifier is not available for this record.',
          ),
        ),
      );
      return;
    }

    final membersMap = ref.read(familyMembersMapProvider);
    final member = membersMap[targetId];

    if (member == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: AppColors.danger,
          content: Text(
            isUrdu
                ? 'یہ خاندانی رکن اب شجرہ نسب میں دستیاب نہیں ہے۔'
                : 'This family member is no longer available in the family tree.',
          ),
        ),
      );
      return;
    }

    // Navigate to Member Profile screen
    context.push('/member/${member.id}');
  }

  String _monthName(int month, bool isUrdu) {
    const en = ['', 'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    const ur = ['', 'جنوری', 'فروری', 'مارچ', 'اپریل', 'مئی', 'جون', 'جولائی', 'اگست', 'ستمبر', 'اکتوبر', 'نومبر', 'دسمبر'];
    if (month >= 1 && month <= 12) {
      return isUrdu ? ur[month] : en[month];
    }
    return '';
  }

  bool _isBase64ImageData(String key, dynamic val) {
    if (val == null) return false;
    final str = val.toString().trim();
    if (str.isEmpty) return false;

    final lowerKey = key.toLowerCase();
    final isImageKey = lowerKey.contains('image') ||
        lowerKey.contains('photo') ||
        lowerKey.contains('avatar') ||
        lowerKey.contains('picture');

    if (str.startsWith('data:image/')) return true;
    if (str.startsWith('iVBORw0KGgo') ||
        str.startsWith('/9j/') ||
        str.startsWith('R0lGOD') ||
        str.startsWith('UklGR')) {
      return true;
    }

    if (isImageKey && str.length > 100 && !str.startsWith('http')) {
      return true;
    }

    if (str.length > 300 && !str.contains(' ') && !str.startsWith('http')) {
      return true;
    }

    return false;
  }

  String _formatAuditValue(String key, dynamic val, bool isUrdu) {
    if (val == null) return isUrdu ? 'خالی' : 'None';
    if (_isBase64ImageData(key, val)) {
      return isUrdu ? '[تصویر کا ڈیٹا موجود ہے]' : '[Image data available]';
    }
    final str = val.toString();
    if (str.length > 100) {
      return '${str.substring(0, 97)}...';
    }
    return str;
  }

  String _formatKeyLabel(String key, bool isUrdu) {
    switch (key.toLowerCase()) {
      case 'name_en':
      case 'nameen':
        return isUrdu ? 'نام (انگریزی)' : 'Name (EN)';
      case 'name_ur':
      case 'nameur':
        return isUrdu ? 'نام (اردو)' : 'Name (UR)';
      case 'father_name':
      case 'fathername':
        return isUrdu ? 'والد کا نام' : 'Father';
      case 'photo_url':
      case 'photourl':
      case 'profile_photo':
      case 'profile_image':
        return isUrdu ? 'پروفائل تصویر' : 'Profile Image';
      case 'generation':
        return isUrdu ? 'پشت' : 'Generation';
      case 'birth_year':
        return isUrdu ? 'پیدائش' : 'Birth Year';
      case 'death_year':
        return isUrdu ? 'وفات' : 'Death Year';
      case 'is_alive':
      case 'alive_status':
        return isUrdu ? 'حیات/وفات' : 'Status';
      default:
        return key.replaceAll('_', ' ');
    }
  }
}
