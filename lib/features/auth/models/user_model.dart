enum UserRole {
  superAdmin('super_admin'),
  admin('admin'),
  user('user');

  final String value;
  const UserRole(this.value);

  static UserRole fromString(String? val) {
    if (val == null) return UserRole.user;
    switch (val.toLowerCase().trim()) {
      case 'super_admin':
        return UserRole.superAdmin;
      case 'admin':
        return UserRole.admin;
      case 'user':
      default:
        return UserRole.user;
    }
  }

  bool get isSuperAdmin => this == UserRole.superAdmin;
  bool get isAdmin => this == UserRole.admin || this == UserRole.superAdmin;
  bool get isNormalUser => this == UserRole.user;

  String get labelEn {
    switch (this) {
      case UserRole.superAdmin:
        return 'Super Admin';
      case UserRole.admin:
        return 'Admin';
      case UserRole.user:
        return 'Member';
    }
  }

  String get labelUr {
    switch (this) {
      case UserRole.superAdmin:
        return 'سپر ایڈمن';
      case UserRole.admin:
        return 'ایڈمن';
      case UserRole.user:
        return 'رکن';
    }
  }
}

enum AccountStatus {
  active('active'),
  blocked('blocked');

  final String value;
  const AccountStatus(this.value);

  static AccountStatus fromString(String? val) {
    if (val == null) return AccountStatus.active;
    switch (val.toLowerCase().trim()) {
      case 'blocked':
        return AccountStatus.blocked;
      case 'active':
      default:
        return AccountStatus.active;
    }
  }

  bool get isBlocked => this == AccountStatus.blocked;
}

class UserModel {
  final String uid;
  final String name;
  final String fatherName;
  final String email;
  final String address;
  final String phone;
  final String profileImageUrl;
  final UserRole role;
  final AccountStatus status;
  final String bloodGroup;
  final String gender;
  final String profession;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const UserModel({
    required this.uid,
    required this.name,
    required this.fatherName,
    required this.email,
    required this.address,
    this.phone = '',
    this.profileImageUrl = '',
    this.role = UserRole.user,
    this.status = AccountStatus.active,
    this.bloodGroup = 'Unknown',
    this.gender = 'Prefer not to say',
    this.profession = '',
    this.createdAt,
    this.updatedAt,
  });

  bool get isSuperAdmin => role.isSuperAdmin;
  bool get isAdmin => role.isAdmin;
  bool get isBlocked => status.isBlocked;

  factory UserModel.fromJson(Map<String, dynamic> json, {String? documentId}) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      // If Firestore Timestamp is present
      try {
        final dynamic t = val;
        if (t.toDate != null) return t.toDate() as DateTime;
      } catch (_) {}
      return null;
    }

    final rawBlood = (json['bloodGroup'] ?? json['blood_group'])?.toString().trim();
    final rawGender = json['gender']?.toString().trim();
    final rawProfession = (json['profession'] ?? json['occupation'])?.toString().trim();

    return UserModel(
      uid: documentId ?? (json['uid'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      fatherName: (json['father_name'] ?? '').toString().trim(),
      email: (json['email'] ?? '').toString().trim(),
      address: (json['address'] ?? '').toString().trim(),
      phone: (json['phone'] ?? '').toString().trim(),
      profileImageUrl: (json['profile_image_url'] ?? '').toString().trim(),
      role: UserRole.fromString(json['role']?.toString()),
      status: AccountStatus.fromString(json['status']?.toString()),
      bloodGroup: (rawBlood != null && rawBlood.isNotEmpty) ? rawBlood : 'Unknown',
      gender: (rawGender != null && rawGender.isNotEmpty) ? rawGender : 'Prefer not to say',
      profession: rawProfession ?? '',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'name': name,
      'father_name': fatherName,
      'email': email,
      'address': address,
      'phone': phone,
      'profile_image_url': profileImageUrl,
      'role': role.value,
      'status': status.value,
      'bloodGroup': bloodGroup,
      'blood_group': bloodGroup,
      'gender': gender,
      'profession': profession,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  UserModel copyWith({
    String? uid,
    String? name,
    String? fatherName,
    String? email,
    String? address,
    String? phone,
    String? profileImageUrl,
    UserRole? role,
    AccountStatus? status,
    String? bloodGroup,
    String? gender,
    String? profession,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return UserModel(
      uid: uid ?? this.uid,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      email: email ?? this.email,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      role: role ?? this.role,
      status: status ?? this.status,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      gender: gender ?? this.gender,
      profession: profession ?? this.profession,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
