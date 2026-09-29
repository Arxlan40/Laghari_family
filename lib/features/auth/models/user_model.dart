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

class UserLocationInfo {
  final double? latitude;
  final double? longitude;
  final double? accuracy;
  final double? altitude;
  final double? speed;
  final double? heading;
  final DateTime? timestamp;
  final String permissionStatus; // 'granted', 'denied', 'deniedForever', 'unavailable'

  const UserLocationInfo({
    this.latitude,
    this.longitude,
    this.accuracy,
    this.altitude,
    this.speed,
    this.heading,
    this.timestamp,
    this.permissionStatus = 'unavailable',
  });

  bool get hasCoordinates => latitude != null && longitude != null;

  factory UserLocationInfo.fromJson(dynamic val) {
    if (val == null || val is! Map) return const UserLocationInfo();
    final json = Map<String, dynamic>.from(val);

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      try {
        final dynamic t = d;
        if (t.toDate != null) return t.toDate() as DateTime;
      } catch (_) {}
      return null;
    }

    return UserLocationInfo(
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      accuracy: (json['accuracy'] as num?)?.toDouble(),
      altitude: (json['altitude'] as num?)?.toDouble(),
      speed: (json['speed'] as num?)?.toDouble(),
      heading: (json['heading'] as num?)?.toDouble(),
      timestamp: parseDate(json['timestamp']),
      permissionStatus: (json['permissionStatus'] ?? json['permission_status'] ?? 'unavailable').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracy != null) 'accuracy': accuracy,
      if (altitude != null) 'altitude': altitude,
      if (speed != null) 'speed': speed,
      if (heading != null) 'heading': heading,
      if (timestamp != null) 'timestamp': timestamp?.toIso8601String(),
      'permissionStatus': permissionStatus,
    };
  }
}

class UserDeviceInfo {
  final String platform;
  final String manufacturer;
  final String model;
  final String deviceName;
  final String operatingSystem;
  final String operatingSystemVersion;
  final String appVersion;
  final String buildNumber;
  final bool? isPhysicalDevice;
  final DateTime? collectedAt;
  final UserLocationInfo? location;
  final Map<String, dynamic>? extraDetails;

  const UserDeviceInfo({
    this.platform = '',
    this.manufacturer = '',
    this.model = '',
    this.deviceName = '',
    this.operatingSystem = '',
    this.operatingSystemVersion = '',
    this.appVersion = '',
    this.buildNumber = '',
    this.isPhysicalDevice,
    this.collectedAt,
    this.location,
    this.extraDetails,
  });

  factory UserDeviceInfo.fromJson(dynamic val) {
    if (val == null || val is! Map) return const UserDeviceInfo();
    final json = Map<String, dynamic>.from(val);

    DateTime? parseDate(dynamic d) {
      if (d == null) return null;
      if (d is DateTime) return d;
      if (d is String) return DateTime.tryParse(d);
      try {
        final dynamic t = d;
        if (t.toDate != null) return t.toDate() as DateTime;
      } catch (_) {}
      return null;
    }

    return UserDeviceInfo(
      platform: (json['platform'] ?? '').toString(),
      manufacturer: (json['manufacturer'] ?? '').toString(),
      model: (json['model'] ?? '').toString(),
      deviceName: (json['deviceName'] ?? json['device_name'] ?? '').toString(),
      operatingSystem: (json['operatingSystem'] ?? json['operating_system'] ?? '').toString(),
      operatingSystemVersion: (json['operatingSystemVersion'] ?? json['operating_system_version'] ?? '').toString(),
      appVersion: (json['appVersion'] ?? json['app_version'] ?? '').toString(),
      buildNumber: (json['buildNumber'] ?? json['build_number'] ?? '').toString(),
      isPhysicalDevice: json['isPhysicalDevice'] is bool
          ? json['isPhysicalDevice'] as bool
          : (json['is_physical_device'] is bool ? json['is_physical_device'] as bool : null),
      collectedAt: parseDate(json['collectedAt'] ?? json['collected_at']),
      location: json['location'] != null ? UserLocationInfo.fromJson(json['location']) : null,
      extraDetails: json['extraDetails'] is Map ? Map<String, dynamic>.from(json['extraDetails'] as Map) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'platform': platform,
      'manufacturer': manufacturer,
      'model': model,
      'deviceName': deviceName,
      'operatingSystem': operatingSystem,
      'operatingSystemVersion': operatingSystemVersion,
      'appVersion': appVersion,
      'buildNumber': buildNumber,
      if (isPhysicalDevice != null) 'isPhysicalDevice': isPhysicalDevice,
      if (collectedAt != null) 'collectedAt': collectedAt?.toIso8601String(),
      if (location != null) 'location': location?.toJson(),
      if (extraDetails != null) 'extraDetails': extraDetails,
    };
  }

  UserDeviceInfo copyWith({
    String? platform,
    String? manufacturer,
    String? model,
    String? deviceName,
    String? operatingSystem,
    String? operatingSystemVersion,
    String? appVersion,
    String? buildNumber,
    bool? isPhysicalDevice,
    DateTime? collectedAt,
    UserLocationInfo? location,
    Map<String, dynamic>? extraDetails,
  }) {
    return UserDeviceInfo(
      platform: platform ?? this.platform,
      manufacturer: manufacturer ?? this.manufacturer,
      model: model ?? this.model,
      deviceName: deviceName ?? this.deviceName,
      operatingSystem: operatingSystem ?? this.operatingSystem,
      operatingSystemVersion: operatingSystemVersion ?? this.operatingSystemVersion,
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
      isPhysicalDevice: isPhysicalDevice ?? this.isPhysicalDevice,
      collectedAt: collectedAt ?? this.collectedAt,
      location: location ?? this.location,
      extraDetails: extraDetails ?? this.extraDetails,
    );
  }
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
  final UserDeviceInfo? deviceInfo;

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
    this.gender = 'Male',
    this.profession = '',
    this.createdAt,
    this.updatedAt,
    this.deviceInfo,
  });

  bool get isSuperAdmin => role.isSuperAdmin;
  bool get isAdmin => role.isAdmin;
  bool get isBlocked => status.isBlocked;

  /// Gracefully normalizes gender values to strictly 'Male' or 'Female'
  static String normalizeGender(String? val) {
    if (val == null || val.trim().isEmpty) return 'Male';
    final lower = val.trim().toLowerCase();
    if (lower == 'female') return 'Female';
    return 'Male';
  }

  factory UserModel.fromJson(Map<String, dynamic> json, {String? documentId}) {
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
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
      profileImageUrl: (json['profile_image_url'] ??
              json['profileImageUrl'] ??
              json['photoUrl'] ??
              json['photo_url'] ??
              json['imageUrl'] ??
              json['image_url'] ??
              json['avatar'] ??
              '')
          .toString()
          .trim(),
      role: UserRole.fromString(json['role']?.toString()),
      status: AccountStatus.fromString(json['status']?.toString()),
      bloodGroup: (rawBlood != null && rawBlood.isNotEmpty) ? rawBlood : 'Unknown',
      gender: (rawGender != null && rawGender.isNotEmpty) ? normalizeGender(rawGender) : 'Male',
      profession: rawProfession ?? '',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      deviceInfo: json['deviceInfo'] != null
          ? UserDeviceInfo.fromJson(json['deviceInfo'])
          : (json['device_info'] != null ? UserDeviceInfo.fromJson(json['device_info']) : null),
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
      if (deviceInfo != null) 'deviceInfo': deviceInfo?.toJson(),
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
    UserDeviceInfo? deviceInfo,
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
      deviceInfo: deviceInfo ?? this.deviceInfo,
    );
  }
}
