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
      setState(() => _users = users);
    } catch (_) {}
    setState(() => _isLoading = false);
  }

  void _showUserDetailsDialog(UserModel user) {
    final loc = AppLocalizations.of(context);
    final currentUser = ref.read(currentUserProvider);
    final isSuperAdmin = currentUser?.isSuperAdmin ?? false;

    UserRole selectedRole = user.role;
    AccountStatus selectedStatus = user.status;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(user.name),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildUserDetailRow('Email', user.email),
                _buildUserDetailRow('Father Name', user.fatherName),
                _buildUserDetailRow('Address', user.address),
                _buildUserDetailRow('UID', user.uid),
                if (user.createdAt != null)
                  _buildUserDetailRow(
                    'Registered',
                    '${user.createdAt!.day}/${user.createdAt!.month}/${user.createdAt!.year}',
                  ),
                const SizedBox(height: 16),
                const Divider(),
                const SizedBox(height: 8),

                if (isSuperAdmin) ...[
                  const Text(
                    'Manage Role & Status (Super Admin):',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.gold),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<UserRole>(
                    initialValue: selectedRole,
                    decoration: const InputDecoration(labelText: 'Role'),
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
                    decoration: const InputDecoration(labelText: 'Status'),
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
                  _buildUserDetailRow('Role', user.role.labelEn),
                  _buildUserDetailRow('Status', user.status.value.toUpperCase()),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(loc.translate('cancel')),
            ),
            if (isSuperAdmin)
              ElevatedButton(
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
                  }
                },
                child: Text(loc.translate('save')),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val.trim()),
                    decoration: InputDecoration(
                      hintText: 'Search users by name, email, or father...',
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
                Expanded(
                  child: filtered.isEmpty
                      ? const Center(child: Text('No users found.'))
                      : ListView.builder(
                          itemCount: filtered.length,
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          itemBuilder: (context, index) {
                            final user = filtered[index];
                            return Card(
                              margin: const EdgeInsets.only(bottom: 12),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: user.isSuperAdmin
                                      ? AppColors.gold
                                      : (user.isAdmin ? AppColors.emerald : AppColors.darkBackground),
                                  child: Icon(
                                    user.isSuperAdmin
                                        ? Icons.admin_panel_settings
                                        : (user.isAdmin ? Icons.security : Icons.person),
                                    color: Colors.white,
                                  ),
                                ),
                                title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${user.email} • Father: ${user.fatherName}'),
                                    const SizedBox(height: 2),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                          decoration: BoxDecoration(
                                            color: user.isSuperAdmin
                                                ? AppColors.gold.withValues(alpha: 0.2)
                                                : (user.isAdmin
                                                    ? AppColors.emerald.withValues(alpha: 0.2)
                                                    : AppColors.darkBorder),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            loc.isUrdu ? user.role.labelUr : user.role.labelEn,
                                            style: TextStyle(
                                              fontSize: 10,
                                              fontWeight: FontWeight.bold,
                                              color: user.isSuperAdmin
                                                  ? AppColors.goldLight
                                                  : (user.isAdmin ? AppColors.emeraldLight : Colors.white),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        if (user.isBlocked)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: AppColors.danger.withValues(alpha: 0.2),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: Text(
                                              loc.translate('blocked'),
                                              style: const TextStyle(fontSize: 10, color: AppColors.danger, fontWeight: FontWeight.bold),
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

  Widget _buildUserDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: const TextStyle(color: AppColors.textLightSecondary, fontSize: 12)),
          ),
          Expanded(
            child: Text(value, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
