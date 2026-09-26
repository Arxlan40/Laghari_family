import '../../features/family_tree/models/family_member.dart';

class ValidationError {
  final String? id;
  final String message;

  const ValidationError({this.id, required this.message});

  @override
  String toString() => id != null ? '[$id]: $message' : message;
}

class ValidationReport {
  int totalFound = 0;
  int newMembersCount = 0;
  int existingMembersCount = 0;
  int invalidRecordsCount = 0;

  final List<ValidationError> errors = [];
  final List<ValidationError> warnings = [];
  List<FamilyMember> validMembers = [];

  bool get isValid => errors.isEmpty && invalidRecordsCount == 0;
  bool get hasWarnings => warnings.isNotEmpty;

  void addError(String? id, String message) {
    errors.add(ValidationError(id: id, message: message));
  }

  void addWarning(String? id, String message) {
    warnings.add(ValidationError(id: id, message: message));
  }

  String get summaryText {
    return 'Members found: $totalFound\n'
        'New members: $newMembersCount\n'
        'Existing members: $existingMembersCount\n'
        'Invalid records: ${errors.length + invalidRecordsCount}';
  }
}
