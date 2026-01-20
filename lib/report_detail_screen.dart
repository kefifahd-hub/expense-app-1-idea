import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'add_expense_screen.dart' as add;
import 'edit_expense_screen.dart' as edit;
import 'expense_detail_screen.dart' as detail;

import 'expense_store.dart';
import 'local_db.dart';
import 'report_service.dart';

class ReportDetailScreen extends StatefulWidget {
  final String reportId;
  final String reportName;
  final String scope; // "Professional" | "Private"
  final String initialStatus; // "Draft" | "Submitted" | "Reimbursed"

  const ReportDetailScreen({
    super.key,
    required this.reportId,
    required this.reportName,
    required this.scope,
    required this.initialStatus,
  });

  @override
  State<ReportDetailScreen> createState() => _ReportDetailScreenState();
}

class _ReportDetailScreenState extends State<ReportDetailScreen> {
  late String _status;
  bool _exporting = false;
  bool _loading = true;

  String? _clientId;
  String? _clientName;

  String? _lastPdfPath;
  String? _lastXlsxPath;

  @override
  void initState() {
    super.initState();
    _status = widget.initialStatus;
    _init();
  }

  bool get _canEdit => _status != 'Reimbursed';

  Future<void> _init() async {
    setState(() => _loading = true);

    await expenseStore.loadFromDb();

    final db = await LocalDb.instance.database;
    final rows = await db.query(
      'reports',
      columns: ['client_id', 'client_name', 'status'],
      where: 'id = ?',
      whereArgs: [widget.reportId],
      limit: 1,
    );

    if (rows.isNotEmpty) {
      _clientId = rows.first['client_id'] as String?;
      _clientName = rows.first['client_name'] as String?;
      _status = (rows.first['status'] as String?) ?? _status;
    }

    if (mounted) setState(() => _loading = false);
  }

  List<Expense> get _expenses {
    final list = expenseStore.items
        .where((e) => e.reportId == widget.reportId)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return list;
  }

  double get _total => _expenses.fold<double>(0, (sum, e) => sum + e.amount);

  Future<void> _setStatus(String newStatus) async {
    await LocalDb.instance.updateReportStatus(widget.reportId, newStatus);
    if (!mounted) return;
    setState(() => _status = newStatus);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Report marked as $newStatus')),
    );
  }

  Future<void> _revertToDraft() async {
    await LocalDb.instance.updateReportStatus(widget.reportId, 'Draft');
    if (!mounted) return;
    setState(() => _status = 'Draft');

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Report reverted to Draft')),
    );
  }

  Future<Directory> _ensureExportDir() async {
    final base = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(base.path, 'exports', widget.reportId));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  Future<Map<String, String>> _generateAndCopyToExportDir() async {
    // Generate files using your ReportService
    final res = await ReportService.generateForReport(
      reportName: widget.reportName,
      scope: widget.scope,
      reportExpenses: _expenses,
    );

    final exportDir = await _ensureExportDir();
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final safeName =
        widget.reportName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');

    final pdfTarget = p.join(exportDir.path, '${safeName}_$timestamp.pdf');
    final xlsxTarget = p.join(exportDir.path, '${safeName}_$timestamp.xlsx');

    if (await File(res.pdfPath).exists()) {
      await File(res.pdfPath).copy(pdfTarget);
    }
    if (await File(res.xlsxPath).exists()) {
      await File(res.xlsxPath).copy(xlsxTarget);
    }

    _lastPdfPath = pdfTarget;
    _lastXlsxPath = xlsxTarget;

    return {'pdf': pdfTarget, 'xlsx': xlsxTarget, 'dir': exportDir.path};
  }

  void _showSuccessDialog(String pdfPath, String xlsxPath, String dirPath) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('✅ Files Generated'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Saved successfully inside the app folder:'),
            const SizedBox(height: 12),
            Text('PDF: ${p.basename(pdfPath)}', style: const TextStyle(fontSize: 12)),
            Text('Excel: ${p.basename(xlsxPath)}', style: const TextStyle(fontSize: 12)),
            const SizedBox(height: 10),
            Text(
              'Folder: $dirPath',
              style: const TextStyle(fontSize: 11, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('OK'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(ctx);
              await Share.shareXFiles([XFile(pdfPath), XFile(xlsxPath)]);
            },
            icon: const Icon(Icons.share),
            label: const Text('Share'),
          ),
        ],
      ),
    );
  }

  Future<void> _generateOnly() async {
    if (_expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to export')),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final out = await _generateAndCopyToExportDir();
      if (!mounted) return;

      _showSuccessDialog(out['pdf']!, out['xlsx']!, out['dir']!);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Export failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _submitAndShare() async {
    if (_expenses.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No expenses to submit/share')),
      );
      return;
    }

    setState(() => _exporting = true);
    try {
      final out = await _generateAndCopyToExportDir();

      // Mark as Submitted
      await LocalDb.instance.updateReportStatus(widget.reportId, 'Submitted');
      if (!mounted) return;
      setState(() => _status = 'Submitted');

      final totalStr = _total.toStringAsFixed(2);
      final dateStr = DateTime.now().toString().split(' ')[0];

      final text = '''Expense Report: ${widget.reportName}

Scope: ${widget.scope}
Date: $dateStr
Total: € $totalStr
Items: ${_expenses.length}

Attached: PDF + Excel''';

      await Share.shareXFiles(
        [XFile(out['pdf']!), XFile(out['xlsx']!)],
        text: text,
        subject: 'Expense Report - ${widget.reportName}',
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Report submitted and shared!'),
          backgroundColor: Colors.green,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Submit/share failed: $e'), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _addExpenseToThisReport() async {
    if (!_canEdit) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Report is reimbursed. Adding is locked.')),
      );
      return;
    }

    if (_clientId == null || _clientName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Missing report client info.')),
      );
      return;
    }

    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => add.AddExpenseScreen(
          presetScope: widget.scope,
          presetClientId: _clientId!,
          presetClientName: _clientName!,
          presetReportId: widget.reportId,
          presetReportName: widget.reportName,
        ),
      ),
    );

    await _init();
  }

  @override
  Widget build(BuildContext context) {
    final totalStr = _total.toStringAsFixed(2);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.reportName),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Status',
            onSelected: _setStatus,
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'Draft', child: Text('Mark as Draft')),
              PopupMenuItem(value: 'Submitted', child: Text('Mark as Submitted')),
              PopupMenuItem(value: 'Reimbursed', child: Text('Mark as Reimbursed')),
            ],
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addExpenseToThisReport,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _init,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(text: widget.scope),
                      _Chip(text: _status),
                      _Chip(
                        text: '${_expenses.length} expense${_expenses.length == 1 ? '' : 's'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Total: € $totalStr',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _canEdit ? 'Editable: YES' : 'Editable: NO (reimbursed)',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),

                  // Submit & Share only when Draft
                  if (_status == 'Draft') ...[
                    FilledButton.icon(
                      onPressed: _exporting ? null : _submitAndShare,
                      icon: _exporting
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.send),
                      label: Text(_exporting ? 'Submitting...' : 'Submit & Share'),
                    ),
                    const SizedBox(height: 12),
                  ],

                  // Generate always allowed unless reimbursed (optional rule)
                  FilledButton.icon(
                    onPressed: (_exporting || _status == 'Reimbursed') ? null : _generateOnly,
                    icon: _exporting
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                          )
                        : const Icon(Icons.download),
                    label: const Text('Generate PDF + Excel'),
                  ),

                  if (_status == 'Submitted') ...[
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _revertToDraft,
                      icon: const Icon(Icons.undo),
                      label: const Text('Revert to Draft'),
                    ),
                  ],

                  if (_lastPdfPath != null && _lastXlsxPath != null) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: () async {
                        await Share.shareXFiles(
                          [XFile(_lastPdfPath!), XFile(_lastXlsxPath!)],
                          subject: 'Expense Report - ${widget.reportName}',
                        );
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Share again'),
                    ),
                  ],

                  const Divider(height: 28),

                  if (_expenses.isEmpty)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32),
                        child: Text(
                          'No expenses linked to this report yet.\nTap + to add an expense.',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    )
                  else
                    ..._expenses.map((e) {
                      final dateStr =
                          "${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}";
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: ListTile(
                          title: Text('${e.vendor} • ${e.category}'),
                          subtitle: Text(
                            '$dateStr • ${e.amount.toStringAsFixed(2)} ${e.currency}',
                          ),
                          trailing: _canEdit
                              ? IconButton(
                                  icon: const Icon(Icons.edit),
                                  onPressed: () async {
                                    await Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => edit.EditExpenseScreen(expense: e),
                                      ),
                                    );
                                    await _init();
                                  },
                                )
                              : null,
                          onTap: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => detail.ExpenseDetailScreen(expense: e),
                              ),
                            );
                            await _init();
                          },
                        ),
                      );
                    }),
                ],
              ),
            ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(text, style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
