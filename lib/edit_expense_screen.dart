import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import 'expense_store.dart';
import 'local_db.dart';
import 'client_store.dart';
import 'report_store.dart';

class EditExpenseScreen extends StatefulWidget {
  final Expense expense;
  const EditExpenseScreen({super.key, required this.expense});

  @override
  State<EditExpenseScreen> createState() => _EditExpenseScreenState();
}

class _EditExpenseScreenState extends State<EditExpenseScreen> {
  final _formKey = GlobalKey<FormState>();

  File? _receiptFile;
  final ImagePicker _picker = ImagePicker();

  late TextEditingController _vendorCtrl;
  late TextEditingController _amountCtrl;

  late DateTime _date;
  late String _currency;
  late String _type;
  late String _category;
  late String _scope;

  String? _clientId;
  String? _clientName;
  String? _reportId;
  String? _reportName;

  bool _loadedLists = false;

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

  @override
  void initState() {
    super.initState();
    
    // Initialize with existing expense data
    _vendorCtrl = TextEditingController(text: widget.expense.vendor);
    _amountCtrl = TextEditingController(text: widget.expense.amount.toString());
    _date = widget.expense.date;
    _currency = widget.expense.currency;
    _type = widget.expense.type;
    _category = widget.expense.category;
    _scope = widget.expense.scope;
    _clientName = widget.expense.client;
    _reportId = widget.expense.reportId;
    _reportName = widget.expense.reportName;
    
    if (widget.expense.receiptPath != null) {
      _receiptFile = File(widget.expense.receiptPath!);
    }
    
    _loadLists();
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadLists() async {
    setState(() => _loadedLists = false);

    await clientStore.load(_scope);

    // Try to find the current client
    if (_clientName != null) {
      final matchingClient = clientStore.items.where((c) => c.name == _clientName).firstOrNull;
      if (matchingClient != null) {
        _clientId = matchingClient.id;
      }
    }

    if (_clientId == null && clientStore.items.isNotEmpty) {
      _clientId = clientStore.items.first.id;
      _clientName = clientStore.items.first.name;
    }

    if (_scope == "Professional" && _clientId != null) {
      await reportStore.loadDraftsForClient(_clientId!);
    }

    if (mounted) setState(() => _loadedLists = true);
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final XFile? picked = await _picker.pickImage(source: source, imageQuality: 85);
    if (picked != null) {
      setState(() => _receiptFile = File(picked.path));
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

  Future<void> _addNewClient() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(_scope == "Professional" ? "New Professional Client" : "New Private Project"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text("Add")),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final newItem = await clientStore.addClient(scope: _scope, name: name);
    setState(() {
      _clientId = newItem.id;
      _clientName = newItem.name;
      _reportId = null;
      _reportName = null;
    });

    if (_scope == "Professional") {
      await reportStore.loadDraftsForClient(_clientId!);
      setState(() {});
    }
  }

  Future<void> _createNewReport() async {
    if (_clientId == null || _clientName == null) return;

    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create new report"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Report name (e.g., CW03 2026 / Jan 2026)",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text("Create")),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final rep = await reportStore.createDraft(
      clientId: _clientId!,
      clientName: _clientName!,
      name: name,
    );

    setState(() {
      _reportId = rep.id;
      _reportName = rep.name;
    });
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    if (_clientId == null || _clientName == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select a client/project")));
      return;
    }

    if (_scope == "Professional" && (_reportId == null || _reportName == null)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Select or create a report")));
      return;
    }

    final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));

    // Update the expense in the database
    await LocalDb.instance.updateExpense(widget.expense.id, {
      'date': _date.toIso8601String(),
      'vendor': _vendorCtrl.text.trim(),
      'category': _category,
      'client': _clientName!,
      'type': _type,
      'scope': _scope,
      'currency': _currency,
      'amount': amount,
      'receipt_path': _receiptFile?.path,
      'report_id': _scope == "Professional" ? _reportId : null,
      'report_name': _scope == "Professional" ? _reportName : null,
    });

    await expenseStore.loadFromDb();
    
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _deleteExpense() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Expense"),
        content: const Text("Are you sure you want to delete this expense?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text("Delete"),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await LocalDb.instance.deleteExpense(widget.expense.id);
      await expenseStore.loadFromDb();
      if (mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateStr =
        "${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}";

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Expense'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete),
            onPressed: _deleteExpense,
          ),
          TextButton(onPressed: _save, child: const Text('Save')),
        ],
      ),
      body: !_loadedLists
          ? const Center(child: CircularProgressIndicator())
          : Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: "Professional", label: Text("Professional")),
                      ButtonSegment(value: "Private", label: Text("Private")),
                    ],
                    selected: {_scope},
                    onSelectionChanged: (s) async {
                      final next = s.first;
                      if (next == _scope) return;
                      setState(() {
                        _scope = next;
                        _clientId = null;
                        _clientName = null;
                        _reportId = null;
                        _reportName = null;
                      });
                      await _loadLists();
                    },
                  ),

                  const SizedBox(height: 12),

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
                          items: currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
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
                          items: types.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                    items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (v) => setState(() => _category = v ?? "Other"),
                  ),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _clientId,
                          decoration: InputDecoration(
                            labelText: _scope == "Professional" ? "Client" : "Project (Private)",
                            border: const OutlineInputBorder(),
                          ),
                          items: clientStore.items
                              .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                              .toList(),
                          onChanged: (id) async {
                            final selected = clientStore.items.firstWhere((c) => c.id == id);
                            setState(() {
                              _clientId = selected.id;
                              _clientName = selected.name;
                              _reportId = null;
                              _reportName = null;
                            });

                            if (_scope == "Professional") {
                              await reportStore.loadDraftsForClient(_clientId!);
                              if (reportStore.drafts.isNotEmpty) {
                                setState(() {
                                  _reportId = reportStore.drafts.first.id;
                                  _reportName = reportStore.drafts.first.name;
                                });
                              }
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      OutlinedButton.icon(
                        onPressed: _addNewClient,
                        icon: const Icon(Icons.add),
                        label: const Text("Add"),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  if (_scope == "Professional") ...[
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            value: _reportId,
                            decoration: const InputDecoration(
                              labelText: "Draft Report",
                              border: OutlineInputBorder(),
                            ),
                            items: reportStore.drafts
                                .map((r) => DropdownMenuItem(value: r.id, child: Text(r.name)))
                                .toList(),
                            onChanged: (rid) {
                              final r = reportStore.drafts.firstWhere((x) => x.id == rid);
                              setState(() {
                                _reportId = r.id;
                                _reportName = r.name;
                              });
                            },
                          ),
                        ),
                        const SizedBox(width: 12),
                        OutlinedButton.icon(
                          onPressed: _createNewReport,
                          icon: const Icon(Icons.add),
                          label: const Text("New"),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],

                  OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today),
                    label: Text("Date: $dateStr"),
                  ),

                  const SizedBox(height: 16),
                  Text('Receipt', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),

                  if (_receiptFile != null)
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(_receiptFile!, height: 180, fit: BoxFit.cover),
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
                    label: const Text('Save Changes'),
                  ),
                ],
              ),
            ),
    );
  }
}