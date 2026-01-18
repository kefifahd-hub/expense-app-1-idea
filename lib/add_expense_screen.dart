import 'package:flutter/material.dart';
import 'expense_store.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'local_db.dart';

class AddExpenseScreen extends StatefulWidget {
  const AddExpenseScreen({super.key});

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
File? _receiptFile;
final ImagePicker _picker = ImagePicker();

  final _vendorCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  DateTime _date = DateTime.now();
  String _currency = "EUR";
  String _type = "Business";
  String _category = "Travel";
  String _client = "Verkor";

  // You can expand these lists later or load from Supabase.
  final List<String> currencies = ["EUR", "AED", "USD", "GBP"];
  final List<String> types = ["Business", "Personal"];
  final List<String> categories = [
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
  final List<String> clients = ["Verkor", "FutureWorks", "Family", "Berlin House", "Spain House"];

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }
Future<void> _pickReceipt(ImageSource source) async {
  final XFile? picked = await _picker.pickImage(
    source: source,
    imageQuality: 85,
  );
  if (picked != null) {
    setState(() {
      _receiptFile = File(picked.path);
    });
  }
}

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _save() async {

    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));

    final e = Expense(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      date: _date,
      vendor: _vendorCtrl.text.trim(),
      category: _category,
      client: _client,
      type: _type,
      currency: _currency,
      amount: amount,
    );

 await LocalDb.instance.insertExpense({
  'id': e.id,
  'date': e.date.toIso8601String(),
  'vendor': e.vendor,
  'category': e.category,
  'client': e.client,
  'type': e.type,
  'currency': e.currency,
  'amount': e.amount,
  'receipt_path': _receiptFile?.path,

  // NEW reimbursement fields (defaults)
  'reimbursable': e.type == "Business" ? 1 : 0,
  'reimbursement_status': "Not Submitted",
  'reimbursed_amount_eur': 0.0,
  'reimbursement_date': null,
  'reimbursement_payer': null,
  'reimbursement_reference': null,
});


expenseStore.add(e);
Navigator.of(context).pop();

  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        "${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Expense'),
        actions: [
          TextButton(
            onPressed: _save,
            child: const Text('Save'),
          )
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextFormField(
              controller: _vendorCtrl,
              decoration: const InputDecoration(
                labelText: 'Vendor / Merchant',
                border: OutlineInputBorder(),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Amount',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Required";
                final cleaned = v.replaceAll(',', '.');
                final parsed = double.tryParse(cleaned);
                if (parsed == null || parsed <= 0) return "Enter a valid amount";
                return null;
              },
            ),
            const SizedBox(height: 12),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _currency,
                    decoration: const InputDecoration(
                      labelText: 'Currency',
                      border: OutlineInputBorder(),
                    ),
                    items: currencies
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) => setState(() => _currency = v ?? "EUR"),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _type,
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                    items: types
                        .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                        .toList(),
                    onChanged: (v) => setState(() => _type = v ?? "Business"),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: categories
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v ?? "Other"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _client,
              decoration: const InputDecoration(
                labelText: 'Client',
                border: OutlineInputBorder(),
              ),
              items: clients
                  .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                  .toList(),
              onChanged: (v) => setState(() => _client = v ?? "Family"),
            ),
            const SizedBox(height: 12),

            OutlinedButton.icon(
              onPressed: _pickDate,
              icon: const Icon(Icons.calendar_today),
              label: Text("Date: $dateStr"),
            ),
const SizedBox(height: 16),

Text(
  'Receipt',
  style: Theme.of(context).textTheme.titleMedium,
),

const SizedBox(height: 8),

if (_receiptFile != null)
  ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.file(
      _receiptFile!,
      height: 180,
      fit: BoxFit.cover,
    ),
  ),

const SizedBox(height: 8),

Row(
  children: [
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _pickReceipt(ImageSource.camera),
        icon: const Icon(Icons.camera_alt),
        label: const Text('Camera'),
      ),
    ),
    const SizedBox(width: 12),
    Expanded(
      child: OutlinedButton.icon(
        onPressed: () => _pickReceipt(ImageSource.gallery),
        icon: const Icon(Icons.photo),
        label: const Text('Gallery'),
      ),
    ),
  ],
),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: const Text('Save Expense'),
            ),
          ],
        ),
      ),
    );
  }
}
