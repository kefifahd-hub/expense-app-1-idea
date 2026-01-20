import 'package:flutter/material.dart';

import 'add_expense_screen.dart';
import 'local_db.dart';
import 'report_detail_screen.dart';

enum ExpenseSection { professional, private }

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

  bool _reportsLoading = true;
  String _reportTab = 'Draft'; // Draft | Submitted | Reimbursed

  List<Map<String, dynamic>> _rDraft = [];
  List<Map<String, dynamic>> _rSubmitted = [];
  List<Map<String, dynamic>> _rReimbursed = [];

  String get _scopeString =>
      _section == ExpenseSection.professional ? 'Professional' : 'Private';

  @override
  void initState() {
    super.initState();
    () async {
      await _loadReportsForCurrentScope();
      if (mounted) {
        setState(() {
          _loaded = true;
          _reportsLoading = false;
        });
      }
    }();
  }

  Future<void> _loadReportsForCurrentScope() async {
    final db = LocalDb.instance;
    final scope = _scopeString;

    _rDraft = await db.getReportsWithTotals(scope: scope, status: 'Draft');
    _rSubmitted = await db.getReportsWithTotals(scope: scope, status: 'Submitted');
    _rReimbursed = await db.getReportsWithTotals(scope: scope, status: 'Reimbursed');
  }

  Future<void> _refreshReports() async {
    setState(() => _reportsLoading = true);
    await _loadReportsForCurrentScope();
    if (mounted) setState(() => _reportsLoading = false);
  }

  List<Map<String, dynamic>> get _activeReports {
    switch (_reportTab) {
      case 'Submitted':
        return _rSubmitted;
      case 'Reimbursed':
        return _rReimbursed;
      default:
        return _rDraft;
    }
  }

  Widget _reportsBlock() {
    if (_reportsLoading) {
      return const Padding(
        padding: EdgeInsets.fromLTRB(12, 12, 12, 0),
        child: LinearProgressIndicator(),
      );
    }

    return Card(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Reports ($_scopeString)',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (_section == ExpenseSection.private)
                  Tooltip(
                    message: 'Private expenses are organized into monthly reports automatically',
                    child: Icon(
                      Icons.info_outline,
                      size: 20,
                      color: Colors.blue.shade600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text('Draft (${_rDraft.length})'),
                  selected: _reportTab == 'Draft',
                  onSelected: (_) => setState(() => _reportTab = 'Draft'),
                ),
                ChoiceChip(
                  label: Text('Submitted (${_rSubmitted.length})'),
                  selected: _reportTab == 'Submitted',
                  onSelected: (_) => setState(() => _reportTab = 'Submitted'),
                ),
                ChoiceChip(
                  label: Text('Reimbursed (${_rReimbursed.length})'),
                  selected: _reportTab == 'Reimbursed',
                  onSelected: (_) => setState(() => _reportTab = 'Reimbursed'),
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (_activeReports.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        Icons.inbox_outlined,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _section == ExpenseSection.private
                            ? 'No private reports yet.\nAdd expenses to create monthly reports automatically.'
                            : 'No professional reports yet.\nCreate reports to organize your expenses.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                ),
              )
            else
              ..._activeReports.map((r) {
                final id = r['id'] as String;
                final name = (r['name'] ?? '') as String;
                final client = (r['client_name'] ?? '') as String;
                final status = (r['status'] ?? 'Draft') as String;
                final count = ((r['expense_count'] ?? 0) as num).toInt();
                final total = ((r['total_amount'] ?? 0) as num).toDouble();
                final periodType = (r['period_type'] ?? 'CUSTOM') as String;

                String subtitle = '$client • $count expense${count == 1 ? '' : 's'}';
                if (_section == ExpenseSection.private && periodType == 'MONTH') {
                  final periodKey = r['period_key'] as String?;
                  if (periodKey != null && periodKey.isNotEmpty) {
                    subtitle = '$periodKey • $client • $count expense${count == 1 ? '' : 's'}';
                  }
                }

                return Card(
                  elevation: 1,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    leading: CircleAvatar(
                      backgroundColor: _getStatusColor(status).withOpacity(0.2),
                      child: Icon(
                        _getStatusIcon(status),
                        color: _getStatusColor(status),
                        size: 20,
                      ),
                    ),
                    title: Text(
                      name,
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      subtitle,
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                    trailing: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '€ ${total.toStringAsFixed(2)}',
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Container(
                          margin: const EdgeInsets.only(top: 2),
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: _getStatusColor(status).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status,
                            style: TextStyle(
                              fontSize: 10,
                              color: _getStatusColor(status),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    onTap: () async {
                      await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReportDetailScreen(
                            reportId: id,
                            reportName: name,
                            scope: _scopeString,
                            initialStatus: status,
                          ),
                        ),
                      );
                      await _refreshReports();
                    },
                  ),
                );
              }),
          ],
        ),
      ),
    );
  }

  IconData _getStatusIcon(String status) {
    switch (status) {
      case 'Submitted':
        return Icons.send;
      case 'Reimbursed':
        return Icons.check_circle;
      default:
        return Icons.edit_document;
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Submitted':
        return Colors.orange;
      case 'Reimbursed':
        return Colors.green;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Tracker'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _refreshReports,
            icon: const Icon(Icons.refresh),
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
              onSelectionChanged: (value) async {
                setState(() {
                  _section = value.first;
                  _reportsLoading = true;
                  _reportTab = 'Draft'; // Reset to Draft tab when switching
                });
                await _loadReportsForCurrentScope();
                if (mounted) setState(() => _reportsLoading = false);
              },
            ),
          ),
        ),
      ),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refreshReports,
              child: ListView(
                children: [
                  _reportsBlock(),
                  
                  // Help card for Private section
                  if (_section == ExpenseSection.private && _activeReports.isEmpty)
                    Card(
                      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                      color: Colors.blue.shade50,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.lightbulb_outline, color: Colors.blue.shade700),
                                const SizedBox(width: 8),
                                Text(
                                  'How Private Expenses Work',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue.shade900,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '• Private expenses are automatically organized by month\n'
                              '• Each client gets a monthly report (e.g., "Home 2026-01")\n'
                              '• Reports are created automatically when you add expenses\n'
                              '• Perfect for personal budgeting and tracking',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.blue.shade800,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.icon(
                              onPressed: () async {
                                await Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const AddExpenseScreen(
                                      presetScope: 'Private',
                                    ),
                                  ),
                                );
                                await _refreshReports();
                              },
                              icon: const Icon(Icons.add),
                              label: const Text('Add Your First Private Expense'),
                              style: FilledButton.styleFrom(
                                backgroundColor: Colors.blue.shade700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => AddExpenseScreen(
                presetScope: _scopeString,
              ),
            ),
          );
          await _refreshReports();
        },
        icon: const Icon(Icons.add),
        label: Text('Add $_scopeString Expense'),
      ),
    );
  }
}