import 'package:flutter/material.dart';

import 'add_expense_screen.dart';
import 'edit_expense_screen.dart';
import 'expense_detail_screen.dart';
import 'expense_store.dart';
import 'reports_screen.dart';

enum ExpenseSection { professional, private }
enum SortBy { date, reportName, vendor, amount }

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
  ExpenseSection _section = ExpenseSection.professional;
  SortBy _sortBy = SortBy.date;

  @override
  void initState() {
    super.initState();
    expenseStore.loadFromDb().then((_) {
      if (mounted) setState(() => _loaded = true);
    });
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => const ReportsScreen(),
      ),
    );
  }

  List<Expense> _getSortedExpenses(List<Expense> expenses) {
    final sorted = List<Expense>.from(expenses);
    
    switch (_sortBy) {
      case SortBy.date:
        sorted.sort((a, b) => b.date.compareTo(a.date));
        break;
      case SortBy.reportName:
        sorted.sort((a, b) {
          final aReport = a.reportName ?? '';
          final bReport = b.reportName ?? '';
          if (aReport.isEmpty && bReport.isEmpty) return 0;
          if (aReport.isEmpty) return 1;
          if (bReport.isEmpty) return -1;
          return aReport.compareTo(bReport);
        });
        break;
      case SortBy.vendor:
        sorted.sort((a, b) => a.vendor.compareTo(b.vendor));
        break;
      case SortBy.amount:
        sorted.sort((a, b) => b.amount.compareTo(a.amount));
        break;
    }
    
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Expenses'),
        actions: [
          PopupMenuButton<SortBy>(
            icon: const Icon(Icons.sort),
            tooltip: 'Sort by',
            onSelected: (value) {
              setState(() => _sortBy = value);
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: SortBy.date,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 20,
                      color: _sortBy == SortBy.date ? Colors.indigo : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Date',
                      style: TextStyle(
                        fontWeight: _sortBy == SortBy.date ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortBy.reportName,
                child: Row(
                  children: [
                    Icon(
                      Icons.description,
                      size: 20,
                      color: _sortBy == SortBy.reportName ? Colors.indigo : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Report Name',
                      style: TextStyle(
                        fontWeight: _sortBy == SortBy.reportName ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortBy.vendor,
                child: Row(
                  children: [
                    Icon(
                      Icons.store,
                      size: 20,
                      color: _sortBy == SortBy.vendor ? Colors.indigo : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Vendor',
                      style: TextStyle(
                        fontWeight: _sortBy == SortBy.vendor ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: SortBy.amount,
                child: Row(
                  children: [
                    Icon(
                      Icons.attach_money,
                      size: 20,
                      color: _sortBy == SortBy.amount ? Colors.indigo : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Amount',
                      style: TextStyle(
                        fontWeight: _sortBy == SortBy.amount ? FontWeight.bold : null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          IconButton(
            icon: const Icon(Icons.insert_drive_file),
            onPressed: _openReports,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SegmentedButton<ExpenseSection>(
              segments: const [
                ButtonSegment(
                  value: ExpenseSection.professional,
                  label: Text('Professional'),
                  icon: Icon(Icons.business),
                ),
                ButtonSegment(
                  value: ExpenseSection.private,
                  label: Text('Private'),
                  icon: Icon(Icons.home),
                ),
              ],
              selected: {_section},
              onSelectionChanged: (value) {
                setState(() {
                  _section = value.first;
                });
              },
            ),
          ),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : AnimatedBuilder(
              animation: expenseStore,
              builder: (context, _) {
                final visibleExpenses = expenseStore.items.where((e) {
                  if (_section == ExpenseSection.professional) {
                    return e.type == "Business";
                  } else {
                    return e.type == "Personal";
                  }
                }).toList();

                if (visibleExpenses.isEmpty) {
                  return Center(
                    child: Text(
                      _section == ExpenseSection.professional
                          ? 'No professional expenses yet'
                          : 'No private expenses yet',
                      style: const TextStyle(fontSize: 18),
                    ),
                  );
                }

                final sortedExpenses = _getSortedExpenses(visibleExpenses);

                return ListView.separated(
                  itemCount: sortedExpenses.length,
                  separatorBuilder: (_, __) => const Divider(height: 0),
                  itemBuilder: (context, index) {
                    final e = sortedExpenses[index];
                    final dateStr =
                        "${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}";

                    return ListTile(
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ExpenseDetailScreen(expense: e),
                          ),
                        );
                        await expenseStore.loadFromDb();
                      },
                      title: Row(
                        children: [
                          Expanded(child: Text("${e.vendor} • ${e.category}")),
                          if (e.reportName != null && e.reportName!.isNotEmpty)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.indigo.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                e.reportName!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.indigo,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                        ],
                      ),
                      subtitle: Text("$dateStr • ${e.client} • ${e.type}"),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            icon: const Icon(Icons.edit, size: 20),
                            onPressed: () async {
                              await Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => EditExpenseScreen(expense: e),
                                ),
                              );
                              await expenseStore.loadFromDb();
                            },
                          ),
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
              builder: (_) => const AddExpenseScreen(),
            ),
          );
          await expenseStore.loadFromDb();
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}