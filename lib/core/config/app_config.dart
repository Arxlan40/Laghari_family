class AppConfig {
  static const String appName = 'Laghari Family';
  static const String appTagline = 'Genealogy & Ancestral Heritage';
  static const String defaultSuperAdminEmail = 'superadmin@laghari.family';

  // Firestore Collections
  static const String usersCollection = 'users';
  static const String familyMembersCollection = 'family_members';
  static const String editRequestsCollection = 'edit_requests';
  static const String notificationsCollection = 'notifications';
  static const String auditLogsCollection = 'audit_logs';
  static const String settingsCollection = 'settings';

  // Settings Document
  static const String appSettingsDoc = 'app';
  static const String initialImportKey = 'initial_data_imported';
  static const String dataVersionKey = 'data_version';

  // Version & Updates
  static const String appVersion = '1.0.0';
  static const String appConfigCollection = 'app_config';
  static const String versionDoc = 'version';

  // Developer & Links
  static const String developerWebsite = 'https://arsalan-umar-ede98.web.app/';
  static const String officialWebsite = 'https://laghari-family.web.app/';
  static const String privacyPolicyUrl =
      'https://www.termsfeed.com/live/3e2e1b33-50aa-4bb5-912a-a7c9f51a1e6c';

  // Supabase Storage
  static const String supabaseStorageBucket = 'family';
}

