import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/otp_repository.dart';

class EmailOtpScreen extends ConsumerStatefulWidget {
  final String email;
  final Map<String, dynamic> signupData;

  const EmailOtpScreen({
    super.key,
    required this.email,
    required this.signupData,
  });

  @override
  ConsumerState<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends ConsumerState<EmailOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;

  int _resendCountdown = 60;
  Timer? _countdownTimer;

  @override
  void initState() {
    super.initState();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startCountdown() {
    _resendCountdown = 60;
    _countdownTimer?.cancel();
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
      }
    });
  }

  String get _enteredCode => _controllers.map((c) => c.text).join();

  void _onDigitChanged(int index, String value) {
    setState(() => _errorMessage = null);

    // Handle paste of 6 digits into any box
    if (value.length > 1) {
      final digits = value.replaceAll(RegExp(r'\D'), '');
      for (int i = 0; i < 6 && i < digits.length; i++) {
        _controllers[i].text = digits[i];
      }
      if (digits.length >= 6) {
        _focusNodes[5].requestFocus();
        _verifyCode();
      } else {
        _focusNodes[digits.length].requestFocus();
      }
      return;
    }

    if (value.isNotEmpty) {
      if (index < 5) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
        if (_enteredCode.length == 6) {
          _verifyCode();
        }
      }
    }
  }

  void _onKeyEvent(int index, KeyEvent event) {
    if (event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _controllers[index - 1].clear();
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  Future<void> _verifyCode() async {
    final code = _enteredCode;
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    try {
      final otpRepo = ref.read(otpRepositoryProvider);
      await otpRepo.verifyOtp(email: widget.email, enteredCode: code);

      // Successfully verified! Now complete the account creation in AuthRepository
      final authRepo = ref.read(authRepositoryProvider);
      await authRepo.signUpWithEmail(
        name: (widget.signupData['name'] ?? '').toString(),
        fatherName: (widget.signupData['father_name'] ?? '').toString(),
        email: widget.email,
        password: (widget.signupData['password'] ?? '').toString(),
        address: (widget.signupData['address'] ?? '').toString(),
        phone: (widget.signupData['phone'] ?? '').toString(),
        profileImageUrl: (widget.signupData['profile_image_url'] ?? '').toString(),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            content: Text('Email verified successfully! Welcome to Laghari Family.'),
          ),
        );
        context.go('/family-tree');
      }
    } on OtpException catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.message);
      }
    } catch (e) {
      if (mounted) {
        final rawMsg = e.toString().toLowerCase();
        if (rawMsg.contains('email-already-in-use')) {
          setState(() => _errorMessage = 'This email is already registered. Please login.');
        } else if (rawMsg.contains('network') || rawMsg.contains('offline')) {
          setState(() => _errorMessage = 'Network error. Please check your internet connection.');
        } else {
          setState(() => _errorMessage = 'Verification error: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isVerifying = false);
    }
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0 || _isResending) return;

    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final otpRepo = ref.read(otpRepositoryProvider);
      await otpRepo.sendOtp(
        email: widget.email,
        signupData: widget.signupData,
        force: true,
      );

      _startCountdown();
      for (final c in _controllers) {
        c.clear();
      }
      _focusNodes[0].requestFocus();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            content: Text('A new 6-digit verification code has been sent.'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _errorMessage = e.toString());
      }
    } finally {
      if (mounted) setState(() => _isResending = false);
    }
  }

  void _handleBackToEdit() {
    // Return to signup screen preserving all signup input
    context.pushReplacement('/signup', extra: widget.signupData);
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBackToEdit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(loc.translate('email_otp_title')),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: _handleBackToEdit,
          ),
        ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Email Icon Header Badge
                        Container(
                          width: 80,
                          height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.emerald.withValues(alpha: 0.15),
                            border: Border.all(color: AppColors.emerald, width: 2),
                          ),
                          child: const Icon(
                            Icons.mark_email_read_outlined,
                            color: AppColors.emerald,
                            size: 40,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Title
                        Text(
                          loc.translate('email_otp_title'),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),

                        // Description
                        Text(
                          loc.translate('email_otp_desc'),
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                        const SizedBox(height: 6),

                        // Highlighted Destination Email
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          decoration: BoxDecoration(
                            color: isDark ? AppColors.darkCard : Colors.grey.shade100,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                            ),
                          ),
                          child: Text(
                            widget.email,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: AppColors.gold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Code display & 1-tap auto-fill helper
                        Builder(
                          builder: (context) {
                            final activeOtp = ref.read(otpRepositoryProvider).getActiveOtp(widget.email);
                            if (activeOtp == null) return const SizedBox(height: 12);
                            return Container(
                              margin: const EdgeInsets.only(bottom: 20),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                              decoration: BoxDecoration(
                                color: AppColors.gold.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: AppColors.gold.withValues(alpha: 0.4),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.key, size: 16, color: AppColors.gold),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Code: ${activeOtp.otp}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.gold,
                                      fontSize: 13,
                                      letterSpacing: 2,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  TextButton(
                                    style: TextButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                      backgroundColor: AppColors.gold.withValues(alpha: 0.2),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                      minimumSize: Size.zero,
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    onPressed: () {
                                      for (int i = 0; i < 6 && i < activeOtp.otp.length; i++) {
                                        _controllers[i].text = activeOtp.otp[i];
                                      }
                                      _verifyCode();
                                    },
                                    child: const Text(
                                      'Auto-fill',
                                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.gold),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // 6-digit OTP Box Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: List.generate(6, (index) {
                            return SizedBox(
                              width: 44,
                              height: 54,
                              child: KeyboardListener(
                                focusNode: FocusNode(),
                                onKeyEvent: (event) => _onKeyEvent(index, event),
                                child: TextFormField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.bold,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  decoration: InputDecoration(
                                    contentPadding: EdgeInsets.zero,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide(
                                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: const BorderSide(
                                        color: AppColors.emerald,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  onChanged: (val) => _onDigitChanged(index, val),
                                ),
                              ),
                            );
                          }),
                        ),
                        const SizedBox(height: 16),

                        // Error Message Display
                        if (_errorMessage != null) ...[
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: AppColors.danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              children: [
                                const Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    _errorMessage!,
                                    style: const TextStyle(color: AppColors.danger, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],

                        // Verify & Continue Button
                        SizedBox(
                          width: double.infinity,
                          height: 48,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                              ),
                            ),
                            onPressed: _isVerifying ? null : _verifyCode,
                            child: _isVerifying
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Text(
                                    loc.translate('verify_code'),
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Resend OTP Countdown & Button
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            if (_resendCountdown > 0)
                              Text(
                                '${loc.translate('resend_in')} 00:${_resendCountdown.toString().padLeft(2, '0')}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                                ),
                              )
                            else
                              TextButton.icon(
                                onPressed: _isResending ? null : _resendCode,
                                icon: _isResending
                                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                                    : const Icon(Icons.refresh, size: 16),
                                label: Text(
                                  loc.translate('resend_otp'),
                                  style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.gold),
                                ),
                              ),
                          ],
                        ),
                        const Divider(height: 28),

                        // Back & Edit Details Button
                        TextButton.icon(
                          onPressed: _handleBackToEdit,
                          icon: const Icon(Icons.edit_note, size: 18),
                          label: Text(
                            loc.translate('wrong_email_edit'),
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600,
                              color: AppColors.emerald,
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
