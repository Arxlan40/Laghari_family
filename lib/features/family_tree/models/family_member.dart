/// Represents the alive status of a family member.
/// Note: MUST NOT be a simple boolean because historical data often has unknown status.
enum AliveStatus {
  alive,
  deceased,
  unknown;

  static AliveStatus fromString(String? value) {
    if (value == null) return AliveStatus.unknown;
    switch (value.toLowerCase().trim()) {
      case 'alive':
        return AliveStatus.alive;
      case 'deceased':
        return AliveStatus.deceased;
      case 'unknown':
      default:
        return AliveStatus.unknown;
    }
  }

  String toDbValue() => name;

  String get labelEn {
    switch (this) {
      case AliveStatus.alive:
        return 'Alive';
      case AliveStatus.deceased:
        return 'Deceased';
      case AliveStatus.unknown:
        return 'Status Unknown';
    }
  }

  String get labelUr {
    switch (this) {
      case AliveStatus.alive:
        return 'حیات';
      case AliveStatus.deceased:
        return 'مرحوم';
      case AliveStatus.unknown:
        return 'معلومات نامعلوم';
    }
  }
}

/// Core Family Member model.
///
/// Strictly conforms to the genealogical requirement:
/// - Only [father_id] and [children_ids] define the primary family-tree structure.
/// - NO mother_id or spouse_id.
/// - [alive_status] is a tri-state value ('alive', 'deceased', 'unknown').
class FamilyMember {
  final String id;
  final String nameEn;
  final String nameUr;
  final String? fatherId;
  final String gender; // 'male' or 'female'
  final AliveStatus aliveStatus;
  final int generation;
  final List<String> childrenIds;
  final String imageUrl;
  final String? phoneNumber;
  final String? bloodGroup;
  final String? profession;
  final String? birthDate;
  final String? deathDate;
  final String? notes;
  final String? confidence;
  final String? section;
  final String? lineColor;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const FamilyMember({
    required this.id,
    required this.nameEn,
    required this.nameUr,
    this.fatherId,
    required this.gender,
    required this.aliveStatus,
    required this.generation,
    this.childrenIds = const [],
    this.imageUrl = '',
    this.phoneNumber,
    this.bloodGroup,
    this.profession,
    this.birthDate,
    this.deathDate,
    this.notes,
    this.confidence,
    this.section,
    this.lineColor,
    this.createdAt,
    this.updatedAt,
  });

  bool get isMale => gender.toLowerCase() == 'male';
  bool get isFemale => gender.toLowerCase() == 'female';

  String get displayPhoneNumber =>
      (phoneNumber != null && phoneNumber!.trim().isNotEmpty) ? phoneNumber!.trim() : 'Unknown';
  String get displayBloodGroup =>
      (bloodGroup != null && bloodGroup!.trim().isNotEmpty) ? bloodGroup!.trim() : 'Unknown';
  String get displayProfession =>
      (profession != null && profession!.trim().isNotEmpty) ? profession!.trim() : 'Unknown';

  /// Primary name depending on current locale code ('ur' or 'en')
  String localizedName(String languageCode) {
    if (languageCode == 'ur') {
      return nameUr.isNotEmpty ? nameUr : nameEn;
    }
    return nameEn.isNotEmpty ? nameEn : nameUr;
  }

  /// Secondary name for subtitle display
  String secondaryName(String languageCode) {
    if (languageCode == 'ur') {
      return nameEn;
    }
    return nameUr;
  }

  factory FamilyMember.fromJson(Map<String, dynamic> json) {
    // Parse dates safely
    DateTime? parseDate(dynamic val) {
      if (val == null) return null;
      if (val is DateTime) return val;
      if (val is String) {
        return DateTime.tryParse(val);
      }
      return null;
    }

    // Children ids list
    List<String> parseChildren(dynamic val) {
      if (val == null) return [];
      if (val is List) {
        return val.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList();
      }
      return [];
    }

    // Safe string parser returning null if missing, null or empty
    String? parseString(dynamic val) {
      if (val == null) return null;
      final str = val.toString().trim();
      return str.isEmpty ? null : str;
    }

    return FamilyMember(
      id: (json['id'] ?? '').toString().trim(),
      nameEn: (json['name_en'] ?? json['nameEn'] ?? json['name'] ?? '').toString().trim(),
      nameUr: (json['name_ur'] ?? json['nameUr'] ?? '').toString().trim(),
      fatherId: (json['father_id'] != null && json['father_id'].toString().trim().isNotEmpty)
          ? json['father_id'].toString().trim()
          : (json['fatherId'] != null && json['fatherId'].toString().trim().isNotEmpty)
              ? json['fatherId'].toString().trim()
              : null,
      gender: (json['gender'] ?? 'male').toString().toLowerCase().trim(),
      aliveStatus: AliveStatus.fromString(json['alive_status']?.toString() ?? json['aliveStatus']?.toString()),
      generation: (json['generation'] is int)
          ? json['generation'] as int
          : int.tryParse(json['generation']?.toString() ?? '1') ?? 1,
      childrenIds: parseChildren(json['children_ids'] ?? json['childrenIds']),
      imageUrl: (json['image_url'] ?? json['imageUrl'] ?? '').toString().trim(),
      phoneNumber: parseString(
          json['phoneNumber'] ?? json['phone_number'] ?? json['mobile_number'] ?? json['phone']),
      bloodGroup: parseString(json['bloodGroup'] ?? json['blood_group']),
      profession: parseString(json['profession'] ?? json['occupation']),
      birthDate: json['birth_date']?.toString().trim() ?? json['birthDate']?.toString().trim(),
      deathDate: json['death_date']?.toString().trim() ?? json['deathDate']?.toString().trim(),
      notes: json['notes']?.toString(),
      confidence: json['confidence']?.toString(),
      section: json['section']?.toString(),
      lineColor: json['line_color']?.toString() ?? json['lineColor']?.toString(),
      createdAt: parseDate(json['created_at'] ?? json['createdAt']),
      updatedAt: parseDate(json['updated_at'] ?? json['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name_en': nameEn,
      'name_ur': nameUr,
      'father_id': fatherId,
      'fatherId': fatherId,
      'gender': gender,
      'alive_status': aliveStatus.toDbValue(),
      'generation': generation,
      'children_ids': childrenIds,
      'image_url': imageUrl,
      'phoneNumber': phoneNumber,
      'phone_number': phoneNumber,
      'bloodGroup': bloodGroup,
      'blood_group': bloodGroup,
      'profession': profession,
      'birth_date': birthDate,
      'death_date': deathDate,
      'notes': notes,
      'confidence': confidence,
      'section': section,
      'line_color': lineColor,
      'created_at': createdAt?.toIso8601String(),
      'updated_at': updatedAt?.toIso8601String(),
    };
  }

  FamilyMember copyWith({
    String? id,
    String? nameEn,
    String? nameUr,
    String? fatherId,
    String? gender,
    AliveStatus? aliveStatus,
    int? generation,
    List<String>? childrenIds,
    String? imageUrl,
    String? phoneNumber,
    String? bloodGroup,
    String? profession,
    String? birthDate,
    String? deathDate,
    String? notes,
    String? confidence,
    String? section,
    String? lineColor,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return FamilyMember(
      id: id ?? this.id,
      nameEn: nameEn ?? this.nameEn,
      nameUr: nameUr ?? this.nameUr,
      fatherId: fatherId ?? this.fatherId,
      gender: gender ?? this.gender,
      aliveStatus: aliveStatus ?? this.aliveStatus,
      generation: generation ?? this.generation,
      childrenIds: childrenIds ?? this.childrenIds,
      imageUrl: imageUrl ?? this.imageUrl,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      profession: profession ?? this.profession,
      birthDate: birthDate ?? this.birthDate,
      deathDate: deathDate ?? this.deathDate,
      notes: notes ?? this.notes,
      confidence: confidence ?? this.confidence,
      section: section ?? this.section,
      lineColor: lineColor ?? this.lineColor,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
