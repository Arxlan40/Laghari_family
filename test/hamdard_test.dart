import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:laghari_family/features/auth/models/user_model.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_donation.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_financial_summary.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_payment_method.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_person.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_spending.dart';
import 'package:laghari_family/features/hamdard/models/hamdard_spending_category.dart';
import 'package:laghari_family/features/hamdard/repositories/hamdard_repository.dart';
import 'package:laghari_family/features/hamdard/services/hamdard_csv_service.dart';
import 'package:laghari_family/features/hamdard/services/hamdard_pdf_service.dart';

void main() {
  group('1. Role & Permission Tests', () {
    test('Normal User: can view, but cannot manage Hamdard, assign roles, or view audit', () {
      const user = UserModel(
        uid: 'user_1',
        name: 'User One',
        fatherName: 'Father',
        email: 'user1@example.com',
        address: 'Sukkur',
        role: UserRole.user,
        isHamdardAdmin: false,
      );

      expect(user.isAdmin, isFalse);
      expect(user.isSuperAdmin, isFalse);
      expect(user.isHamdardAdmin, isFalse);
      expect(user.canManageHamdard, isFalse);
      expect(user.canAssignHamdardAdmins, isFalse);
      expect(user.canViewHamdardAudit, isFalse);
    });

    test('Normal Admin: does NOT have Hamdard management rights by default', () {
      const admin = UserModel(
        uid: 'admin_1',
        name: 'Admin One',
        fatherName: 'Father',
        email: 'admin1@example.com',
        address: 'Hyderabad',
        role: UserRole.admin,
        isHamdardAdmin: false,
      );

      expect(admin.isAdmin, isTrue);
      expect(admin.isSuperAdmin, isFalse);
      expect(admin.isHamdardAdmin, isFalse);
      expect(admin.canManageHamdard, isFalse); // Independent permissions!
      expect(admin.canAssignHamdardAdmins, isFalse);
      expect(admin.canViewHamdardAudit, isFalse);
    });

    test('Hamdard Admin (Member + Hamdard Admin): can manage Hamdard, but cannot assign roles or view audit', () {
      const hamdardAdmin = UserModel(
        uid: 'h_admin_1',
        name: 'Hamdard Admin One',
        fatherName: 'Father',
        email: 'hamdard1@example.com',
        address: 'Karachi',
        role: UserRole.user,
        isHamdardAdmin: true,
      );

      expect(hamdardAdmin.isAdmin, isFalse);
      expect(hamdardAdmin.isSuperAdmin, isFalse);
      expect(hamdardAdmin.isHamdardAdmin, isTrue);
      expect(hamdardAdmin.canManageHamdard, isTrue);
      expect(hamdardAdmin.canAssignHamdardAdmins, isFalse);
      expect(hamdardAdmin.canViewHamdardAudit, isFalse);
    });

    test('Admin + Hamdard Admin: additive role retains normal Admin and grants Hamdard permissions', () {
      const dualAdmin = UserModel(
        uid: 'dual_admin_1',
        name: 'Dual Admin',
        fatherName: 'Father',
        email: 'dual@example.com',
        address: 'Larkana',
        role: UserRole.admin,
        isHamdardAdmin: true,
      );

      expect(dualAdmin.isAdmin, isTrue);
      expect(dualAdmin.isSuperAdmin, isFalse);
      expect(dualAdmin.isHamdardAdmin, isTrue);
      expect(dualAdmin.canManageHamdard, isTrue);
      expect(dualAdmin.canAssignHamdardAdmins, isFalse); // Super Admin only
      expect(dualAdmin.canViewHamdardAudit, isFalse); // Super Admin only
    });

    test('Super Admin: automatically possesses all permissions across both systems', () {
      const superAdmin = UserModel(
        uid: 'super_admin_1',
        name: 'Super Admin',
        fatherName: 'Father',
        email: 'super@example.com',
        address: 'Islamabad',
        role: UserRole.superAdmin,
        isHamdardAdmin: false, // Automatically granted through isSuperAdmin
      );

      expect(superAdmin.isAdmin, isTrue);
      expect(superAdmin.isSuperAdmin, isTrue);
      expect(superAdmin.canManageHamdard, isTrue);
      expect(superAdmin.canAssignHamdardAdmins, isTrue);
      expect(superAdmin.canViewHamdardAudit, isTrue);
    });

    test('Blocked user: cannot manage Hamdard even if previously designated Hamdard Admin', () {
      const blockedHamdardAdmin = UserModel(
        uid: 'blocked_1',
        name: 'Blocked User',
        fatherName: 'Father',
        email: 'blocked@example.com',
        address: 'City',
        role: UserRole.user,
        status: AccountStatus.blocked,
        isHamdardAdmin: true,
      );

      expect(blockedHamdardAdmin.isBlocked, isTrue);
      expect(blockedHamdardAdmin.canManageHamdard, isFalse);
    });

    test('Additive Role Assignment: assigning and removing Hamdard Admin preserves base user role', () {
      const originalAdmin = UserModel(
        uid: 'test_u1',
        name: 'Admin Tariq',
        fatherName: 'Tariq',
        email: 'tariq@example.com',
        address: 'Dadu',
        role: UserRole.admin,
        isHamdardAdmin: false,
      );

      // Add Hamdard Admin
      final granted = originalAdmin.copyWith(
        isHamdardAdmin: true,
        hamdardAdminAssignedAt: DateTime(2026, 10, 1),
        hamdardAdminAssignedBy: 'super_1',
        hamdardAdminAssignedByName: 'Super Admin',
      );
      expect(granted.role, UserRole.admin); // Preserved!
      expect(granted.isHamdardAdmin, isTrue);
      expect(granted.canManageHamdard, isTrue);

      // Remove Hamdard Admin
      final revoked = granted.copyWith(
        isHamdardAdmin: false,
        hamdardAdminAssignedAt: null,
      );
      expect(revoked.role, UserRole.admin); // Still an Admin!
      expect(revoked.isHamdardAdmin, isFalse);
      expect(revoked.canManageHamdard, isFalse);
    });
  });

  group('2. Financial Calculations & Accounting Tests', () {
    test('Current Balance = Opening Balance + Donations - Spending', () {
      final summary = HamdardFinancialSummary.compute(
        openingBalance: 50000,
        allDonations: [
          HamdardDonation(
            id: 'd1',
            personId: 'p1',
            personNameSnapshot: 'Ali',
            fatherNameSnapshot: 'Khan',
            phoneNumberSnapshot: '03001111111',
            amount: 70000,
            paymentMethod: HamdardPaymentMethod.jazzCash,
            date: DateTime(2026, 10, 1),
          ),
          HamdardDonation(
            id: 'd2',
            personId: 'p2',
            personNameSnapshot: 'Bilal',
            fatherNameSnapshot: 'Khan',
            phoneNumberSnapshot: '03002222222',
            amount: 50000,
            paymentMethod: HamdardPaymentMethod.easypaisa,
            date: DateTime(2026, 10, 2),
          ),
        ],
        allSpending: [
          HamdardSpending(
            id: 's1',
            recipientName: 'Rasheed',
            recipientFatherName: 'Khan',
            recipientPhoneNumber: '03003333333',
            amount: 80000,
            date: DateTime(2026, 10, 3),
            paymentMethod: HamdardPaymentMethod.bankTransfer,
            category: HamdardSpendingCategory.medical,
          ),
        ],
        allPeople: [
          const HamdardPerson(id: 'p1', name: 'Ali', fatherName: 'Khan', phoneNumber: '03001111111'),
          const HamdardPerson(id: 'p2', name: 'Bilal', fatherName: 'Khan', phoneNumber: '03002222222'),
          const HamdardPerson(id: 'p3', name: 'Zahid', fatherName: 'Khan', phoneNumber: '03004444444'),
        ],
        referenceDate: DateTime(2026, 10, 15),
      );

      expect(summary.openingBalance, 50000);
      expect(summary.totalDonations, 120000);
      expect(summary.totalSpending, 80000);
      // 50,000 + 120,000 - 80,000 = 90,000
      expect(summary.currentBalance, 90000);

      // This Month
      expect(summary.thisMonthCollection, 120000);
      expect(summary.thisMonthSpending, 80000);

      // Participation counts
      expect(summary.totalDonors, 3);
      expect(summary.donorsDonatedThisMonth, 2);
      expect(summary.donorsNotDonatedThisMonth, 1);

      // Payment method breakdown
      expect(summary.paymentMethodDonations[HamdardPaymentMethod.jazzCash], 70000);
      expect(summary.paymentMethodDonations[HamdardPaymentMethod.easypaisa], 50000);
      expect(summary.paymentMethodDonations[HamdardPaymentMethod.cash], 0);

      // Category breakdown
      expect(summary.categorySpending[HamdardSpendingCategory.medical], 80000);
      expect(summary.categorySpending[HamdardSpendingCategory.education], 0);
    });

    test('Accurate PKR formatting with currency symbols and thousand separators', () {
      expect(HamdardRepository.formatPkr(5000), 'Rs. 5,000');
      expect(HamdardRepository.formatPkr(1250000), 'Rs. 1,250,000');
      expect(HamdardRepository.formatPkr(0), 'Rs. 0');
      expect(HamdardRepository.formatPkr(-2500), '-Rs. 2,500');
    });

    test('Calendar year boundary: Jan 1 to Dec 31 calculates correctly', () {
      final summary = HamdardFinancialSummary.compute(
        openingBalance: 10000,
        allDonations: [
          HamdardDonation(
            id: 'd_last_year',
            personId: 'p1',
            personNameSnapshot: 'Person',
            fatherNameSnapshot: 'Father',
            phoneNumberSnapshot: '03001234567',
            amount: 25000,
            paymentMethod: HamdardPaymentMethod.cash,
            date: DateTime(2025, 12, 31, 23, 59),
          ),
          HamdardDonation(
            id: 'd_this_year',
            personId: 'p1',
            personNameSnapshot: 'Person',
            fatherNameSnapshot: 'Father',
            phoneNumberSnapshot: '03001234567',
            amount: 40000,
            paymentMethod: HamdardPaymentMethod.cash,
            date: DateTime(2026, 1, 1, 10, 0),
          ),
        ],
        allSpending: [],
        allPeople: [],
        referenceDate: DateTime(2026, 5, 20),
      );

      expect(summary.totalDonations, 65000);
      expect(summary.thisYearCollection, 40000); // Only 2026
      expect(summary.currentBalance, 75000);
    });
  });

  group('3. Donation CRUD & Audit Trail Tests', () {
    test('Add, Edit, and Delete donations correctly maintain in-memory audit logs', () async {
      final repo = HamdardRepository();

      // 1. Add Donation
      final donation = HamdardDonation(
        id: 'don_101',
        personId: 'person_001',
        personNameSnapshot: 'Muhammad Khan',
        fatherNameSnapshot: 'Ahmed Khan',
        phoneNumberSnapshot: '03001234567',
        amount: 5000,
        paymentMethod: HamdardPaymentMethod.jazzCash,
        date: DateTime(2026, 10, 3),
        description: 'Monthly assistance fund',
      );

      final added = await repo.addDonation(
        donation,
        performedBy: 'admin_uid',
        performedByName: 'Hamdard Admin',
      );
      expect(added.id, 'don_101');
      expect((await repo.getDonations()).length, 1);

      var logs = await repo.watchAuditLogs().first;
      expect(logs.length, 1);
      expect(logs.first.action, 'created_donation');
      expect(logs.first.newData?['amount'], 5000);

      // 2. Edit Donation (amount changed 5000 -> 3000, payment method JazzCash -> Cash)
      final edited = added.copyWith(
        amount: 3000,
        paymentMethod: HamdardPaymentMethod.cash,
      );

      await repo.editDonation(
        edited,
        added,
        performedBy: 'admin_uid',
        performedByName: 'Hamdard Admin',
      );

      final listAfterEdit = await repo.getDonations();
      expect(listAfterEdit.first.amount, 3000);
      expect(listAfterEdit.first.paymentMethod, HamdardPaymentMethod.cash);

      logs = await repo.watchAuditLogs().first;
      expect(logs.length, 2);
      expect(logs.first.action, 'edited_donation');
      expect(logs.first.oldData?['amount'], 5000);
      expect(logs.first.newData?['amount'], 3000);

      // 3. Delete Donation
      await repo.deleteDonation(
        edited,
        performedBy: 'admin_uid',
        performedByName: 'Hamdard Admin',
      );

      expect((await repo.getDonations()).isEmpty, isTrue);
      logs = await repo.watchAuditLogs().first;
      expect(logs.length, 3);
      expect(logs.first.action, 'deleted_donation');
      expect(logs.first.oldData?['amount'], 3000);
    });

    test('Multiple donations in the same month for same donor calculate cumulative total', () {
      final d1 = HamdardDonation(
        id: '1',
        personId: 'p1',
        personNameSnapshot: 'Kamran',
        fatherNameSnapshot: 'Aslam',
        phoneNumberSnapshot: '03001234567',
        amount: 3000,
        paymentMethod: HamdardPaymentMethod.cash,
        date: DateTime(2026, 10, 5),
      );
      final d2 = HamdardDonation(
        id: '2',
        personId: 'p1',
        personNameSnapshot: 'Kamran',
        fatherNameSnapshot: 'Aslam',
        phoneNumberSnapshot: '03001234567',
        amount: 7000,
        paymentMethod: HamdardPaymentMethod.bankTransfer,
        date: DateTime(2026, 10, 20),
      );

      final summary = HamdardFinancialSummary.compute(
        openingBalance: 0,
        allDonations: [d1, d2],
        allSpending: [],
        allPeople: [const HamdardPerson(id: 'p1', name: 'Kamran', fatherName: 'Aslam', phoneNumber: '03001234567')],
        referenceDate: DateTime(2026, 10, 25),
      );

      expect(summary.totalDonations, 10000);
      expect(summary.thisMonthCollection, 10000);
      expect(summary.donorsDonatedThisMonth, 1); // Single distinct donor
    });
  });

  group('4. Spending CRUD & Category Tests', () {
    test('Add, Edit, and Delete spending correctly logs audit records', () async {
      final repo = HamdardRepository();

      final spending = HamdardSpending(
        id: 'sp_101',
        recipientName: 'Ghulam Qadir',
        recipientFatherName: 'Nabi Bux',
        recipientPhoneNumber: '03123456789',
        amount: 25000,
        date: DateTime(2026, 10, 2),
        paymentMethod: HamdardPaymentMethod.easypaisa,
        category: HamdardSpendingCategory.education,
        description: 'Semester tuition fees aid',
      );

      // Add
      await repo.addSpending(spending, performedBy: 'h_admin', performedByName: 'Hamdard Admin');
      expect((await repo.getSpending()).length, 1);

      var logs = await repo.watchAuditLogs().first;
      expect(logs.first.action, 'created_spending');
      expect(logs.first.newData?['category'], 'education');

      // Edit (25,000 -> 20,000)
      final edited = spending.copyWith(amount: 20000);
      await repo.editSpending(edited, spending, performedBy: 'h_admin', performedByName: 'Hamdard Admin');
      expect((await repo.getSpending()).first.amount, 20000);

      // Delete
      await repo.deleteSpending(edited, performedBy: 'h_admin', performedByName: 'Hamdard Admin');
      expect((await repo.getSpending()).isEmpty, isTrue);
    });

    test('All 8 Predefined Categories are valid and cannot be altered', () {
      expect(HamdardSpendingCategory.values.length, 8);
      expect(HamdardSpendingCategory.medical.labelEn, 'Medical');
      expect(HamdardSpendingCategory.education.labelEn, 'Education');
      expect(HamdardSpendingCategory.food.labelEn, 'Food');
      expect(HamdardSpendingCategory.emergency.labelEn, 'Emergency');
      expect(HamdardSpendingCategory.marriage.labelEn, 'Marriage');
      expect(HamdardSpendingCategory.funeral.labelEn, 'Funeral');
      expect(HamdardSpendingCategory.familyAssistance.labelEn, 'Family Assistance');
      expect(HamdardSpendingCategory.other.labelEn, 'Other');
    });
  });

  group('5. JSON Import & Duplicate Prevention Tests', () {
    test('Import rejects duplicates by phone number and adds new people without tree linkage', () async {
      final repo = HamdardRepository();

      // Pre-seed an existing person
      await repo.savePerson(
        const HamdardPerson(
          id: 'existing_1',
          name: 'Muhammad Khan',
          fatherName: 'Ahmed Khan',
          phoneNumber: '03001234567',
        ),
        performedBy: 'super_admin',
        performedByName: 'Super Admin',
      );

      final jsonToImport = jsonEncode([
        {
          "name": "Muhammad Khan",
          "fatherName": "Ahmed Khan",
          "phoneNumber": "03001234567", // duplicate!
        },
        {
          "name": "Ali Khan",
          "fatherName": "Umar Khan",
          "phoneNumber": "+92 311 1234567", // new!
        },
        {
          "name": "Invalid Person",
          "fatherName": "No Phone",
          "phoneNumber": "", // invalid!
        },
      ]);

      final summary = await repo.importPeopleFromJson(
        jsonToImport,
        performedBy: 'super_admin',
        performedByName: 'Super Admin',
      );

      expect(summary.totalRecords, 3);
      expect(summary.newAdded, 1);
      expect(summary.alreadyExisted, 1);
      expect(summary.invalidRecords, 1);

      final people = await repo.getPeople();
      expect(people.length, 2); // 1 pre-existing + 1 new
      expect(people.any((p) => p.name == 'Ali Khan'), isTrue);
    });

    test('Backup export generates complete JSON without leaking tokens', () async {
      final repo = HamdardRepository();
      await repo.setOpeningBalance(15000, performedBy: 'super', performedByName: 'Super');
      await repo.savePerson(
        const HamdardPerson(id: 'p1', name: 'Zain', fatherName: 'Abid', phoneNumber: '03009999999'),
        performedBy: 'super',
        performedByName: 'Super',
      );

      final backupStr = await repo.exportBackupJson();
      final decoded = jsonDecode(backupStr) as Map<String, dynamic>;

      expect(decoded['version'], '1.0');
      expect(decoded['opening_balance'], 15000);
      expect((decoded['people'] as List).length, 1);
      expect(backupStr.contains('password'), isFalse);
      expect(backupStr.contains('fcm_token'), isFalse);
    });
  });

  group('6. CSV & PDF Export Tests', () {
    test('CSV generator formats rows with RFC 4180 escaping for quotes and commas', () {
      final csv = HamdardCsvService.generateCsv(
        donations: [
          HamdardDonation(
            id: 'd1',
            personId: 'p1',
            personNameSnapshot: 'Khan, Muhammad',
            fatherNameSnapshot: 'Umar "Elder" Khan',
            phoneNumberSnapshot: '03001112222',
            amount: 5000,
            paymentMethod: HamdardPaymentMethod.cash,
            date: DateTime(2026, 10, 3, 14, 30),
            description: 'Note with\nnewline',
          ),
        ],
        spending: [
          HamdardSpending(
            id: 's1',
            recipientName: 'Recipient Name',
            recipientFatherName: 'Recipient Father',
            recipientPhoneNumber: '03003334444',
            amount: 3000,
            date: DateTime(2026, 10, 2, 10, 0),
            paymentMethod: HamdardPaymentMethod.easypaisa,
            category: HamdardSpendingCategory.medical,
            description: 'Medical support',
          ),
        ],
      );

      expect(csv.contains('Date,Type,Person/Recipient'), isTrue);
      // Escaped quotes: ""Elder""
      expect(csv.contains('"Umar ""Elder"" Khan"'), isTrue);
      // Escaped comma in name
      expect(csv.contains('"Khan, Muhammad"'), isTrue);
      // Both donation and spending present
      expect(csv.contains('Donation'), isTrue);
      expect(csv.contains('Spending'), isTrue);
    });

    test('PDF generator compiles valid document bytes', () async {
      final summary = HamdardFinancialSummary(
        openingBalance: 10000,
        totalDonations: 50000,
        totalSpending: 20000,
        currentBalance: 40000,
      );

      final bytes = await HamdardPdfService.generatePdfBytes(
        periodTitle: 'October 2026',
        summary: summary,
        donations: [],
        spending: [],
        donorStats: [],
      );

      expect(bytes, isNotEmpty);
      // PDF documents start with %PDF header
      final header = String.fromCharCodes(bytes.take(4));
      expect(header, '%PDF');
    });
  });
}
