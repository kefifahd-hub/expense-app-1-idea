import 'package:flutter/material.dart';

import 'expense_store.dart';
import 'local_db.dart';

class EditExpenseScreen extends StatefulWidget {
  final Expense expense;

  const EditExpenseScreen({
    super.key,
    required this.expense,
  });

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  late DateTime _date;
  late TextEditingController _vendorCtrl;
  late TextEditingController _amountCtrl;

  String _category = "Other";
  String _currency = "EUR";

  final categories = const [
    "Travel",
    "Hotel",
    "Transport",
    "Meals",
    "Groceries",
    "Utilities",
    "Rent",
    "Office",
    "Other"
  ];

  final currencies = const ["EUR", "AED", "USD", "GBP"];

  @override
  void initState() {
    super.initState();
    _date = widget.expense.date;
    _vendorCtrl = TextEditingController(text: widget.expense.vendor);
    _amountCtrl =
        TextEditingController(text: widget.expense.amount.toStringAsFixed(2));
    _category = widget.expense.category.isEmpty ? "Other" : widget.expense.category;
    _currency = widget.expense.currency.isEmpty ? "EUR" : widget.expense.currency;
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  String _fmtDate(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));

    await LocalDb.instance.updateExpense(widget.expense.id, {
      'date': _date.toIso8601String(),
      'vendor': _vendorCtrl.text.trim(),
      'category': _category,
      'currency': _currency,
      'amount': amount,
      // NOTE: we intentionally do NOT change scope/client/report link here.
    });

    await expenseStore.loadFromDb();

    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final locked = widget.expense.reimbursementStatus == 'Reimbursed';
    final reportLabel = (widget.expense.reportName == null ||
            widget.expense.reportName!.isEmpty)
        ? "-"
        : widget.expense.reportName!;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Expense"),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (locked)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    'This expense is in a reimbursed report / reimbursed status.\nEditing is locked.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ),

            const SizedBox(height: 12),

            // Read-only context (helps user understand where it lives)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Scope: ${widget.expense.scope}"),
                    Text("Client: ${widget.expense.client}"),
                    Text("Report: $reportLabel"),
                    Text("Type: ${widget.expense.type}"),
                    Text("Reimbursement: ${widget.expense.reimbursementStatus}"),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Date"),
              subtitle: Text(_fmtDate(_date)),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: locked ? null : _pickDate,
              ),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _vendorCtrl,
              decoration: const InputDecoration(
                labelText: "Vendor",
                border: OutlineInputBorder(),
              ),
              enabled: !locked,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? "Required" : null,
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(
                labelText: "Category",
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: locked ? null : (v) => setState(() => _category = v ?? "Other"),
            ),

            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(
                labelText: "Currency",
                border: OutlineInputBorder(),
              ),
              items: currencies
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: locked ? null : (v) => setState(() => _currency = v ?? "EUR"),
            ),

            const SizedBox(height: 12),

            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: "Amount",
                border: OutlineInputBorder(),
              ),
              enabled: !locked,
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Required";
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return "Invalid number";
                return null;
              },
            ),

            const SizedBox(height: 18),

            FilledButton(
              onPressed: locked ? null : _save,
              child: const Text("Save Changes"),
            ),
          ],
        ),
      ),
    );
  }
}
