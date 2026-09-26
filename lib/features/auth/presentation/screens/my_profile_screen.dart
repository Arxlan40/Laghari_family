import 'dart:convert';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/constants/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/presentation/widgets/app_drawer.dart';
import '../../../storage/services/supabase_storage_service.dart';
import '../../models/user_model.dart';
import '../../providers/auth_provider.dart';

class MyProfileScreen extends ConsumerStatefulWidget {
  const MyProfileScreen({super.key});

  @override
  ConsumerState<MyProfileScreen> createState() => _MyProfileScreenState();
}

class _MyProfileScreenState extends ConsumerState<MyProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _nameController;
  late TextEditingController _fatherNameController;
  late TextEditingController _phoneController;
  late TextEditingController _professionController;
  late TextEditingController _addressController;

  String _profileImageUrl = '';
  String _bloodGroup = 'Unknown';
  String _gender = 'Prefer not to say';
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

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
    'Other',
    'Prefer not to say',
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _fatherNameController = TextEditingController();
    _phoneController = TextEditingController();
    _professionController = TextEditingController();
    _addressController = TextEditingController();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final user = ref.read(currentUserProvider);
    if (user != null && _nameController.text.isEmpty) {
      _nameController.text = user.name;
      _fatherNameController.text = user.fatherName;
      _phoneController.text = user.phone;
      _professionController.text = user.profession;
      _addressController.text = user.address;
      _profileImageUrl = user.profileImageUrl;
      if (_bloodGroupOptions.contains(user.bloodGroup)) {
        _bloodGroup = user.bloodGroup;
      }
      if (_genderOptions.contains(user.gender)) {
        _gender = user.gender;
      }
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _fatherNameController.dispose();
    _phoneController.dispose();
    _professionController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPhoto() async {
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    final loc = AppLocalizations.of(context);
    final user = ref.read(currentUserProvider);
    if (user == null) return;

    final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
    if (result != null && result.files.single.bytes != null) {
      setState(() => _isUploadingPhoto = true);
      try {
        final bytes = result.files.single.bytes!;
        final ext = result.files.single.extension ?? 'jpg';
        final storage = ref.read(supabaseStorageServiceProvider);

        final url = await storage.uploadUserProfileImage(
          userId: user.uid,
          bytes: bytes,
          fileExtension: ext,
        );

        if (mounted) {
          setState(() => _profileImageUrl = url);
        }

        // Persist immediately in Firestore so drawer, app bar, and future launches show it
        final updated = user.copyWith(
          profileImageUrl: url,
          updatedAt: DateTime.now(),
        );
        await ref.read(authRepositoryProvider).saveUserProfile(updated);

        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.emerald,
            content: Text(loc.isUrdu ? 'پروفائل تصویر کامیابی سے محفوظ ہو گئی!' : 'Profile picture updated successfully!'),
          ),
        );
      } catch (e) {
        scaffoldMessenger.showSnackBar(
          SnackBar(
            backgroundColor: AppColors.danger,
            content: Text(
              'Unable to upload profile picture. Please check your internet connection and try again: $e',
            ),
          ),
        );
      } finally {
        if (mounted) setState(() => _isUploadingPhoto = false);
      }
    }
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final user = ref.read(currentUserProvider);
    if (user == null) return;

    setState(() => _isSaving = true);
    final scaffoldMessenger = ScaffoldMessenger.of(context);

    try {
      final updated = UserModel(
        uid: user.uid,
        name: _nameController.text.trim(),
        fatherName: _fatherNameController.text.trim(),
        email: user.email,
        phone: _phoneController.text.trim(),
        bloodGroup: _bloodGroup,
        gender: _gender,
        profession: _professionController.text.trim(),
        address: _addressController.text.trim(),
        profileImageUrl: _profileImageUrl,
        role: user.role,
        status: user.status,
        createdAt: user.createdAt,
        updatedAt: DateTime.now(),
      );

      await ref.read(authRepositoryProvider).saveUserProfile(updated);

      scaffoldMessenger.showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.emerald,
          content: Text('Profile saved successfully!'),
        ),
      );
    } catch (e) {
      scaffoldMessenger.showSnackBar(
        SnackBar(backgroundColor: AppColors.danger, content: Text('Error saving profile: $e')),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = AppLocalizations.of(context);
    final user = ref.watch(currentUserProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(loc.isUrdu ? 'میری پروفائل' : 'My Profile'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined, color: AppColors.gold),
            tooltip: loc.isUrdu ? 'ترتیبات' : 'Settings',
            onPressed: () => context.push('/settings'),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 540),
          child: user == null
              ? const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Avatar Header Card
                        Center(
                          child: Stack(
                            children: [
                              Container(
                                width: 104,
                                height: 104,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: AppColors.gold, width: 2.5),
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.gold.withValues(alpha: 0.3),
                                      blurRadius: 16,
                                    ),
                                  ],
                                ),
                                child: ClipOval(
                                  child: _buildAvatarPreview(_profileImageUrl),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: AppColors.emerald,
                                  child: IconButton(
                                    icon: _isUploadingPhoto
                                        ? const SizedBox(
                                            width: 14,
                                            height: 14,
                                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                          )
                                        : const Icon(Icons.camera_alt, size: 18, color: Colors.white),
                                    onPressed: _isUploadingPhoto ? null : _pickAndUploadPhoto,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),

                        // User email & role chip
                        Center(
                          child: Text(
                            user.email,
                            style: TextStyle(
                              fontSize: 13,
                              color: isDark ? AppColors.textLightSecondary : AppColors.textDarkSecondary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Center(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: user.isAdmin
                                  ? AppColors.gold.withValues(alpha: 0.2)
                                  : AppColors.emerald.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: user.isAdmin ? AppColors.gold : AppColors.emerald,
                                width: 1,
                              ),
                            ),
                            child: Text(
                              user.role.value.toUpperCase().replaceAll('_', ' '),
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: user.isAdmin ? AppColors.gold : AppColors.emerald,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        const Divider(),
                        const SizedBox(height: 16),

                        // Full Name
                        TextFormField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: loc.isUrdu ? 'پورا نام' : 'Full Name',
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Father's Name
                        TextFormField(
                          controller: _fatherNameController,
                          decoration: InputDecoration(
                            labelText: loc.isUrdu ? 'والد کا نام' : "Father's Name",
                            prefixIcon: const Icon(Icons.escalator_warning_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 16),

                        // Gender Selector
                        DropdownButtonFormField<String>(
                          initialValue: _gender,
                          decoration: InputDecoration(
                            labelText: loc.translate('gender'),
                            prefixIcon: const Icon(Icons.person_outline),
                          ),
                          items: _genderOptions.map((g) {
                            String label = g;
                            if (loc.isUrdu) {
                              if (g == 'Male') {
                                label = 'مرد (Male)';
                              } else if (g == 'Female') {
                                label = 'خاتون (Female)';
                              } else if (g == 'Other') {
                                label = 'دیگر (Other)';
                              } else if (g == 'Prefer not to say') {
                                label = 'بتانا پسند نہیں';
                              }
                            }
                            return DropdownMenuItem<String>(
                              value: g,
                              child: Text(label),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _gender = val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Phone Number
                        TextFormField(
                          controller: _phoneController,
                          keyboardType: TextInputType.phone,
                          decoration: InputDecoration(
                            labelText: loc.translate('phone_number'),
                            hintText: '03001234567',
                            prefixIcon: const Icon(Icons.phone_outlined),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Blood Group
                        DropdownButtonFormField<String>(
                          initialValue: _bloodGroup,
                          decoration: InputDecoration(
                            labelText: loc.translate('blood_group'),
                            prefixIcon: const Icon(Icons.bloodtype_outlined, color: AppColors.danger),
                          ),
                          items: _bloodGroupOptions.map((bg) {
                            return DropdownMenuItem<String>(
                              value: bg,
                              child: Text(bg == 'Unknown' && loc.isUrdu ? 'معلوم نہیں (Unknown)' : bg),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) setState(() => _bloodGroup = val);
                          },
                        ),
                        const SizedBox(height: 16),

                        // Profession
                        TextFormField(
                          controller: _professionController,
                          decoration: InputDecoration(
                            labelText: loc.translate('profession'),
                            hintText: loc.isUrdu
                                ? 'مثلاً: سافٹ ویئر انجینئر، ڈاکٹر، کاشتکار'
                                : 'e.g. Software Engineer, Doctor, Farmer...',
                            prefixIcon: const Icon(Icons.work_outline),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Address / City
                        TextFormField(
                          controller: _addressController,
                          decoration: InputDecoration(
                            labelText: loc.isUrdu ? 'موجودہ شہر / رہائش' : 'Current City / Address',
                            prefixIcon: const Icon(Icons.location_on_outlined),
                          ),
                          validator: (v) => (v == null || v.trim().isEmpty) ? 'Required' : null,
                        ),
                        const SizedBox(height: 28),

                        // Save Changes Button
                        ElevatedButton.icon(
                          onPressed: _isSaving ? null : _saveProfile,
                          icon: const Icon(Icons.check_circle_outline),
                          label: _isSaving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                )
                              : Text(loc.isUrdu ? 'محفوظ کریں' : 'Save Profile Changes'),
                        ),
                      ],
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildAvatarPreview(String url) {
    const fallback = 'assets/images/male_avatar.jpg';
    if (url.isEmpty) {
      return Image.asset(fallback, fit: BoxFit.cover, width: 104, height: 104);
    }
    if (url.startsWith('data:image')) {
      try {
        final comma = url.indexOf(',');
        final b64 = comma != -1 ? url.substring(comma + 1) : url;
        return Image.memory(
          base64Decode(b64),
          fit: BoxFit.cover,
          width: 104,
          height: 104,
          errorBuilder: (context, error, stackTrace) => Image.asset(fallback, fit: BoxFit.cover),
        );
      } catch (_) {
        return Image.asset(fallback, fit: BoxFit.cover, width: 104, height: 104);
      }
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: BoxFit.cover,
      width: 104,
      height: 104,
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
      errorWidget: (context, url, error) => Image.asset(fallback, fit: BoxFit.cover),
    );
  }
}
