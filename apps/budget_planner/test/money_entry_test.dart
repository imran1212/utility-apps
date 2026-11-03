import 'package:budget_planner/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('MoneyEntry', () {
    test('serializes and restores an expense without changing its values', () {
      final entry = MoneyEntry(
        id: 'expense-1',
        title: 'Groceries',
        category: 'Food',
        amount: 42.75,
        isIncome: false,
        date: DateTime(2026, 11, 3, 12),
      );

      final restored = MoneyEntry.fromJson(entry.toJson());

      expect(restored.id, entry.id);
      expect(restored.title, entry.title);
      expect(restored.category, entry.category);
      expect(restored.amount, entry.amount);
      expect(restored.isIncome, isFalse);
      expect(restored.date, entry.date);
    });

    test('serializes and restores income entries', () {
      final entry = MoneyEntry(
        id: 'income-1',
        title: 'Salary',
        category: 'Salary',
        amount: 2500,
        isIncome: true,
        date: DateTime(2026, 11, 1),
      );

      final restored = MoneyEntry.fromJson(entry.toJson());

      expect(restored.amount, 2500);
      expect(restored.isIncome, isTrue);
      expect(restored.category, 'Salary');
    });
  });
}
