import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/crashlytics_service.dart';
import '../../providers/auth_provider.dart';

class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => const DeleteAccountDialog(),
    );
  }

  @override
  ConsumerState<DeleteAccountDialog> createState() => _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _isConfirmed = false;
  bool _isDeleting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleDeleteAccount() async {
    setState(() => _errorMessage = null);
    if (!_formKey.currentState!.validate()) return;
    if (!_isConfirmed) {
      setState(() {
        _errorMessage = 'Please check the box confirming you understand this action is permanent.';
      });
      return;
    }

    final loc = AppLocalizations.of(context);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() => _isDeleting = true);

    try {
      CrashlyticsService.instance.log('Account Deletion initiated');
      await ref.read(authRepositoryProvider).deleteUserAccount(
            password: _passwordController.text,
          );

      CrashlyticsService.instance.log('Account Deletion completed successfully');

      if (mounted) {
        Navigator.pop(context); // Close dialog
        context.go('/login'); // Return to login / signup screen

        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(
              loc.isUrdu
                  ? 'آپ کا اکاؤنٹ اور ذاتی ڈیٹا کامیابی کے ساتھ مستقل طور پر حذف کر دیا گیا ہے۔'
                  : 'Your account and personal data have been permanently deleted.',
            ),
          ),
        );
      }
    } catch (e) {
      CrashlyticsService.instance.recordNonFatalError(
        e,
        StackTrace.current,
        reason: 'Account deletion failed',
      );
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceFirst('Exception: ', '');
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AlertDialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.danger.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.warning_amber_rounded, color: AppColors.danger, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isUrdu ? 'اکاؤنٹ مستقل حذف کریں؟' : 'Delete Account?',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ),
        ],
      ),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  isUrdu
                      ? 'اکاؤنٹ حذف کرنے سے آپ کا لاگ ان، موبائل ڈیوائس کی معلومات، نوٹیفیکیشنز اور ذاتی سیٹنگز مستقل طور پر حذف ہو جائیں گی اور یہ عمل واپس نہیں کیا جا سکتا۔'
                      : 'Deleting your account will remove your account and associated personal data according to our data-retention policy.\n\nThis action is permanent and cannot be undone.',
                  style: TextStyle(
                    fontSize: 13.5,
                    height: 1.45,
                    color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                  ),
                ),
                const SizedBox(height: 12),

                // Note clarifying family tree data is preserved
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.gold.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AppColors.gold.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.info_outline, size: 16, color: AppColors.gold),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          isUrdu
                              ? 'نوٹ: خاندانی شجرہ نسب کی تاریخی معلومات محفوظ رہیں گی۔ صرف آپ کا لاگ ان اور ذاتی ڈیٹا حذف ہوگا۔'
                              : 'Note: Historical family-tree records remain preserved. Only your user account, login credentials, and personal data will be deleted.',
                          style: const TextStyle(fontSize: 12, height: 1.4, color: AppColors.gold),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                if (_errorMessage != null) ...[
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: AppColors.danger.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      _errorMessage!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 13),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],

                // Password Verification Field
                Text(
                  isUrdu ? 'تصدیق کے لیے اپنا پاس ورڈ درج کریں:' : 'Enter your password to confirm identity:',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  decoration: InputDecoration(
                    labelText: loc.translate('password'),
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, size: 20),
                      onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return isUrdu ? 'پاس ورڈ درج کرنا ضروری ہے' : 'Password is required to delete account';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Confirmation Checkbox
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: _isConfirmed,
                  onChanged: (val) => setState(() => _isConfirmed = val ?? false),
                  title: Text(
                    isUrdu
                        ? 'میں سمجھتا ہوں کہ میرا اکاؤنٹ مستقل طور پر حذف ہو جائے گا۔'
                        : 'I understand that my account will be permanently deleted.',
                    style: const TextStyle(fontSize: 12.5),
                  ),
                  controlAffinity: ListTileControlAffinity.leading,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isDeleting ? null : () => Navigator.pop(context),
          child: Text(loc.translate('cancel')),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: (_isDeleting || !_isConfirmed) ? null : _handleDeleteAccount,
          child: _isDeleting
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(isUrdu ? 'اکاؤنٹ حذف کریں' : 'Delete Account'),
        ),
      ],
    );
  }
}
