import 'hamdard_donation.dart';
import 'hamdard_payment_method.dart';
import 'hamdard_person.dart';
import 'hamdard_spending.dart';
import 'hamdard_spending_category.dart';

class HamdardFinancialSummary {
  final int openingBalance;
  final int totalDonations;
  final int totalSpending;
  final int currentBalance;
  final int thisMonthCollection;
  final int thisMonthSpending;
  final int thisYearCollection;
  final int thisYearSpending;
  final int totalDonors;
  final int donorsDonatedThisMonth;
  final int donorsNotDonatedThisMonth;
  final Map<HamdardPaymentMethod, int> paymentMethodDonations;
  final Map<HamdardPaymentMethod, int> paymentMethodSpending;
  final Map<HamdardSpendingCategory, int> categorySpending;

  const HamdardFinancialSummary({
    this.openingBalance = 0,
    this.totalDonations = 0,
    this.totalSpending = 0,
    this.currentBalance = 0,
    this.thisMonthCollection = 0,
    this.thisMonthSpending = 0,
    this.thisYearCollection = 0,
    this.thisYearSpending = 0,
    this.totalDonors = 0,
    this.donorsDonatedThisMonth = 0,
    this.donorsNotDonatedThisMonth = 0,
    this.paymentMethodDonations = const {},
    this.paymentMethodSpending = const {},
    this.categorySpending = const {},
  });

  /// Computes accurate, robust financial summary from raw transactions & people list.
  /// Rule: Current Balance = Opening Balance + Total Donations - Total Spending
  factory HamdardFinancialSummary.compute({
    required int openingBalance,
    required List<HamdardDonation> allDonations,
    required List<HamdardSpending> allSpending,
    required List<HamdardPerson> allPeople,
    DateTime? referenceDate,
  }) {
    final now = referenceDate ?? DateTime.now();
    final currentYear = now.year;
    final currentMonth = now.month;

    int totalDonations = 0;
    int thisMonthCollection = 0;
    int thisYearCollection = 0;
    final Map<HamdardPaymentMethod, int> paymentMethodDonations = {
      for (var method in HamdardPaymentMethod.values) method: 0,
    };

    final Set<String> thisMonthDonorIds = {};

    for (final donation in allDonations) {
      totalDonations += donation.amount;
      paymentMethodDonations[donation.paymentMethod] =
          (paymentMethodDonations[donation.paymentMethod] ?? 0) + donation.amount;

      if (donation.date.year == currentYear) {
        thisYearCollection += donation.amount;
        if (donation.date.month == currentMonth) {
          thisMonthCollection += donation.amount;
          if (donation.personId.isNotEmpty) {
            thisMonthDonorIds.add(donation.personId);
          }
        }
      }
    }

    int totalSpending = 0;
    int thisMonthSpending = 0;
    int thisYearSpending = 0;
    final Map<HamdardPaymentMethod, int> paymentMethodSpending = {
      for (var method in HamdardPaymentMethod.values) method: 0,
    };
    final Map<HamdardSpendingCategory, int> categorySpending = {
      for (var cat in HamdardSpendingCategory.values) cat: 0,
    };

    for (final spend in allSpending) {
      totalSpending += spend.amount;
      paymentMethodSpending[spend.paymentMethod] =
          (paymentMethodSpending[spend.paymentMethod] ?? 0) + spend.amount;
      categorySpending[spend.category] =
          (categorySpending[spend.category] ?? 0) + spend.amount;

      if (spend.date.year == currentYear) {
        thisYearSpending += spend.amount;
        if (spend.date.month == currentMonth) {
          thisMonthSpending += spend.amount;
        }
      }
    }

    final totalDonors = allPeople.length;
    final donorsDonatedThisMonth = thisMonthDonorIds.length;
    final donorsNotDonatedThisMonth =
        (totalDonors - donorsDonatedThisMonth).clamp(0, totalDonors);

    final currentBalance = openingBalance + totalDonations - totalSpending;

    return HamdardFinancialSummary(
      openingBalance: openingBalance,
      totalDonations: totalDonations,
      totalSpending: totalSpending,
      currentBalance: currentBalance,
      thisMonthCollection: thisMonthCollection,
      thisMonthSpending: thisMonthSpending,
      thisYearCollection: thisYearCollection,
      thisYearSpending: thisYearSpending,
      totalDonors: totalDonors,
      donorsDonatedThisMonth: donorsDonatedThisMonth,
      donorsNotDonatedThisMonth: donorsNotDonatedThisMonth,
      paymentMethodDonations: paymentMethodDonations,
      paymentMethodSpending: paymentMethodSpending,
      categorySpending: categorySpending,
    );
  }
}
