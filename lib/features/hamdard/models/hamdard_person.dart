class HamdardPerson {
  final String id;
  final String name;
  final String fatherName;
  final String phoneNumber;
  final String sourceType; // 'family_tree' or 'manual'
  final String? familyMemberId; // Unique UUID of linked FamilyMember, if any
  final String? profileImageUrl; // Cached or direct photo URL
  final String? bloodGroup;
  final String? profession;
  final String? gender;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const HamdardPerson({
    required this.id,
    required this.name,
    required this.fatherName,
    required this.phoneNumber,
    this.sourceType = 'manual',
    this.familyMemberId,
    this.profileImageUrl,
    this.bloodGroup,
    this.profession,
    this.gender,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  bool get isFromFamilyTree =>
      sourceType == 'family_tree' && (familyMemberId != null && familyMemberId!.trim().isNotEmpty);

  /// Normalizes Pakistani phone numbers to standard `03XXXXXXXXX` format for clean matching.
  static String normalizePhone(String? input) {
    if (input == null) return '';
    // Strip non-digits
    String digits = input.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('92') && digits.length >= 12) {
      digits = '0${digits.substring(2)}';
    } else if (digits.length == 10 && digits.startsWith('3')) {
      digits = '0$digits';
    }
    return digits;
  }

  /// Validates standard Pakistani mobile format (e.g. 03001234567, 11 digits starting with 03)
  static bool isValidPakistaniPhone(String? input) {
    final normalized = normalizePhone(input);
    return normalized.length == 11 && normalized.startsWith('03');
  }

  factory HamdardPerson.fromJson(Map<String, dynamic> json, {String? documentId}) {
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

    final rawPhone = (json['phoneNumber'] ?? json['phone_number'] ?? json['phone'])?.toString().trim() ?? '';
    final normalizedPhone = normalizePhone(rawPhone);

    return HamdardPerson(
      id: documentId ?? (json['id'] ?? '').toString(),
      name: (json['name'] ?? '').toString().trim(),
      fatherName: (json['fatherName'] ?? json['father_name'] ?? '').toString().trim(),
      phoneNumber: normalizedPhone.isNotEmpty ? normalizedPhone : rawPhone,
      sourceType: (json['sourceType'] ?? json['source_type'] ?? 'manual').toString(),
      familyMemberId: (json['familyMemberId'] ?? json['family_member_id'])?.toString(),
      profileImageUrl: (json['profileImageUrl'] ?? json['profile_image_url'])?.toString(),
      bloodGroup: (json['bloodGroup'] ?? json['blood_group'])?.toString(),
      profession: json['profession']?.toString(),
      gender: json['gender']?.toString(),
      notes: json['notes']?.toString(),
      createdAt: parseDate(json['createdAt'] ?? json['created_at']),
      updatedAt: parseDate(json['updatedAt'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'father_name': fatherName,
      'fatherName': fatherName,
      'phone_number': phoneNumber,
      'phoneNumber': phoneNumber,
      'source_type': sourceType,
      'sourceType': sourceType,
      if (familyMemberId != null && familyMemberId!.isNotEmpty) ...{
        'family_member_id': familyMemberId,
        'familyMemberId': familyMemberId,
      },
      if (profileImageUrl != null && profileImageUrl!.isNotEmpty) ...{
        'profile_image_url': profileImageUrl,
        'profileImageUrl': profileImageUrl,
      },
      if (bloodGroup != null && bloodGroup!.isNotEmpty) ...{
        'blood_group': bloodGroup,
        'bloodGroup': bloodGroup,
      },
      if (profession != null && profession!.isNotEmpty) 'profession': profession,
      if (gender != null && gender!.isNotEmpty) 'gender': gender,
      if (notes != null && notes!.isNotEmpty) 'notes': notes,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  HamdardPerson copyWith({
    String? id,
    String? name,
    String? fatherName,
    String? phoneNumber,
    String? sourceType,
    String? familyMemberId,
    bool clearFamilyMemberId = false,
    String? profileImageUrl,
    bool clearProfileImageUrl = false,
    String? bloodGroup,
    String? profession,
    String? gender,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return HamdardPerson(
      id: id ?? this.id,
      name: name ?? this.name,
      fatherName: fatherName ?? this.fatherName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      sourceType: sourceType ?? this.sourceType,
      familyMemberId: clearFamilyMemberId ? null : (familyMemberId ?? this.familyMemberId),
      profileImageUrl: clearProfileImageUrl ? null : (profileImageUrl ?? this.profileImageUrl),
      bloodGroup: bloodGroup ?? this.bloodGroup,
      profession: profession ?? this.profession,
      gender: gender ?? this.gender,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
