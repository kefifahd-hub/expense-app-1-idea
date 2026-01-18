import 'package:flutter/material.dart';
import 'expense_store.dart';
import 'local_db.dart';
import 'receipt_viewer_screen.dart';

class ExpenseDetailScreen extends StatefulWidget {
  final Expense expense;
  const ExpenseDetailScreen({super.key, required this.expense});

  @override
  State<ExpenseDetailScreen> createState() => _ExpenseDetailScreenState();
}

class _ExpenseDetailScreenState extends State<ExpenseDetailScreen> {
  late bool reimbursable;
  late String status;
  late TextEditingController reimbursedCtrl;
  late TextEditingController payerCtrl;
  late TextEditingController refCtrl;
  DateTime? reimbDate;

  final statuses = const [
    "Not Submitted",
    "Submitted",
    "Partially Reimbursed",
    "Reimbursed",
    "Rejected",
  ];

  @override
  void initState() {
    super.initState();
    final e = widget.expense;
    reimbursable = e.reimbursable;
    status = e.reimbursementStatus;
    reimbDate = e.reimbursementDate;
    reimbursedCtrl = TextEditingController(text: e.reimbursedAmountEur.toStringAsFixed(2));
    payerCtrl = TextEditingController(text: e.reimbursementPayer ?? "");
    refCtrl = TextEditingController(text: e.reimbursementReference ?? "");
  }

  @override
  void dispose() {
    reimbursedCtrl.dispose();
    payerCtrl.dispose();
    refCtrl.dispose();
    super.dispose();
  }

  double get amountEurAssumed => widget.expense.currency == "EUR" ? widget.expense.amount : widget.expense.amount;

  double get pendingEur {
    final reimb = double.tryParse(reimbursedCtrl.text.replaceAll(',', '.')) ?? 0;
    final total = amountEurAssumed;
    return (total - reimb).clamp(0, total);
  }

  Future<void> pickReimbDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: reimbDate ?? now,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => reimbDate = picked);
  }

  Future<void> save() async {
    final reimb = double.tryParse(reimbursedCtrl.text.replaceAll(',', '.')) ?? 0;

    // Auto-consistency rules
    String normalizedStatus = status;
    if (!reimbursable) {
      normalizedStatus = "Not Submitted";
    } else {
      final total = amountEurAssumed;
      if (reimb <= 0 && normalizedStatus == "Reimbursed") normalizedStatus = "Submitted";
      if (reimb >= total && normalizedStatus != "Rejected") normalizedStatus = "Reimbursed";
      if (reimb > 0 && reimb < total && normalizedStatus != "Rejected") normalizedStatus = "Partially Reimbursed";
    }

    await LocalDb.instance.updateExpense(widget.expense.id, {
      'reimbursable': reimbursable ? 1 : 0,
      'reimbursement_status': normalizedStatus,
      'reimbursed_amount_eur': reimb,
      'reimbursement_date': reimbDate?.toIso8601String(),
      'reimbursement_payer': payerCtrl.text.trim().isEmpty ? null : payerCtrl.text.trim(),
      'reimbursement_reference': refCtrl.text.trim().isEmpty ? null : refCtrl.text.trim(),
    });

    // Reload store (simple + safe)
    await expenseStore.loadFromDb();

    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final e = widget.expense;
    final dateStr = "${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}";
    final reimbDateStr = reimbDate == null
        ? "Not set"
        : "${reimbDate!.year}-${reimbDate!.month.toString().padLeft(2, '0')}-${reimbDate!.day.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text("Expense Details"),
        actions: [
          TextButton(onPressed: save, child: const Text("Save")),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("${e.vendor} • ${e.category}", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Text("$dateStr • ${e.client} • ${e.type}"),
          const SizedBox(height: 10),
          Text("Amount: ${e.amount.toStringAsFixed(2)} ${e.currency}"),

          const Divider(height: 28),

          if (e.receiptPath != null) ...[
            OutlinedButton.icon(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ReceiptViewerScreen(imagePath: e.receiptPath!),
                  ),
                );
              },
              icon: const Icon(Icons.receipt_long),
              label: const Text("View Receipt"),
            ),
            const Divider(height: 28),
          ],

          SwitchListTile(
            value: reimbursable,
            onChanged: (v) => setState(() => reimbursable = v),
            title: const Text("Reimbursable"),
            subtitle: const Text("Turn ON for business expenses to track pending reimbursement"),
          ),

          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            value: status,
            decoration: const InputDecoration(
              labelText: "Reimbursement Status",
              border: OutlineInputBorder(),
            ),
            items: statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
            onChanged: reimbursable ? (v) => setState(() => status = v ?? status) : null,
          ),

          const SizedBox(height: 12),
          TextFormField(
            controller: reimbursedCtrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: "Reimbursed Amount (EUR)",
              border: OutlineInputBorder(),
            ),
            enabled: reimbursable,
          ),

          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: reimbursable ? pickReimbDate : null,
            icon: const Icon(Icons.calendar_today),
            label: Text("Reimbursement Date: $reimbDateStr"),
          ),

          const SizedBox(height: 12),
          TextFormField(
            controller: payerCtrl,
            decoration: const InputDecoration(
              labelText: "Reimbursement Payer",
              border: OutlineInputBorder(),
            ),
            enabled: reimbursable,
          ),

          const SizedBox(height: 12),
          TextFormField(
            controller: refCtrl,
            decoration: const InputDecoration(
              labelText: "Reference / Notes",
              border: OutlineInputBorder(),
            ),
            enabled: reimbursable,
          ),

          const SizedBox(height: 16),
          if (reimbursable)
            Text(
              "Pending (EUR, assumed): ${pendingEur.toStringAsFixed(2)}",
              style: Theme.of(context).textTheme.titleMedium,
            ),
        ],
      ),
    );
  }
}
