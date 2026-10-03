import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/localization/locale_provider.dart';
import '../../../../core/services/crashlytics_service.dart';
import '../../../../core/services/device_info_service.dart';
import '../../../../core/theme/theme_provider.dart';
import '../../providers/auth_provider.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  Future<void> _handleEmailLogin() async {
    if (_formKey.currentState?.validate() != true) return;

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      final user = await ref.read(authRepositoryProvider).signInWithEmail(
            email: email,
            password: password,
            isAdminLogin: false,
          );
      if (mounted) {
        // Save device details and location to user in Firestore
        final devInfo = DeviceInfoService.cachedDeviceInfo;
        if (devInfo != null) {
          ref.read(authRepositoryProvider).updateUserDeviceInfo(user.uid, devInfo);
        } else {
          DeviceInfoService.collectDeviceInfo().then((info) {
            ref.read(authRepositoryProvider).updateUserDeviceInfo(user.uid, info);
          });
        }

        if (user.isAdmin) {
          context.go('/admin/dashboard');
        } else {
          context.go('/family-tree');
        }
      }
    } catch (e, stack) {
      debugPrint('Login exception: $e\n$stack');
      CrashlyticsService.instance.recordNonFatalError(e, stack, reason: 'Login failed');
      if (mounted) {
        final rawMsg = e.toString().toLowerCase();
        String displayError = 'Login failed. Please check your credentials.';
        if (rawMsg.contains('user-not-found') ||
            rawMsg.contains('wrong-password') ||
            rawMsg.contains('invalid-credential') ||
            rawMsg.contains('invalid-login-credentials')) {
          displayError = 'Incorrect email or password. Please try again.';
        } else if (rawMsg.contains('network') || rawMsg.contains('offline')) {
          displayError = 'Network error: Unable to connect to Firebase. Please verify your internet connection.\n($e)';
        } else if (rawMsg.contains('too-many-requests')) {
          displayError = 'Too many failed attempts. Please wait a moment or reset your password.';
        } else {
          displayError = '$e';
        }

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            behavior: SnackBarBehavior.floating,
            content: Text(displayError),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showForgotPasswordDialog() {
    final loc = AppLocalizations.of(context);
    final resetEmailController = TextEditingController(text: _emailController.text.trim());
    bool isSubmitting = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(loc.translate('reset_password')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                loc.isUrdu
                    ? 'اپنا رجسٹرڈ ای میل درج کریں۔ ہم پاس ورڈ کی بازیابی کا لنک بھیج دیں گے۔'
                    : 'Enter your registered email address and we will send you a password reset link.',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: resetEmailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: loc.translate('email'),
                  prefixIcon: const Icon(Icons.email_outlined),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: isSubmitting ? null : () => Navigator.pop(ctx),
              child: Text(loc.translate('cancel')),
            ),
            ElevatedButton(
              onPressed: isSubmitting
                  ? null
                  : () async {
                      final email = resetEmailController.text.trim();
                      if (email.isEmpty || !email.contains('@')) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter a valid email address.')),
                        );
                        return;
                      }
                      final scaffoldMessenger = ScaffoldMessenger.of(context);
                      setDialogState(() => isSubmitting = true);
                      try {
                        await ref.read(authRepositoryProvider).sendPasswordResetEmail(email);
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            const SnackBar(
                              backgroundColor: AppColors.emerald,
                              content: Text('Password reset link sent to your email.'),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => isSubmitting = false);
                        if (mounted) {
                          scaffoldMessenger.showSnackBar(
                            SnackBar(backgroundColor: AppColors.danger, content: Text('Error: $e')),
                          );
                        }
                      }
                    },
              child: isSubmitting
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(loc.translate('submit')),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                elevation: isDark ? 0 : 8,
                shadowColor: Colors.black26,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                  side: BorderSide(
                    color: isDark ? AppColors.darkBorder : AppColors.gold.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 32),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Top Bar: Theme Toggle & Language Switcher
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            IconButton(
                              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                              icon: Icon(
                                isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                                color: AppColors.gold,
                                size: 22,
                              ),
                              onPressed: () => ref.read(themeModeProvider.notifier).toggleTheme(),
                            ),
                            TextButton.icon(
                              onPressed: () => ref.read(localeProvider.notifier).toggleLanguage(),
                              icon: const Icon(Icons.language, size: 18, color: AppColors.gold),
                              label: Text(
                                loc.isUrdu ? 'English' : 'اردو',
                                style: const TextStyle(color: AppColors.gold, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),

                        // App Crest Logo
                        Center(
                          child: Container(
                            width: 88,
                            height: 88,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: AppColors.gold, width: 2.5),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.gold.withValues(alpha: 0.3),
                                  blurRadius: 20,
                                  spreadRadius: 2,
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child: Image.asset(
                                'assets/images/app_crest.jpg',
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // App Title & Tagline
                        Text(
                          loc.translate('app_name'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                            color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.translate('app_tagline'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                        const SizedBox(height: 28),

                        // Email Input
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _passwordFocusNode.requestFocus(),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your email address.';
                            }
                            if (!val.contains('@') || !val.contains('.')) {
                              return 'Please enter a valid email address.';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: loc.translate('email'),
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Password Input
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocusNode,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) => _handleEmailLogin(),
                          validator: (val) {
                            if (val == null || val.trim().isEmpty) {
                              return 'Please enter your password.';
                            }
                            if (val.length < 6) {
                              return 'Password must be at least 6 characters.';
                            }
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: loc.translate('password'),
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),

                        // Forgot Password Link
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _showForgotPasswordDialog,
                            child: Text(
                              loc.translate('forgot_password'),
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Login Button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isLoading ? null : _handleEmailLogin,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white),
                                  )
                                : Text(
                                    loc.translate('login'),
                                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Sign Up Link
                        Wrap(
                          alignment: WrapAlignment.center,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              loc.translate('dont_have_account'),
                              style: TextStyle(
                                fontSize: 13,
                                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.push('/signup'),
                              child: Text(
                                loc.translate('signup'),
                                style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Discreet Admin Portal Link
                        Center(
                          child: TextButton.icon(
                            onPressed: () => context.push('/admin-login'),
                            icon: const Icon(Icons.shield_outlined, size: 15, color: AppColors.gold),
                            label: Text(
                              loc.translate('admin_login'),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppColors.gold,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
