import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../providers/auth_provider.dart';

class CompleteProfileScreen extends ConsumerStatefulWidget {
  const CompleteProfileScreen({super.key});

  @override
  ConsumerState<CompleteProfileScreen> createState() =>
      _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends ConsumerState<CompleteProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fatherNameController = TextEditingController();
  final _addressController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _fatherNameController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    final currentUser = ref.read(currentUserProvider);
    if (currentUser == null) return;

    setState(() => _isLoading = true);
    try {
      final updated = currentUser.copyWith(
        fatherName: _fatherNameController.text.trim(),
        address: _addressController.text.trim(),
        updatedAt: DateTime.now(),
      );

      await ref.read(authRepositoryProvider).updateUserProfile(updated);

      if (mounted) {
        context.go('/family-tree');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update profile: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final currentUser = ref.watch(currentUserProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('complete_profile_title')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Icon(Icons.account_circle, size: 64, color: AppColors.gold),
                    const SizedBox(height: 16),
                    Text(
                      loc.translate('complete_profile_title'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      loc.translate('complete_profile_desc'),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: AppColors.textLightSecondary, fontSize: 13),
                    ),
                    const SizedBox(height: 24),
                    if (currentUser != null) ...[
                      Text(
                        'Welcome, ${currentUser.name} (${currentUser.email})',
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.emeraldLight),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // Father Name
                    TextFormField(
                      controller: _fatherNameController,
                      decoration: InputDecoration(
                        labelText: loc.translate('father_name'),
                        prefixIcon: const Icon(Icons.escalator_warning),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Father name is required' : null,
                    ),
                    const SizedBox(height: 16),

                    // Address
                    TextFormField(
                      controller: _addressController,
                      decoration: InputDecoration(
                        labelText: loc.translate('address'),
                        prefixIcon: const Icon(Icons.location_on),
                      ),
                      validator: (v) =>
                          (v == null || v.trim().isEmpty) ? 'Address is required' : null,
                    ),
                    const SizedBox(height: 28),

                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleSave,
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                            )
                          : Text(loc.translate('save')),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
