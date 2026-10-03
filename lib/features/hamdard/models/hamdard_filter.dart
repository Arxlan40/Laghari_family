enum HamdardDateFilterType {
  thisMonth,
  lastMonth,
  thisYear,
  lastYear,
  custom,
  allTime;

  String label(bool isUrdu) {
    switch (this) {
      case HamdardDateFilterType.thisMonth:
        return isUrdu ? 'موجودہ مہینہ' : 'This Month';
      case HamdardDateFilterType.lastMonth:
        return isUrdu ? 'پچھلا مہینہ' : 'Last Month';
      case HamdardDateFilterType.thisYear:
        return isUrdu ? 'موجودہ سال' : 'This Year';
      case HamdardDateFilterType.lastYear:
        return isUrdu ? 'پچھلا سال' : 'Last Year';
      case HamdardDateFilterType.custom:
        return isUrdu ? 'مخصوص مدت' : 'Custom Range';
      case HamdardDateFilterType.allTime:
        return isUrdu ? 'کل ریکارڈ' : 'All Time';
    }
  }
}

class HamdardDateRange {
  final HamdardDateFilterType type;
  final DateTime? start;
  final DateTime? end;

  const HamdardDateRange({
    required this.type,
    this.start,
    this.end,
  });

  factory HamdardDateRange.forType(HamdardDateFilterType type, {DateTime? customStart, DateTime? customEnd, DateTime? referenceDate}) {
    final now = referenceDate ?? DateTime.now();

    switch (type) {
      case HamdardDateFilterType.thisMonth:
        final start = DateTime(now.year, now.month, 1);
        final nextMonth = DateTime(now.year, now.month + 1, 1);
        final end = nextMonth.subtract(const Duration(milliseconds: 1));
        return HamdardDateRange(type: type, start: start, end: end);

      case HamdardDateFilterType.lastMonth:
        final prevMonthYear = now.month == 1 ? now.year - 1 : now.year;
        final prevMonth = now.month == 1 ? 12 : now.month - 1;
        final start = DateTime(prevMonthYear, prevMonth, 1);
        final thisMonthStart = DateTime(now.year, now.month, 1);
        final end = thisMonthStart.subtract(const Duration(milliseconds: 1));
        return HamdardDateRange(type: type, start: start, end: end);

      case HamdardDateFilterType.thisYear:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return HamdardDateRange(type: type, start: start, end: end);

      case HamdardDateFilterType.lastYear:
        final start = DateTime(now.year - 1, 1, 1);
        final end = DateTime(now.year - 1, 12, 31, 23, 59, 59, 999);
        return HamdardDateRange(type: type, start: start, end: end);

      case HamdardDateFilterType.custom:
        final s = customStart != null ? DateTime(customStart.year, customStart.month, customStart.day, 0, 0, 0) : null;
        final e = customEnd != null ? DateTime(customEnd.year, customEnd.month, customEnd.day, 23, 59, 59, 999) : null;
        return HamdardDateRange(type: type, start: s, end: e);

      case HamdardDateFilterType.allTime:
        return const HamdardDateRange(type: HamdardDateFilterType.allTime, start: null, end: null);
    }
  }

  bool contains(DateTime date) {
    if (start != null && date.isBefore(start!)) return false;
    if (end != null && date.isAfter(end!)) return false;
    return true;
  }
}
