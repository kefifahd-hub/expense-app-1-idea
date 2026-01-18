import 'expense_store.dart';
import 'add_expense_screen.dart';
import 'package:flutter/material.dart';
import 'expense_detail_screen.dart';
import 'reports_screen.dart';

void main() {
  runApp(const ExpenseApp());
}

class ExpenseApp extends StatelessWidget {
  const ExpenseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Expense Tracker',
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.indigo,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    expenseStore.loadFromDb().then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
  title: const Text('My Expenses'),
  actions: [
    IconButton(
      icon: const Icon(Icons.insert_drive_file),
      onPressed: () async {
        await Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const ReportsScreen()),
        );
      },
    )
  ],
),

      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: expenseStore,
              builder: (context, _) {
                if (expenseStore.items.isEmpty) {
                  return const Center(
                    child: Text(
                      'No expenses yet',
                      style: TextStyle(fontSize: 18),
                    ),
                  );
                }

                return ListView.separated(
                  itemCount: expenseStore.items.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final e = expenseStore.items[index];
                    final dateStr =
                        "${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}";

                    return ListTile(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExpenseDetailScreen(expense: e),
                          ),
                        );
                        // Ensure list is refreshed after coming back
                        await expenseStore.loadFromDb();
                      },
                      title: Text("${e.vendor} • ${e.category}"),
                      subtitle: Text("$dateStr • ${e.client} • ${e.type}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (e.receiptPath != null)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: Icon(Icons.receipt_long, size: 18),
                            ),
                          Text("${e.amount.toStringAsFixed(2)} ${e.currency}"),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (context) => const AddExpenseScreen(),
            ),
          );
          await expenseStore.loadFromDb();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}


