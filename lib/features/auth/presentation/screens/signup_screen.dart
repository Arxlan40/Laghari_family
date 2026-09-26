import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/device_info_service.dart';
import '../../../storage/services/supabase_storage_service.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';
import '../widgets/pakistan_phone_field.dart';

class SignupScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic>? initialData;

  const SignupScreen({super.key, this.initialData});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _nameController;
  late final TextEditingController _fatherNameController;
  late final TextEditingController _phoneController;
  late final TextEditingController _emailController;
  late final TextEditingController _passwordController;
  late final TextEditingController _confirmPasswordController;
  late final TextEditingController _professionController;
  late final TextEditingController _addressController;

  final _fatherNameFocus = FocusNode();
  final _phoneFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passwordFocus = FocusNode();
  final _confirmPasswordFocus = FocusNode();
  final _professionFocus = FocusNode();
  final _addressFocus = FocusNode();

  String _profileImageUrl = '';
  String _bloodGroup = 'Unknown';
  String _gender = 'Male';

  static const List<String> _bloodGroupOptions = [
    'A+',
    'A-',
    'B+',
    'B-',
    'AB+',
    'AB-',
    'O+',
    'O-',
    'Unknown',
  ];

  static const List<String> _genderOptions = [
    'Male',
    'Female',
  ];

  bool _isUploadingPicture = false;
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void initState() {
    super.initState();
    final data = widget.initialData;

    _nameController = TextEditingController(text: data?['name']?.toString() ?? '');
    _fatherNameController = TextEditingController(text: data?['father_name']?.toString() ?? '');
    _phoneController = TextEditingController(text: data?['phone']?.toString() ?? '');
    _emailController = TextEditingController(text: data?['email']?.toString() ?? '');
    _passwordController = TextEditingController(text: data?['password']?.toString() ?? '');
    _confirmPasswordController = TextEditingController(text: data?['password']?.toString() ?? '');
    _professionController = TextEditingController(text: (data?['profession'] ?? data?['occupation'])?.toString() ?? '');
    _addressController = TextEditingController(text: data?['address']?.toString() ?? '');
    _profileImageUrl = data?['profile_image_url']?.toString() ?? '';
    _bloodGroup = (data?['bloodGroup'] ?? data?['blood_group'] ?? 'Unknown').toString();
    if (!_bloodGroupOptions.contains(_bloodGroup)) _bloodGroup = 'Unknown';
    _gender = (data?['gender'] ?? 'Male').toString();
    if (!_genderOptions.contains(_gender)) _gender = 'Male';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _professionController.dispose();
    _addressController.dispose();

    _fatherNameFocus.dispose();
    _phoneFocus.dispose();
    _emailFocus.dispose();
    _passwordFocus.dispose();
    _confirmPasswordFocus.dispose();
    _professionFocus.dispose();
    _addressFocus.dispose();
    super.dispose();
  }

  Future<void> _pickProfilePicture() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      setState(() => _isUploadingPicture = true);
      try {
        final bytes = result.files.single.bytes!;
        final ext = result.files.single.extension ?? 'jpg';
        final storage = ref.read(supabaseStorageServiceProvider);
        final url = await storage.uploadUserProfileImage(
          userId: 'signup_${DateTime.now().millisecondsSinceEpoch}',
          bytes: bytes,
          fileExtension: ext,
        );
        setState(() => _profileImageUrl = url);
      } catch (e) {
        if (mounted) {
          _showErrorPopup(
            'Unable to upload profile picture. Please check your internet connection and try again:\n$e',
          );
        }
      } finally {
        if (mounted) setState(() => _isUploadingPicture = false);
      }
    }
  }

  void _showRequiredPopup(List<String> missingItems) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.danger.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_rounded, color: AppColors.danger, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                loc.isUrdu ? 'تمام معلومات لازمی ہیں' : 'All Information Required',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              loc.isUrdu
                  ? 'اکاؤنٹ بنانے کے لیے تصویر اور درج ذیل تمام تفصیلات فراہم کرنا لازمی ہے:'
                  : 'A profile picture and all profile details are mandatory to register:',
              style: TextStyle(
                fontSize: 13.5,
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
              ),
            ),
            const SizedBox(height: 14),
            ...missingItems.map(
              (item) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, size: 16, color: AppColors.danger),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        item,
                        style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('ok')),
          ),
        ],
      ),
    );
  }

  void _showErrorPopup(String message) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            const Icon(Icons.error, color: AppColors.danger, size: 24),
            const SizedBox(width: 10),
            Text(
              loc.isUrdu ? 'خرابی' : 'Registration Error',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
            ),
          ],
        ),
        content: Text(
          message,
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(loc.translate('ok')),
          ),
        ],
      ),
    );
  }

  Future<bool> _promptLocationPermission(bool isUrdu) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? AppColors.darkCard : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.emerald.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.location_on_rounded, color: AppColors.emerald, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                isUrdu ? 'مقام کی رسائی' : 'Location Permission',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
              ),
            ),
          ],
        ),
        content: Text(
          isUrdu
              ? 'مقام کی رسائی کی اجازت دیں تاکہ آپ کا اکاؤنٹ موجودہ مقام کی معلومات محفوظ کر سکے۔'
              : 'Allow location access so your account can store your current location information.',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(
              isUrdu ? 'ابھی نہیں' : 'Not Now',
              style: TextStyle(
                color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.emerald,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              isUrdu ? 'اجازت دیں' : 'Allow',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleDirectSignUp() async {
    final loc = AppLocalizations.of(context);
    final isUrdu = loc.isUrdu;
    final missing = <String>[];

    // 1. Mandatory Profile Picture Check
    if (_profileImageUrl.trim().isEmpty) {
      missing.add(isUrdu ? 'پروفائل تصویر منتخب کریں (لازمی)' : 'Profile Picture (Mandatory)');
    }

    // 2. Full Name Check
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      missing.add(isUrdu ? 'مکمل نام درج کریں' : 'Full Name');
    }

    // 3. Father Name Check
    final fatherName = _fatherNameController.text.trim();
    if (fatherName.isEmpty) {
      missing.add(isUrdu ? 'والد کا نام درج کریں' : "Father's Name");
    }

    // 4. Mobile Number Check
    final phone = _phoneController.text.trim();
    final phoneError = PakistanPhoneField.validatePakistaniNumber(phone);
    if (phoneError != null) {
      missing.add(isUrdu ? 'درست پاکستانی موبائل نمبر (03XX)' : 'Mobile Number: $phoneError');
    }

    // 5. Email Check
    final email = _emailController.text.trim();
    if (email.isEmpty || !email.contains('@') || !email.contains('.')) {
      missing.add(isUrdu ? 'درست ای میل ایڈریس درج کریں' : 'Valid Email Address');
    }

    // 6. Password Check
    final password = _passwordController.text.trim();
    if (password.length < 6) {
      missing.add(isUrdu ? 'پاس ورڈ (کم از کم 6 ہندسے)' : 'Password (minimum 6 characters)');
    }

    // 7. Confirm Password Check
    final confirmPassword = _confirmPasswordController.text.trim();
    if (confirmPassword.isEmpty || confirmPassword != password) {
      missing.add(isUrdu ? 'پاس ورڈ کی تصدیق ایک جیسی نہیں ہے' : 'Passwords do not match');
    }

    // 8. Address Check
    final address = _addressController.text.trim();
    if (address.isEmpty) {
      missing.add(isUrdu ? 'رہائش کا پتہ درج کریں' : 'Address / Residence');
    }

    // If any item is missing, show popup dialog
    if (missing.isNotEmpty) {
      _showRequiredPopup(missing);
      return;
    }

    final allowLocation = await _promptLocationPermission(isUrdu);

    if (!mounted) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);

    try {
      UserLocationInfo? location;
      if (allowLocation) {
        if (DeviceInfoService.cachedDeviceInfo?.location?.latitude != null) {
          location = DeviceInfoService.cachedDeviceInfo!.location;
        } else {
          location = await DeviceInfoService.requestLocationPermissionAndFetch();
        }
      } else {
        location = const UserLocationInfo(permissionStatus: 'not_now');
      }

      final deviceInfo = await DeviceInfoService.collectDeviceInfo(location: location);

      final authRepo = ref.read(authRepositoryProvider);
      final normalizedPhone = PakistanPhoneField.normalizeToFullNumber(phone);

      await authRepo.signUpWithEmail(
        name: name,
        fatherName: fatherName,
        email: email,
        password: password,
        address: address,
        phone: normalizedPhone,
        profileImageUrl: _profileImageUrl,
        bloodGroup: _bloodGroup,
        gender: _gender,
        profession: _professionController.text.trim(),
        deviceInfo: deviceInfo,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: AppColors.emerald,
            behavior: SnackBarBehavior.floating,
            content: Text('Account created successfully! Welcome to Laghari Family.'),
          ),
        );
        context.go('/family-tree');
      }
    } catch (e) {
      if (mounted) {
        final raw = e.toString().toLowerCase();
        if (raw.contains('email-already-in-use')) {
          _showErrorPopup(isUrdu
              ? 'یہ ای میل پہلے سے رجسٹرڈ ہے۔ برائے مہربانی لاگ ان کریں۔'
              : 'This email is already registered. Please log in.');
        } else if (raw.contains('network') || raw.contains('offline')) {
          _showErrorPopup(isUrdu
              ? 'انٹرنیٹ کنکشن کا مسئلہ ہے۔ برائے مہربانی چیک کریں۔'
              : 'Network error. Please check your internet connection.');
        } else {
          _showErrorPopup('Error: $e');
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(loc.translate('create_account')),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 500),
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
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Header Title
                        Text(
                          loc.translate('create_account'),
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: isDark ? AppColors.goldLight : AppColors.emeraldDark,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          loc.isUrdu
                              ? 'لغاری خاندان شجرہ نسب پورٹل میں خوش آمدید'
                              : 'Join the Laghari Clan Ancestral Directory',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        // Mandatory Profile Picture Avatar Picker
                        Center(
                          child: Column(
                            children: [
                              GestureDetector(
                                onTap: _isUploadingPicture ? null : _pickProfilePicture,
                                child: Stack(
                                  children: [
                                    Container(
                                      width: 96,
                                      height: 96,
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _profileImageUrl.isNotEmpty
                                              ? AppColors.emerald
                                              : AppColors.danger,
                                          width: 2.5,
                                        ),
                                      ),
                                      child: ClipOval(
                                        child: _buildSignupAvatarPreview(_profileImageUrl, isDark),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 0,
                                      right: 0,
                                      child: CircleAvatar(
                                        radius: 17,
                                        backgroundColor: _profileImageUrl.isNotEmpty
                                            ? AppColors.emerald
                                            : AppColors.gold,
                                        child: _isUploadingPicture
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                              )
                                            : const Icon(Icons.camera_alt, size: 16, color: Colors.white),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 8),
                              GestureDetector(
                                onTap: _isUploadingPicture ? null : _pickProfilePicture,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _profileImageUrl.isNotEmpty
                                        ? AppColors.emerald.withValues(alpha: 0.12)
                                        : AppColors.danger.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _profileImageUrl.isNotEmpty ? Icons.check_circle : Icons.add_a_photo,
                                        size: 14,
                                        color: _profileImageUrl.isNotEmpty ? AppColors.emerald : AppColors.danger,
                                      ),
                                      const SizedBox(width: 5),
                                      Text(
                                        _profileImageUrl.isNotEmpty
                                            ? (loc.isUrdu ? 'تصویر منتخب ہو گئی ✓' : 'Photo Added ✓')
                                            : (loc.isUrdu ? '* تصویر اپلوڈ کرنا لازمی ہے' : '* Profile Photo (Mandatory)'),
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: _profileImageUrl.isNotEmpty ? AppColors.emerald : AppColors.danger,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 22),

                        // Full Name Field (Mandatory)
                        TextFormField(
                          controller: _nameController,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _fatherNameFocus.requestFocus(),
                          validator: (v) => (v == null || v.trim().isEmpty) ? loc.translate('enter_name') : null,
                          decoration: InputDecoration(
                            labelText: '${loc.translate('full_name')} *',
                            prefixIcon: const Icon(Icons.badge_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Father Name Field (Mandatory)
                        TextFormField(
                          controller: _fatherNameController,
                          focusNode: _fatherNameFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _phoneFocus.requestFocus(),
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (loc.isUrdu ? 'والد کا نام درج کریں' : "Please enter father's name")
                              : null,
                          decoration: InputDecoration(
                            labelText: '${loc.translate('father_name')} *',
                            prefixIcon: const Icon(Icons.people_outline),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Gender Selection Field (Options: Male, Female, Other, Prefer not to say)
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(left: 4, bottom: 6),
                              child: Text(
                                '${loc.translate('gender')} *',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 13,
                                  color: isDark ? Colors.grey[300] : Colors.grey[700],
                                ),
                              ),
                            ),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: _genderOptions.map((g) {
                                final isSelected = _gender == g;
                                String label = g;
                                if (loc.isUrdu) {
                                  if (g == 'Male') {
                                    label = 'مرد';
                                  } else if (g == 'Female') {
                                    label = 'خاتون';
                                  } else if (g == 'Other') {
                                    label = 'دیگر';
                                  } else if (g == 'Prefer not to say') {
                                    label = 'بتانا پسند نہیں';
                                  }
                                }
                                IconData icon;
                                if (g == 'Male') {
                                  icon = Icons.male;
                                } else if (g == 'Female') {
                                  icon = Icons.female;
                                } else {
                                  icon = Icons.person_outline;
                                }

                                return ChoiceChip(
                                  avatar: Icon(
                                    icon,
                                    size: 16,
                                    color: isSelected ? Colors.white : (isDark ? Colors.grey[300] : Colors.grey[700]),
                                  ),
                                  label: Text(label),
                                  selected: isSelected,
                                  selectedColor: AppColors.emerald,
                                  labelStyle: TextStyle(
                                    color: isSelected ? Colors.white : (isDark ? Colors.grey[200] : Colors.black87),
                                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  backgroundColor: isDark ? AppColors.darkSurface : Colors.grey[100],
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: isSelected ? AppColors.emerald : (isDark ? Colors.white12 : Colors.grey[300]!),
                                    ),
                                  ),
                                  onSelected: (val) {
                                    if (val) setState(() => _gender = g);
                                  },
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),

                        // Pakistan Phone Field with +92 prefix (Mandatory)
                        PakistanPhoneField(
                          controller: _phoneController,
                          focusNode: _phoneFocus,
                          nextFocusNode: _emailFocus,
                        ),
                        const SizedBox(height: 14),

                        // Email Field (Mandatory)
                        TextFormField(
                          controller: _emailController,
                          focusNode: _emailFocus,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return loc.translate('enter_email');
                            if (!v.contains('@') || !v.contains('.')) return 'Invalid email address';
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: '${loc.translate('email')} *',
                            prefixIcon: const Icon(Icons.email_outlined),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Password Field (Mandatory)
                        TextFormField(
                          controller: _passwordController,
                          focusNode: _passwordFocus,
                          obscureText: _obscurePassword,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _professionFocus.requestFocus(),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return loc.translate('enter_password');
                            if (v.trim().length < 6) return loc.translate('password_too_short');
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: '${loc.translate('password')} *',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Confirm Password Field (Mandatory)
                        TextFormField(
                          controller: _confirmPasswordController,
                          focusNode: _confirmPasswordFocus,
                          obscureText: _obscureConfirmPassword,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _professionFocus.requestFocus(),
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Please confirm your password';
                            if (v.trim() != _passwordController.text.trim()) return 'Passwords do not match';
                            return null;
                          },
                          decoration: InputDecoration(
                            labelText: '${loc.isUrdu ? 'پاس ورڈ کی تصدیق' : 'Confirm Password'} *',
                            prefixIcon: const Icon(Icons.lock_reset),
                            suffixIcon: IconButton(
                              icon: Icon(_obscureConfirmPassword ? Icons.visibility_off : Icons.visibility),
                              onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                            ),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Blood Group Dropdown
                        DropdownButtonFormField<String>(
                          initialValue: _bloodGroup,
                          decoration: InputDecoration(
                            labelText: loc.translate('blood_group'),
                            prefixIcon: const Icon(Icons.bloodtype_outlined, color: AppColors.danger),
                          ),
                          items: _bloodGroupOptions.map((bg) {
                            return DropdownMenuItem<String>(
                              value: bg,
                              child: Text(
                                bg == 'Unknown' && loc.isUrdu ? 'معلوم نہیں (Unknown)' : bg,
                                style: const TextStyle(fontSize: 14),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _bloodGroup = val);
                          },
                        ),
                        const SizedBox(height: 14),

                        // Profession Field (Free text input)
                        TextFormField(
                          controller: _professionController,
                          focusNode: _professionFocus,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: (_) => _addressFocus.requestFocus(),
                          decoration: InputDecoration(
                            labelText: loc.translate('profession'),
                            hintText: loc.isUrdu
                                ? 'مثلاً: سافٹ ویئر انجینئر، ڈاکٹر، کاشتکار'
                                : 'e.g. Software Engineer, Doctor, Farmer...',
                            prefixIcon: const Icon(Icons.work_outline),
                          ),
                        ),
                        const SizedBox(height: 14),

                        // Address Field (Mandatory)
                        TextFormField(
                          controller: _addressController,
                          focusNode: _addressFocus,
                          textInputAction: TextInputAction.done,
                          maxLines: 2,
                          validator: (v) => (v == null || v.trim().isEmpty)
                              ? (loc.isUrdu ? 'رہائش کا پتہ درج کریں' : 'Please enter your address')
                              : null,
                          decoration: InputDecoration(
                            labelText: '${loc.translate('address')} *',
                            hintText: loc.isUrdu ? 'شہر، گاؤں، ضلع وغیرہ...' : 'City, Village, District...',
                            prefixIcon: const Icon(Icons.home_outlined),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Direct Create Account Button
                        SizedBox(
                          height: 50,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.emerald,
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            onPressed: _isLoading ? null : _handleDirectSignUp,
                            child: _isLoading
                                ? const SizedBox(
                                    width: 22,
                                    height: 22,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  )
                                : Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        loc.isUrdu ? 'اکاؤنٹ بنائیں' : 'Create Account',
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      const SizedBox(width: 8),
                                      const Icon(Icons.check_circle_outline, size: 20),
                                    ],
                                  ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Already have account
                        Center(
                          child: TextButton(
                            onPressed: () => context.go('/login'),
                            child: Text(
                              loc.translate('already_have_account'),
                              style: const TextStyle(color: AppColors.emerald, fontWeight: FontWeight.bold),
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

  Widget _buildSignupAvatarPreview(String url, bool isDark) {
    if (url.isEmpty) {
      return Container(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        child: Center(
          child: Icon(Icons.person, size: 48, color: isDark ? AppColors.gold : AppColors.emerald),
        ),
      );
    }
    if (url.startsWith('data:image')) {
      try {
        final comma = url.indexOf(',');
        final b64 = comma != -1 ? url.substring(comma + 1) : url;
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          width: 96,
          height: 96,
          errorBuilder: (context, error, stackTrace) => Container(
            color: isDark ? AppColors.darkSurface : AppColors.lightCard,
            child: const Center(child: Icon(Icons.person, size: 48, color: AppColors.emerald)),
          ),
        );
      } catch (_) {
        return Container(
          color: isDark ? AppColors.darkSurface : AppColors.lightCard,
          child: const Center(child: Icon(Icons.person, size: 48, color: AppColors.emerald)),
        );
      }
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: 96,
      height: 96,
      placeholder: (context, url) => Container(
        color: AppColors.darkCard,
        child: const Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.emerald),
          ),
        ),
      ),
      errorWidget: (context, url, error) => Container(
        color: isDark ? AppColors.darkSurface : AppColors.lightCard,
        child: const Center(child: Icon(Icons.person, size: 48, color: AppColors.emerald)),
      ),
    );
  }
}
