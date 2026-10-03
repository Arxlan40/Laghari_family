import 'package:flutter/material.dart';

enum HamdardSpendingCategory {
  medical('medical'),
  education('education'),
  food('food'),
  emergency('emergency'),
  marriage('marriage'),
  funeral('funeral'),
  familyAssistance('family_assistance'),
  other('other');

  final String value;
  const HamdardSpendingCategory(this.value);

  static HamdardSpendingCategory fromString(String? val) {
    if (val == null) return HamdardSpendingCategory.other;
    switch (val.toLowerCase().replaceAll(' ', '_').trim()) {
      case 'medical':
        return HamdardSpendingCategory.medical;
      case 'education':
        return HamdardSpendingCategory.education;
      case 'food':
        return HamdardSpendingCategory.food;
      case 'emergency':
        return HamdardSpendingCategory.emergency;
      case 'marriage':
        return HamdardSpendingCategory.marriage;
      case 'funeral':
        return HamdardSpendingCategory.funeral;
      case 'family_assistance':
      case 'familyassistance':
        return HamdardSpendingCategory.familyAssistance;
      case 'other':
      default:
        return HamdardSpendingCategory.other;
    }
  }

  String get labelEn {
    switch (this) {
      case HamdardSpendingCategory.medical:
        return 'Medical';
      case HamdardSpendingCategory.education:
        return 'Education';
      case HamdardSpendingCategory.food:
        return 'Food';
      case HamdardSpendingCategory.emergency:
        return 'Emergency';
      case HamdardSpendingCategory.marriage:
        return 'Marriage';
      case HamdardSpendingCategory.funeral:
        return 'Funeral';
      case HamdardSpendingCategory.familyAssistance:
        return 'Family Assistance';
      case HamdardSpendingCategory.other:
        return 'Other';
    }
  }

  String get labelUr {
    switch (this) {
      case HamdardSpendingCategory.medical:
        return 'طبی امداد';
      case HamdardSpendingCategory.education:
        return 'تعلیم';
      case HamdardSpendingCategory.food:
        return 'راشن و خوراک';
      case HamdardSpendingCategory.emergency:
        return 'ہنگامی امداد';
      case HamdardSpendingCategory.marriage:
        return 'شادی بیاہ';
      case HamdardSpendingCategory.funeral:
        return 'کفن دفن';
      case HamdardSpendingCategory.familyAssistance:
        return 'خاندانی معاونت';
      case HamdardSpendingCategory.other:
        return 'دیگر';
    }
  }

  String label(bool isUrdu) => isUrdu ? labelUr : labelEn;

  IconData get icon {
    switch (this) {
      case HamdardSpendingCategory.medical:
        return Icons.medical_services_outlined;
      case HamdardSpendingCategory.education:
        return Icons.school_outlined;
      case HamdardSpendingCategory.food:
        return Icons.restaurant_outlined;
      case HamdardSpendingCategory.emergency:
        return Icons.warning_amber_rounded;
      case HamdardSpendingCategory.marriage:
        return Icons.celebration_outlined;
      case HamdardSpendingCategory.funeral:
        return Icons.sentiment_dissatisfied_outlined;
      case HamdardSpendingCategory.familyAssistance:
        return Icons.family_restroom_outlined;
      case HamdardSpendingCategory.other:
        return Icons.category_outlined;
    }
  }

  Color get color {
    switch (this) {
      case HamdardSpendingCategory.medical:
        return const Color(0xFFEF4444); // Red
      case HamdardSpendingCategory.education:
        return const Color(0xFF3B82F6); // Blue
      case HamdardSpendingCategory.food:
        return const Color(0xFF10B981); // Emerald
      case HamdardSpendingCategory.emergency:
        return const Color(0xFFF59E0B); // Amber
      case HamdardSpendingCategory.marriage:
        return const Color(0xFFEC4899); // Pink
      case HamdardSpendingCategory.funeral:
        return const Color(0xFF64748B); // Slate
      case HamdardSpendingCategory.familyAssistance:
        return const Color(0xFF8B5CF6); // Purple
      case HamdardSpendingCategory.other:
        return const Color(0xFF06B6D4); // Cyan
    }
  }
}
