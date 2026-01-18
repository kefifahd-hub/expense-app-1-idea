import 'package:flutter_test/flutter_test.dart';
import 'package:expense_app/main.dart';

void main() {
  testWidgets('App launches', (WidgetTester tester) async {
    await tester.pumpWidget(const ExpenseApp());

    // Basic sanity check: home title is visible
    expect(find.text('My Expenses'), findsOneWidget);
  });
}
