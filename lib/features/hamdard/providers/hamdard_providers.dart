import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../auth/models/user_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../models/hamdard_audit_log.dart';
import '../models/hamdard_donation.dart';
import '../models/hamdard_filter.dart';
import '../models/hamdard_financial_summary.dart';
import '../models/hamdard_person.dart';
import '../models/hamdard_spending.dart';
import '../repositories/hamdard_repository.dart';

final hamdardRepositoryProvider = Provider<HamdardRepository>((ref) {
  FirebaseFirestore? firestore;
  try {
    firestore = FirebaseFirestore.instance;
  } catch (_) {}
  return HamdardRepository(firestore);
});

final hamdardOpeningBalanceStreamProvider = StreamProvider<int>((ref) {
  final repo = ref.watch(hamdardRepositoryProvider);
  return repo.watchOpeningBalance();
});

final hamdardPeopleStreamProvider = StreamProvider<List<HamdardPerson>>((ref) {
  final repo = ref.watch(hamdardRepositoryProvider);
  return repo.watchPeople();
});

final hamdardDonationsStreamProvider = StreamProvider<List<HamdardDonation>>((ref) {
  final repo = ref.watch(hamdardRepositoryProvider);
  return repo.watchDonations();
});

final hamdardSpendingStreamProvider = StreamProvider<List<HamdardSpending>>((ref) {
  final repo = ref.watch(hamdardRepositoryProvider);
  return repo.watchSpending();
});

final hamdardAuditLogsStreamProvider = StreamProvider<List<HamdardAuditLog>>((ref) {
  final repo = ref.watch(hamdardRepositoryProvider);
  return repo.watchAuditLogs();
});

/// Global Date Filter for Hamdard Dashboard & Reports
final hamdardDateFilterProvider = StateProvider<HamdardDateRange>((ref) {
  return HamdardDateRange.forType(HamdardDateFilterType.thisMonth);
});

/// Comprehensive Financial Summary Provider
final hamdardFinancialSummaryProvider = Provider<HamdardFinancialSummary>((ref) {
  final openingBalance = ref.watch(hamdardOpeningBalanceStreamProvider).valueOrNull ?? 0;
  final donations = ref.watch(hamdardDonationsStreamProvider).valueOrNull ?? [];
  final spending = ref.watch(hamdardSpendingStreamProvider).valueOrNull ?? [];
  final people = ref.watch(hamdardPeopleStreamProvider).valueOrNull ?? [];

  return HamdardFinancialSummary.compute(
    openingBalance: openingBalance,
    allDonations: donations,
    allSpending: spending,
    allPeople: people,
  );
});

/// Person with computed donation & assistance totals for person directory & profile
class HamdardPersonStats {
  final HamdardPerson person;
  final int thisMonthTotal;
  final int thisYearTotal;
  final int allTimeTotal;
  final int donationCount;
  final List<HamdardDonation> donations;
  final int totalAssistanceReceived;
  final int assistanceCount;
  final List<HamdardSpending> spendingRecords;

  const HamdardPersonStats({
    required this.person,
    required this.thisMonthTotal,
    required this.thisYearTotal,
    required this.allTimeTotal,
    required this.donationCount,
    required this.donations,
    this.totalAssistanceReceived = 0,
    this.assistanceCount = 0,
    this.spendingRecords = const [],
  });

  bool get isDonor => donationCount > 0;
  bool get isRecipient => assistanceCount > 0;
  bool get isFromFamilyTree => person.isFromFamilyTree;
  double get averageDonation => donationCount > 0 ? (allTimeTotal / donationCount) : 0.0;
}

final hamdardPeopleWithStatsProvider = Provider<List<HamdardPersonStats>>((ref) {
  final people = ref.watch(hamdardPeopleStreamProvider).valueOrNull ?? [];
  final donations = ref.watch(hamdardDonationsStreamProvider).valueOrNull ?? [];
  final spending = ref.watch(hamdardSpendingStreamProvider).valueOrNull ?? [];
  final now = DateTime.now();

  // Group donations by personId
  final Map<String, List<HamdardDonation>> personDonations = {};
  for (final d in donations) {
    personDonations.putIfAbsent(d.personId, () => []).add(d);
  }

  // Group spending by personId or normalized phone number fallback
  final Map<String, List<HamdardSpending>> personSpending = {};
  final Map<String, List<HamdardSpending>> phoneSpending = {};
  for (final s in spending) {
    if (s.personId != null && s.personId!.isNotEmpty) {
      personSpending.putIfAbsent(s.personId!, () => []).add(s);
    }
    final normPhone = HamdardPerson.normalizePhone(s.recipientPhoneNumber);
    if (normPhone.isNotEmpty) {
      phoneSpending.putIfAbsent(normPhone, () => []).add(s);
    }
  }

  return people.map((person) {
    final donorDonations = personDonations[person.id] ?? [];
    int thisMonth = 0;
    int thisYear = 0;
    int allTime = 0;

    for (final d in donorDonations) {
      allTime += d.amount;
      if (d.date.year == now.year) {
        thisYear += d.amount;
        if (d.date.month == now.month) {
          thisMonth += d.amount;
        }
      }
    }

    // Resolve spending records (by personId, or phone match fallback if no personId on legacy spending)
    final matchedSpending = <HamdardSpending>{};
    if (personSpending.containsKey(person.id)) {
      matchedSpending.addAll(personSpending[person.id]!);
    }
    if (person.phoneNumber.isNotEmpty && phoneSpending.containsKey(person.phoneNumber)) {
      for (final s in phoneSpending[person.phoneNumber]!) {
        if (s.personId == null || s.personId!.isEmpty || s.personId == person.id) {
          matchedSpending.add(s);
        }
      }
    }

    final spendingList = matchedSpending.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    int totalAssistance = 0;
    for (final s in spendingList) {
      totalAssistance += s.amount;
    }

    return HamdardPersonStats(
      person: person,
      thisMonthTotal: thisMonth,
      thisYearTotal: thisYear,
      allTimeTotal: allTime,
      donationCount: donorDonations.length,
      donations: donorDonations,
      totalAssistanceReceived: totalAssistance,
      assistanceCount: spendingList.length,
      spendingRecords: spendingList,
    );
  }).toList();
});

/// Filtered donations according to active HamdardDateRange
final hamdardFilteredDonationsProvider = Provider<List<HamdardDonation>>((ref) {
  final all = ref.watch(hamdardDonationsStreamProvider).valueOrNull ?? [];
  final filter = ref.watch(hamdardDateFilterProvider);

  if (filter.type == HamdardDateFilterType.allTime) return all;
  return all.where((d) => filter.contains(d.date)).toList();
});

/// Filtered spending according to active HamdardDateRange
final hamdardFilteredSpendingProvider = Provider<List<HamdardSpending>>((ref) {
  final all = ref.watch(hamdardSpendingStreamProvider).valueOrNull ?? [];
  final filter = ref.watch(hamdardDateFilterProvider);

  if (filter.type == HamdardDateFilterType.allTime) return all;
  return all.where((s) => filter.contains(s.date)).toList();
});

/// Stream of all registered users who have Hamdard Admin permissions
final hamdardAdminsFutureProvider = FutureProvider<List<UserModel>>((ref) async {
  final authRepo = ref.watch(authRepositoryProvider);
  return authRepo.getHamdardAdmins();
});
