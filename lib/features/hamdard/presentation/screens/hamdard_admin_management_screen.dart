import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';
import '../../models/hamdard_audit_log.dart';
import '../../providers/hamdard_providers.dart';
import '../../repositories/hamdard_repository.dart';
import '../widgets/hamdard_user_avatar.dart';
import 'hamdard_audit_log_screen.dart';

class HamdardAdminManagementScreen extends ConsumerStatefulWidget {
  const HamdardAdminManagementScreen({super.key});

  @override
  ConsumerState<HamdardAdminManagementScreen> createState() => _HamdardAdminManagementScreenState();
}

class _HamdardAdminManagementScreenState extends ConsumerState<HamdardAdminManagementScreen> {
  final DateFormat _dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

  Future<void> _showAddHamdardAdminDialog() async {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allUsers = await ref.read(authRepositoryProvider).getAllUsers();
    final nonHamdardAdmins = allUsers.where((u) => !u.isSuperAdmin && !u.isHamdardAdmin).toList();
    String search = '';

    if (!mounted) return;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final filtered = nonHamdardAdmins.where((u) {
            final q = search.toLowerCase().trim();
            if (q.isEmpty) return true;
            return u.name.toLowerCase().contains(q) ||
                u.email.toLowerCase().contains(q) ||
                u.phone.contains(q);
          }).toList();

          return AlertDialog(
            backgroundColor: isDark ? AppColors.darkCard : Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            title: Text(loc.isUrdu ? 'ہمدرد ایڈمن مقرر کریں' : 'Assign Hamdard Admin'),
            content: SizedBox(
              width: double.maxFinite,
              height: 420,
              child: Column(
                children: [
                  TextField(
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.search),
                      hintText: loc.isUrdu ? 'صارف کو تلاش کریں...' : 'Search user...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (val) => setDialogState(() => search = val),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: filtered.isEmpty
                        ? Center(
                            child: Text(
                              loc.isUrdu ? 'کوئی اہل صارف دستیاب نہیں' : 'No eligible users found',
                              style: const TextStyle(color: Colors.grey),
                            ),
                          )
                        : ListView.separated(
                            itemCount: filtered.length,
                            separatorBuilder: (ctx, i) => const Divider(height: 1),
                            itemBuilder: (ctx, i) {
                              final u = filtered[i];
                              return ListTile(
                                leading: HamdardUserAvatar(
                                  imageUrl: u.profileImageUrl,
                                  name: u.name,
                                  size: 40,
                                ),
                                title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                                subtitle: Text(
                                  '${u.email} • Current: ${u.role.labelEn}',
                                  style: const TextStyle(fontSize: 11),
                                ),
                                trailing: ElevatedButton(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: AppColors.emerald,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  ),
                                  onPressed: () async {
                                    final currentSuper = ref.read(currentUserProvider);
                                    if (currentSuper != null) {
                                      await ref.read(authRepositoryProvider).setHamdardAdminRole(
                                        uid: u.uid,
                                        isHamdardAdmin: true,
                                        assignedByUid: currentSuper.uid,
                                        assignedByName: currentSuper.name,
                                      );

                                      await ref.read(hamdardRepositoryProvider).recordAuditLog(
                                        HamdardAuditLog(
                                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                                          action: 'assigned_hamdard_admin',
                                          recordType: 'role',
                                          recordId: u.uid,
                                          performedBy: currentSuper.uid,
                                          performedByName: currentSuper.name,
                                          timestamp: DateTime.now(),
                                          oldData: {'is_hamdard_admin': false},
                                          newData: {'is_hamdard_admin': true, 'assigned_to': u.name},
                                          details: 'Super Admin assigned Hamdard Admin role to ${u.name} (${u.email})',
                                        ),
                                      );
                                    }
                                    if (ctx.mounted) Navigator.pop(ctx);
                                    ref.invalidate(hamdardAdminsFutureProvider);
                                  },
                                  child: Text(loc.isUrdu ? 'مقرر کریں' : 'Assign'),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(loc.translate('cancel')),
              ),
            ],
          );
        },
      ),
    );
  }

  Future<void> _confirmRemoveHamdardAdmin(UserModel adminUser) async {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentSuper = ref.read(currentUserProvider);

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'ہمدرد ایڈمن کا عہدہ ختم کریں؟' : 'Remove Hamdard Admin?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                HamdardUserAvatar(
                  imageUrl: adminUser.profileImageUrl,
                  name: adminUser.name,
                  size: 44,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(adminUser.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                      Text(adminUser.email, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              loc.isUrdu
                  ? 'کیا آپ واقعی ${adminUser.name} سے ہمدرد ایڈمن کی ذمہ داری واپس لینا چاہتے ہیں؟ اگر ان کے پاس نارمل ایڈمن رول ہے تو وہ برقرار رہے گا۔'
                  : 'Are you sure you want to remove Hamdard Admin privileges from ${adminUser.name}? Their base role (${adminUser.role.labelEn}) will remain untouched.',
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(loc.translate('delete')),
          ),
        ],
      ),
    );

    if (confirm == true && currentSuper != null) {
      await ref.read(authRepositoryProvider).setHamdardAdminRole(
        uid: adminUser.uid,
        isHamdardAdmin: false,
        assignedByUid: currentSuper.uid,
        assignedByName: currentSuper.name,
      );

      await ref.read(hamdardRepositoryProvider).recordAuditLog(
        HamdardAuditLog(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          action: 'removed_hamdard_admin',
          recordType: 'role',
          recordId: adminUser.uid,
          performedBy: currentSuper.uid,
          performedByName: currentSuper.name,
          timestamp: DateTime.now(),
          oldData: {'is_hamdard_admin': true},
          newData: {'is_hamdard_admin': false, 'removed_from': adminUser.name},
          details: 'Super Admin removed Hamdard Admin role from ${adminUser.name}',
        ),
      );

      ref.invalidate(hamdardAdminsFutureProvider);
    }
  }

  void _showSetOpeningBalanceDialog() {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentBal = ref.read(hamdardOpeningBalanceStreamProvider).valueOrNull ?? 0;
    final amountCtrl = TextEditingController(text: currentBal.toString());
    final reasonCtrl = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(loc.isUrdu ? 'ابتدائی میزان مقرر کریں' : 'Set Opening Balance'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.isUrdu
                  ? 'یہ صرف سپر ایڈمن کر سکتا ہے۔ تبدیلی مکمل طور پر آڈٹ ٹریل میں محفوظ کی جائے گی۔'
                  : 'Super Admin only. Any adjustment is tracked with a full financial audit log.',
              style: TextStyle(
                fontSize: 12,
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: amountCtrl,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: loc.isUrdu ? 'ابتدائی رقم (روپے)' : 'Opening Amount (PKR)',
                prefixText: 'Rs. ',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: reasonCtrl,
              decoration: InputDecoration(
                labelText: loc.isUrdu ? 'تبدیلی کی وجہ' : 'Reason for change',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.gold,
              foregroundColor: Colors.black,
            ),
            onPressed: () async {
              final val = int.tryParse(amountCtrl.text.trim()) ?? 0;
              final currentSuper = ref.read(currentUserProvider);
              if (currentSuper != null) {
                await ref.read(hamdardRepositoryProvider).setOpeningBalance(
                  val,
                  performedBy: currentSuper.uid,
                  performedByName: currentSuper.name,
                  reason: reasonCtrl.text.trim(),
                );
              }
              if (ctx.mounted) Navigator.pop(ctx);
            },
            child: Text(loc.translate('save')),
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
    final adminsAsync = ref.watch(hamdardAdminsFutureProvider);
    final openingBalance = ref.watch(hamdardOpeningBalanceStreamProvider).valueOrNull ?? 0;

    return Scaffold(
      appBar: AppBar(
        title: Text(isUrdu ? 'ہمدرد ایڈمن مینجمنٹ' : 'Hamdard Admin Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: isUrdu ? 'آڈٹ لاگ' : 'Financial Audit Logs',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const HamdardAuditLogScreen()),
              );
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.emerald,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.person_add),
        label: Text(isUrdu ? 'نیا ایڈمن بنائیں' : 'Add Hamdard Admin'),
        onPressed: _showAddHamdardAdminDialog,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          // Super Admin Controls Card: Opening Balance & Audit Log Shortcuts
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
                      const Icon(Icons.shield, color: AppColors.gold, size: 24),
                      const SizedBox(width: 10),
                      Text(
                        isUrdu ? 'سپر ایڈمن کنٹرول پینل' : 'Super Admin Control Panel',
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    leading: const Icon(Icons.account_balance_wallet_outlined, color: AppColors.gold),
                    title: Text(isUrdu ? 'ابتدائی کیش بیلنس' : 'Opening Cash Balance'),
                    subtitle: Text(HamdardRepository.formatPkr(openingBalance),
                        style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold)),
                    trailing: const Icon(Icons.edit, size: 18),
                    onTap: _showSetOpeningBalanceDialog,
                  ),
                  const SizedBox(height: 10),
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    tileColor: isDark ? AppColors.darkCard : AppColors.lightCard,
                    leading: const Icon(Icons.receipt_long_outlined, color: AppColors.info),
                    title: Text(isUrdu ? 'مالیاتی آڈٹ ٹریل' : 'Financial Audit Logs'),
                    subtitle: Text(
                      isUrdu ? 'تمام مالیاتی تبدیلیوں کی تفصیلی تاریخ' : 'Audit logs of all financial transactions',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const HamdardAuditLogScreen()),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Current Hamdard Admins List Header
          Text(
            isUrdu ? 'موجودہ ہمدرد ایڈمنز' : 'Current Hamdard Administrators',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          adminsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (err, stack) => Center(
              child: Text('Error loading admins: $err'),
            ),
            data: (admins) {
              if (admins.isEmpty) {
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      isUrdu ? 'کوئی ہمدرد ایڈمن مقرر نہیں' : 'No Hamdard Admins configured.',
                      style: const TextStyle(color: Colors.grey),
                    ),
                  ),
                );
              }

              return Column(
                children: admins.map((admin) {
                  final isSuper = admin.isSuperAdmin;
                  final hasBaseAdmin = admin.role.isAdmin && !isSuper;

                  return Card(
                    color: isDark ? AppColors.darkSurface : Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    margin: const EdgeInsets.only(bottom: 12),
                    elevation: 1.5,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Stack(
                                clipBehavior: Clip.none,
                                children: [
                                  HamdardUserAvatar(
                                    imageUrl: admin.profileImageUrl,
                                    name: admin.name,
                                    size: 46,
                                    backgroundColor: isSuper
                                        ? AppColors.gold.withValues(alpha: 0.2)
                                        : AppColors.emerald.withValues(alpha: 0.2),
                                    textColor: isSuper ? AppColors.gold : AppColors.emerald,
                                  ),
                                  Positioned(
                                    right: -2,
                                    bottom: -2,
                                    child: Container(
                                      padding: const EdgeInsets.all(3),
                                      decoration: BoxDecoration(
                                        color: isSuper ? AppColors.gold : AppColors.emerald,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isDark ? AppColors.darkCard : Colors.white,
                                          width: 1.5,
                                        ),
                                      ),
                                      child: Icon(
                                        isSuper ? Icons.shield : Icons.security,
                                        color: Colors.black87,
                                        size: 11,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(admin.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    Text(
                                      '${admin.email} • ${admin.phone.isNotEmpty ? admin.phone : "No Phone"}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Wrap(
                                      spacing: 6,
                                      children: [
                                        if (isSuper)
                                          _buildRoleChip('Super Admin', AppColors.gold)
                                        else ...[
                                          _buildRoleChip('Hamdard Admin', AppColors.emerald),
                                          if (hasBaseAdmin) _buildRoleChip('Tree Admin', AppColors.info),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              if (!isSuper)
                                IconButton(
                                  icon: const Icon(Icons.remove_circle_outline, color: AppColors.danger),
                                  tooltip: 'Remove Hamdard Admin',
                                  onPressed: () => _confirmRemoveHamdardAdmin(admin),
                                ),
                            ],
                          ),
                          if (admin.hamdardAdminAssignedAt != null) ...[
                            const SizedBox(height: 10),
                            const Divider(height: 1),
                            const SizedBox(height: 8),
                            Text(
                              'Assigned: ${_dateFormat.format(admin.hamdardAdminAssignedAt!)}${admin.hamdardAdminAssignedByName?.isNotEmpty == true ? " by ${admin.hamdardAdminAssignedByName}" : ""}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildRoleChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: color),
      ),
    );
  }
}
