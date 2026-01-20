import 'package:flutter/material.dart';

import 'edit_expense_screen.dart' as edit;
import 'receipt_viewer_screen.dart';
import 'expense_store.dart';


class ExpenseDetailScreen extends StatelessWidget {
  final Expense expense;

  const ExpenseDetailScreen({
    super.key,
    required this.expense,
  });

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  @override
  Widget build(BuildContext context) {
    final amountStr = "${expense.amount.toStringAsFixed(2)} ${expense.currency}";
    final dateStr = _fmtDate(expense.date);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Expense Details'),
        actions: [
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit),
            onPressed: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => edit.EditExpenseScreen(expense: expense),
                ),
              );
              // After edit, just pop back to let previous screen refresh
              // (ReportDetailScreen already refreshes after navigation)
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.vendor,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 6),
                  Text('$dateStr • ${expense.category}'),
                  const SizedBox(height: 12),
                  Text(
                    amountStr,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _kv(context, 'Scope', expense.scope),
          _kv(context, 'Type', expense.type),
          _kv(context, 'Client', expense.client),
          _kv(context, 'Report', expense.reportName ?? '-'),
          _kv(context, 'Reimbursable', expense.reimbursable ? 'Yes' : 'No'),
          _kv(context, 'Reimbursement status', expense.reimbursementStatus),
          if (expense.reimbursedAmountEur > 0)
            _kv(context, 'Reimbursed (EUR)', expense.reimbursedAmountEur.toStringAsFixed(2)),
          if (expense.reimbursementDate != null)
            _kv(context, 'Reimbursement date', _fmtDate(expense.reimbursementDate!)),
          if ((expense.reimbursementPayer ?? '').isNotEmpty)
            _kv(context, 'Payer', expense.reimbursementPayer!),
          if ((expense.reimbursementReference ?? '').isNotEmpty)
            _kv(context, 'Reference', expense.reimbursementReference!),

          const SizedBox(height: 18),

          if (expense.receiptPath != null && expense.receiptPath!.isNotEmpty)
            FilledButton.icon(
              icon: const Icon(Icons.receipt_long),
              label: const Text('View receipt'),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReceiptViewerScreen(imagePath: expense.receiptPath!),
                  ),
                );
              },
            )
          else
            const Text('No receipt attached.'),
        ],
      ),
    );
  }

  Widget _kv(BuildContext context, String k, String v) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 160,
            child: Text(
              k,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(child: Text(v)),
        ],
      ),
    );
  }
}