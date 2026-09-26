import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../auth/models/user_model.dart';
import '../../../auth/providers/auth_provider.dart';

class AdminUserManagementScreen extends ConsumerStatefulWidget {
  const AdminUserManagementScreen({super.key});

  @override
  ConsumerState<AdminUserManagementScreen> createState() =>
      _AdminUserManagementScreenState();
}

class _AdminUserManagementScreenState
    extends ConsumerState<AdminUserManagementScreen> {
  List<UserModel> _users = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadUsers();
  }

  Future<void> _loadUsers() async {
    setState(() => _isLoading = true);
    try {
      final users = await ref.read(authRepositoryProvider).getAllUsers();
      if (mounted) setState(() => _users = users);
    } catch (_) {}
    if (mounted) setState(() => _isLoading = false);
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Not Available';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = (dt.month >= 1 && dt.month <= 12) ? months[dt.month - 1] : '${dt.month}';
    return '${dt.day} $monthName ${dt.year}';
  }

  void _showUserDetailsDialog(UserModel user) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.read(currentUserProvider);
    final isSuperAdmin = currentUser?.isSuperAdmin ?? false;

    UserRole selectedRole = user.role;
    AccountStatus selectedStatus = user.status;
    final devInfo = user.deviceInfo;
    final locInfo = devInfo?.location;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => Dialog(
          backgroundColor: isDark ? AppColors.darkCard : Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 540, maxHeight: 720),
            child: Column(
              children: [
                // Dialog Header
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                    border: Border(
                      bottom: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: user.isSuperAdmin
                            ? AppColors.gold
                            : (user.isAdmin ? AppColors.emerald : AppColors.lightBorder),
                        child: Icon(
                          user.isSuperAdmin
                              ? Icons.admin_panel_settings
                              : (user.isAdmin ? Icons.security : Icons.person),
                          color: Colors.white,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.name,
                              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${user.email} • ${user.phone.isNotEmpty ? user.phone : "No Phone"}',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                ),

                // Dialog Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Section 1: Personal Information
                        _buildSectionHeader('Personal Information', Icons.badge_outlined, isDark),
                        const SizedBox(height: 8),
                        _buildDetailCard(
                          isDark,
                          children: [
                            _buildInfoTile('Full Name', user.name),
                            _buildInfoTile("Father's Name", user.fatherName.isNotEmpty ? user.fatherName : 'Not Available'),
                            _buildInfoTile('Gender', UserModel.normalizeGender(user.gender)),
                            _buildInfoTile('Phone', user.phone.isNotEmpty ? user.phone : 'Not Available'),
                            _buildInfoTile('Email', user.email),
                            _buildInfoTile('Blood Group', user.bloodGroup.isNotEmpty ? user.bloodGroup : 'Unknown'),
                            _buildInfoTile('Profession', user.profession.isNotEmpty ? user.profession : 'Not Available'),
                            _buildInfoTile('Address', user.address.isNotEmpty ? user.address : 'Not Available'),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Section 2: Device Information
                        _buildSectionHeader('Device Information', Icons.devices_outlined, isDark),
                        const SizedBox(height: 8),
                        _buildDetailCard(
                          isDark,
                          children: [
                            _buildInfoTile('Platform', devInfo?.platform.isNotEmpty == true ? devInfo!.platform : 'Unknown'),
                            _buildInfoTile('Manufacturer', devInfo?.manufacturer.isNotEmpty == true ? devInfo!.manufacturer : 'Not Available'),
                            _buildInfoTile('Model', devInfo?.model.isNotEmpty == true ? devInfo!.model : 'Not Available'),
                            _buildInfoTile('Device Name', devInfo?.deviceName.isNotEmpty == true ? devInfo!.deviceName : 'Not Available'),
                            _buildInfoTile(
                              'OS',
                              devInfo != null && devInfo.operatingSystem.isNotEmpty
                                  ? '${devInfo.operatingSystem} ${devInfo.operatingSystemVersion}'.trim()
                                  : 'Not Available',
                            ),
                            _buildInfoTile('App Version', devInfo?.appVersion.isNotEmpty == true ? devInfo!.appVersion : 'Not Available'),
                            _buildInfoTile('Build', devInfo?.buildNumber.isNotEmpty == true ? devInfo!.buildNumber : 'Not Available'),
                            _buildInfoTile(
                              'Physical Device',
                              devInfo?.isPhysicalDevice != null
                                  ? (devInfo!.isPhysicalDevice! ? 'Yes' : 'No (Emulator/Simulator)')
                                  : 'Unknown',
                            ),
                            _buildInfoTile(
                              'Last Updated',
                              devInfo?.collectedAt != null
                                  ? _formatDate(devInfo!.collectedAt)
                                  : 'Not Available',
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),

                        // Section 3: Location Information (Super Admin Only)
                        if (isSuperAdmin) ...[
                          _buildSectionHeader('Location Information', Icons.location_on_outlined, isDark),
                          const SizedBox(height: 8),
                          _buildDetailCard(
                            isDark,
                            children: _buildLocationRows(locInfo),
                          ),
                          const SizedBox(height: 18),
                        ],

                        // Section 4: Account Information
                        _buildSectionHeader('Account Information', Icons.manage_accounts_outlined, isDark),
                        const SizedBox(height: 8),
                        _buildDetailCard(
                          isDark,
                          children: [
                            _buildInfoTile('User ID (UID)', user.uid),
                            _buildInfoTile('Registered Date', _formatDate(user.createdAt)),
                            const SizedBox(height: 12),
                            if (isSuperAdmin) ...[
                              DropdownButtonFormField<UserRole>(
                                initialValue: selectedRole,
                                decoration: InputDecoration(
                                  labelText: 'Account Role',
                                  filled: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: UserRole.values.map((role) {
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Text(loc.isUrdu ? role.labelUr : role.labelEn),
                                  );
                                }).toList(),
                                onChanged: (r) {
                                  if (r != null) setDialogState(() => selectedRole = r);
                                },
                              ),
                              const SizedBox(height: 12),
                              DropdownButtonFormField<AccountStatus>(
                                initialValue: selectedStatus,
                                decoration: InputDecoration(
                                  labelText: 'Account Status',
                                  filled: true,
                                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                ),
                                items: AccountStatus.values.map((s) {
                                  return DropdownMenuItem(
                                    value: s,
                                    child: Text(s.value.toUpperCase()),
                                  );
                                }).toList(),
                                onChanged: (s) {
                                  if (s != null) setDialogState(() => selectedStatus = s);
                                },
                              ),
                            ] else ...[
                              _buildInfoTile('Role', user.role.labelEn),
                              _buildInfoTile('Status', user.status.value.toUpperCase()),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                // Dialog Actions
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                    border: Border(
                      top: BorderSide(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Delete user permanently button
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.danger,
                        ),
                        onPressed: () async {
                          final navigator = Navigator.of(ctx);
                          final scaffoldMessenger = ScaffoldMessenger.of(context);

                          if (user.uid == currentUser?.uid) {
                            scaffoldMessenger.showSnackBar(
                              const SnackBar(
                                backgroundColor: AppColors.danger,
                                content: Text('You cannot delete your own logged-in account.'),
                              ),
                            );
                            return;
                          }

                          final confirm = await showDialog<bool>(
                            context: ctx,
                            builder: (deleteCtx) => AlertDialog(
                              title: Row(
                                children: [
                                  const Icon(Icons.warning_amber_rounded, color: AppColors.danger),
                                  const SizedBox(width: 8),
                                  Text(loc.isUrdu ? 'صارف کو مستقل حذف کریں؟' : 'Delete User Permanently?'),
                                ],
                              ),
                              content: Text(
                                loc.isUrdu
                                    ? 'کیا آپ واقعی "${user.name}" (${user.email}) کو سسٹم سے مستقل طور پر حذف کرنا چاہتے ہیں؟ یہ عمل واپس نہیں لیا جا سکتا۔'
                                    : 'Are you sure you want to permanently delete "${user.name}" (${user.email}) from the system? This action cannot be undone.',
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () => Navigator.pop(deleteCtx, false),
                                  child: Text(loc.translate('cancel')),
                                ),
                                ElevatedButton(
                                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                                  onPressed: () => Navigator.pop(deleteCtx, true),
                                  child: Text(
                                    loc.isUrdu ? 'مستقل حذف کریں' : 'Delete Permanently',
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                ),
                              ],
                            ),
                          );

                          if (confirm == true && mounted) {
                            try {
                              await ref.read(authRepositoryProvider).deleteUserPermanently(user.uid);
                              if (mounted) {
                                navigator.pop();
                                _loadUsers();
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.danger,
                                    content: Text(
                                      loc.isUrdu
                                          ? 'صارف کو مستقل طور پر حذف کر دیا گیا۔'
                                          : 'User "${user.name}" permanently deleted from system.',
                                    ),
                                  ),
                                );
                              }
                            } catch (e) {
                              if (mounted) {
                                scaffoldMessenger.showSnackBar(
                                  SnackBar(
                                    backgroundColor: AppColors.danger,
                                    content: Text('Failed to delete user: $e'),
                                  ),
                                );
                              }
                            }
                          }
                        },
                        icon: const Icon(Icons.delete_forever, size: 18),
                        label: Text(
                          loc.isUrdu ? 'مستقل حذف' : 'Delete User',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(loc.translate('cancel')),
                      ),
                      if (isSuperAdmin) ...[
                        const SizedBox(width: 8),
                        ElevatedButton.icon(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.emerald,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          onPressed: () async {
                            final navigator = Navigator.of(ctx);
                            await ref.read(authRepositoryProvider).setRoleAndStatus(
                                  uid: user.uid,
                                  role: selectedRole,
                                  status: selectedStatus,
                                );
                            if (mounted) {
                              navigator.pop();
                              _loadUsers();
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  backgroundColor: AppColors.emerald,
                                  content: Text('User role & status updated successfully.'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.save, size: 16),
                          label: Text(loc.translate('save')),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildLocationRows(UserLocationInfo? locInfo) {
    if (locInfo == null) {
      return [
        _buildInfoTile('Location', 'Not Available'),
      ];
    }

    final pStatus = locInfo.permissionStatus.toLowerCase();

    if (pStatus == 'denied' || pStatus == 'deniedforever') {
      return [
        _buildInfoTile('Location Permission', 'Denied'),
        _buildInfoTile('Location', 'Unavailable'),
      ];
    } else if (pStatus == 'not_now') {
      return [
        _buildInfoTile('Location Permission', 'Skipped by User (Not Now)'),
        _buildInfoTile('Location', 'Unavailable'),
      ];
    } else if (pStatus == 'disabled') {
      return [
        _buildInfoTile('Location Service', 'Disabled on Device'),
        _buildInfoTile('Location', 'Unavailable'),
      ];
    }

    if (locInfo.hasCoordinates) {
      return [
        _buildInfoTile('Latitude', locInfo.latitude?.toStringAsFixed(5) ?? 'Not Available'),
        _buildInfoTile('Longitude', locInfo.longitude?.toStringAsFixed(5) ?? 'Not Available'),
        if (locInfo.accuracy != null)
          _buildInfoTile('Accuracy', '${locInfo.accuracy!.toStringAsFixed(1)} m'),
        if (locInfo.altitude != null)
          _buildInfoTile('Altitude', '${locInfo.altitude!.toStringAsFixed(1)} m'),
        if (locInfo.speed != null)
          _buildInfoTile('Speed', '${locInfo.speed!.toStringAsFixed(1)} m/s'),
        _buildInfoTile('Last Updated', _formatDate(locInfo.timestamp)),
      ];
    }

    return [
      _buildInfoTile('Location Permission', locInfo.permissionStatus.isNotEmpty ? locInfo.permissionStatus : 'Unknown'),
      _buildInfoTile('Location', 'Not Available'),
    ];
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isDark) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.gold),
        const SizedBox(width: 8),
        Text(
          title,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: isDark ? AppColors.goldLight : AppColors.goldDark,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailCard(bool isDark, {required List<Widget> children}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightBackground,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }

  Widget _buildInfoTile(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 130,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 12.5,
                color: AppColors.textLightSecondary,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final currentUser = ref.watch(currentUserProvider);

    if (currentUser?.isSuperAdmin != true) {
      return Scaffold(
        appBar: AppBar(title: Text(loc.translate('user_management'))),
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

    final filtered = _users.where((u) {
      final q = _searchQuery.toLowerCase();
      return u.name.toLowerCase().contains(q) ||
          u.email.toLowerCase().contains(q) ||
          u.phone.toLowerCase().contains(q) ||
          u.fatherName.toLowerCase().contains(q);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('user_management')),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.emerald))
          : Column(
              children: [
                // Clean search bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search by name, email, phone, or father...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear),
                              onPressed: () => setState(() => _searchQuery = ''),
                            )
                          : null,
                    ),
                  ),
                ),

                // Clean User List
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No users found.'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                ),
                              ),
                              child: ListTile(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                leading: CircleAvatar(
                                  radius: 20,
                                  backgroundColor: user.isSuperAdmin
                                      ? AppColors.gold
                                      : (user.isAdmin ? AppColors.emerald : (isDark ? AppColors.darkCard : AppColors.lightBorder)),
                                  child: Icon(
                                    user.isSuperAdmin
                                        ? Icons.admin_panel_settings
                                        : (user.isAdmin ? Icons.security : Icons.person),
                                    color: user.isAdmin ? Colors.black87 : (isDark ? Colors.white : Colors.black87),
                                    size: 20,
                                  ),
                                ),
                                title: Text(
                                  user.name,
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                ),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 2),
                                    Text(
                                      '${user.email} • ${user.phone.isNotEmpty ? user.phone : "No Phone"}',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                      ),
                                    ),
                                    const SizedBox(height: 6),
                                    Row(
                                      children: [
                                        // Role badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: user.isSuperAdmin
                                                ? AppColors.gold.withValues(alpha: 0.2)
                                                : (user.isAdmin
                                                    ? AppColors.emerald.withValues(alpha: 0.2)
                                                    : (isDark ? AppColors.darkBorder : AppColors.lightBorder)),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            loc.isUrdu ? user.role.labelUr : user.role.labelEn,
                                            style: TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: user.isSuperAdmin
                                                  ? AppColors.goldLight
                                                  : (user.isAdmin ? AppColors.emeraldLight : (isDark ? Colors.white : Colors.black87)),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 8),

                                        // Status badge
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: user.isBlocked
                                                ? AppColors.danger.withValues(alpha: 0.15)
                                                : AppColors.emerald.withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            user.status.value.toUpperCase(),
                                            style: TextStyle(
                                              fontSize: 10.5,
                                              color: user.isBlocked ? AppColors.danger : AppColors.emeraldLight,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                                onTap: () => _showUserDetailsDialog(user),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
