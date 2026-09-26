class OtpModel {
  final String email;
  final String otp;
  final DateTime createdAt;
  final DateTime expiresAt;
  final int attempts;
  final int maxAttempts;
  final bool verified;
  final Map<String, dynamic> signupData;

  const OtpModel({
    required this.email,
    required this.otp,
    required this.createdAt,
    required this.expiresAt,
    this.attempts = 0,
    this.maxAttempts = 5,
    this.verified = false,
    this.signupData = const {},
  });

  bool get isExpired => DateTime.now().isAfter(expiresAt);
  bool get hasExceededAttempts => attempts >= maxAttempts;
  bool get isValid => !isExpired && !hasExceededAttempts && !verified;

  factory OtpModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic val, DateTime fallback) {
      if (val == null) return fallback;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val) ?? fallback;
      try {
        final dynamic t = val;
        if (t.toDate != null) return t.toDate() as DateTime;
      } catch (_) {}
      return fallback;
    }

    return OtpModel(
      email: (json['email'] ?? '').toString().trim(),
      otp: (json['otp'] ?? '').toString().trim(),
      createdAt: parseDate(json['created_at'], DateTime.now()),
      expiresAt: parseDate(json['expires_at'], DateTime.now().add(const Duration(minutes: 10))),
      attempts: (json['attempts'] as num?)?.toInt() ?? 0,
      maxAttempts: (json['max_attempts'] as num?)?.toInt() ?? 5,
      verified: json['verified'] == true,
      signupData: (json['signup_data'] as Map<String, dynamic>?) ?? {},
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'otp': otp,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'attempts': attempts,
      'max_attempts': maxAttempts,
      'verified': verified,
      'signup_data': signupData,
    };
  }

  OtpModel copyWith({
    String? email,
    String? otp,
    DateTime? createdAt,
    DateTime? expiresAt,
    int? attempts,
    int? maxAttempts,
    bool? verified,
    Map<String, dynamic>? signupData,
  }) {
    return OtpModel(
      email: email ?? this.email,
      otp: otp ?? this.otp,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      attempts: attempts ?? this.attempts,
      maxAttempts: maxAttempts ?? this.maxAttempts,
      verified: verified ?? this.verified,
      signupData: signupData ?? this.signupData,
    );
  }
}
