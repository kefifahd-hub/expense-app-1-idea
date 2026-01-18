import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/expense_store.dart';

// Mock ExpenseStore for testing (doesn't require database)
class TestExpenseStore extends ExpenseStore {
  @override
  Future<void> loadFromDb() async {
    // Skip database loading in tests
  }
}

void main() {
  group('Expense Model Tests', () {
    test('Create expense with all required fields', () {
      final expense = Expense(
        id: '1',
        date: DateTime(2026, 1, 15),
        vendor: 'Test Vendor',
        category: 'Travel',
        client: 'Test Client',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 100.50,
      );

      expect(expense.id, '1');
      expect(expense.vendor, 'Test Vendor');
      expect(expense.amount, 100.50);
      expect(expense.currency, 'EUR');
      expect(expense.type, 'Business');
      expect(expense.scope, 'Professional');
    });

    test('Expense has correct default values', () {
      final expense = Expense(
        id: '1',
        date: DateTime(2026, 1, 15),
        vendor: 'Test Vendor',
        category: 'Travel',
        client: 'Test Client',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 100.50,
      );

      expect(expense.reimbursable, false);
      expect(expense.reimbursementStatus, 'Not Submitted');
      expect(expense.reimbursedAmountEur, 0);
      expect(expense.reimbursementDate, null);
      expect(expense.receiptPath, null);
    });

    test('Create expense with reimbursement data', () {
      final reimbDate = DateTime(2026, 1, 20);
      final expense = Expense(
        id: '1',
        date: DateTime(2026, 1, 15),
        vendor: 'Hotel XYZ',
        category: 'Hotel',
        client: 'Client A',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 150.00,
        reimbursable: true,
        reimbursementStatus: 'Submitted',
        reimbursedAmountEur: 150.00,
        reimbursementDate: reimbDate,
        reimbursementPayer: 'Company',
        reimbursementReference: 'REF-123',
      );

      expect(expense.reimbursable, true);
      expect(expense.reimbursementStatus, 'Submitted');
      expect(expense.reimbursedAmountEur, 150.00);
      expect(expense.reimbursementDate, reimbDate);
      expect(expense.reimbursementPayer, 'Company');
      expect(expense.reimbursementReference, 'REF-123');
    });
  });

  group('ExpenseStore Tests', () {
    late TestExpenseStore store;

    setUp(() {
      store = TestExpenseStore();
    });

    test('Store initializes with empty list', () {
      expect(store.items, isEmpty);
    });

    test('Add expense to store', () {
      final expense = Expense(
        id: '1',
        date: DateTime(2026, 1, 15),
        vendor: 'Test Vendor',
        category: 'Travel',
        client: 'Client A',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 100.50,
      );

      store.add(expense);

      expect(store.items.length, 1);
      expect(store.items.first.id, '1');
      expect(store.items.first.vendor, 'Test Vendor');
    });

    test('Add multiple expenses to store', () {
      final expense1 = Expense(
        id: '1',
        date: DateTime(2026, 1, 15),
        vendor: 'Vendor 1',
        category: 'Travel',
        client: 'Client A',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 100.00,
      );

      final expense2 = Expense(
        id: '2',
        date: DateTime(2026, 1, 16),
        vendor: 'Vendor 2',
        category: 'Meals',
        client: 'Client B',
        type: 'Business',
        scope: 'Professional',
        currency: 'USD',
        amount: 50.00,
      );

      store.add(expense1);
      store.add(expense2);

      expect(store.items.length, 2);
      expect(store.items[0].id, '2'); // Most recent is first
      expect(store.items[1].id, '1');
    });

    test('Newest expense appears first in list', () {
      final oldExpense = Expense(
        id: '1',
        date: DateTime(2026, 1, 1),
        vendor: 'Old Vendor',
        category: 'Travel',
        client: 'Client A',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 100.00,
      );

      final newExpense = Expense(
        id: '2',
        date: DateTime(2026, 1, 20),
        vendor: 'New Vendor',
        category: 'Meals',
        client: 'Client B',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 50.00,
      );

      store.add(oldExpense);
      store.add(newExpense);

      expect(store.items.first.id, '2');
      expect(store.items.first.vendor, 'New Vendor');
    });

    test('Store notifies listeners when expense is added', () {
      var notified = false;
      store.addListener(() {
        notified = true;
      });

      final expense = Expense(
        id: '1',
        date: DateTime(2026, 1, 15),
        vendor: 'Test',
        category: 'Travel',
        client: 'Client A',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 100.00,
      );

      store.add(expense);

      expect(notified, true);
    });
  });

  group('Business Logic Tests', () {
    test('Calculate pending reimbursement', () {
      final expense = Expense(
        id: '1',
        date: DateTime(2026, 1, 15),
        vendor: 'Hotel',
        category: 'Hotel',
        client: 'Client A',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 200.00,
        reimbursable: true,
        reimbursedAmountEur: 50.00,
      );

      final pending = expense.amount - expense.reimbursedAmountEur;
      expect(pending, 150.00);
    });

    test('Professional scope expense with report', () {
      final expense = Expense(
        id: '1',
        date: DateTime(2026, 1, 15),
        vendor: 'Conference',
        category: 'Travel',
        client: 'Client A',
        type: 'Business',
        scope: 'Professional',
        currency: 'EUR',
        amount: 500.00,
        reportId: 'rep_123',
        reportName: 'January 2026',
      );

      expect(expense.scope, 'Professional');
      expect(expense.reportId, isNotNull);
      expect(expense.reportName, 'January 2026');
    });

    test('Private scope expense without report', () {
      final expense = Expense(
        id: '1',
        date: DateTime(2026, 1, 15),
        vendor: 'Grocery Store',
        category: 'Groceries',
        client: 'Home',
        type: 'Personal',
        scope: 'Private',
        currency: 'EUR',
        amount: 45.00,
      );

      expect(expense.scope, 'Private');
      expect(expense.reportId, isNull);
      expect(expense.reportName, isNull);
    });
  });
}