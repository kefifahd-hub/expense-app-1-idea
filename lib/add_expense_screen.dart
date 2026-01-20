import 'dart:io';

import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:sqflite/sqflite.dart';

import 'client_store.dart';
import 'expense_store.dart';
import 'local_db.dart';

class AddExpenseScreen extends StatefulWidget {
  // Optional presets (used when adding from a report detail screen)
  final String? presetScope; // "Professional" | "Private"
  final String? presetClientId;
  final String? presetClientName;
  final String? presetReportId;
  final String? presetReportName;

  const AddExpenseScreen({
    super.key,
    this.presetScope,
    this.presetClientId,
    this.presetClientName,
    this.presetReportId,
    this.presetReportName,
  });

  @override
  State<AddExpenseScreen> createState() => _AddExpenseScreenState();
}

class _AddExpenseScreenState extends State<AddExpenseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _uuid = const Uuid();
  final _picker = ImagePicker();
  final _textRecognizer = TextRecognizer();

  DateTime _date = DateTime.now();
  final _vendorCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();

  String _category = "Other";
  String _currency = "EUR";
  String _scope = "Professional"; // Professional / Private

  String? _clientId;
  String? _clientName;

  // Report selection (for Professional only)
  bool _loadingReports = false;
  List<Map<String, dynamic>> _draftReports = [];
  String? _reportId;
  String? _reportName;

  // Receipt
  String? _receiptPath;
  bool _processingOCR = false;

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

  bool get _lockedByPreset =>
      widget.presetScope != null &&
      widget.presetClientId != null &&
      widget.presetReportId != null;

  bool get _isPro => _scope == "Professional";

  @override
  void initState() {
    super.initState();

    // Apply presets if coming from report detail
    if (widget.presetScope != null) _scope = widget.presetScope!;
    _clientId = widget.presetClientId;
    _clientName = widget.presetClientName;
    _reportId = widget.presetReportId;
    _reportName = widget.presetReportName;

    clientStore.load(_scope);

    // If preset provides a professional client, load draft reports
    if (_isPro && _clientId != null && !_lockedByPreset) {
      _loadDraftReportsForClient(_clientId!);
    }
  }

  @override
  void dispose() {
    _vendorCtrl.dispose();
    _amountCtrl.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _loadDraftReportsForClient(String clientId) async {
    setState(() {
      _loadingReports = true;
      _draftReports = [];
      _reportId = null;
      _reportName = null;
    });

    final rows = await LocalDb.instance.getReportsForClient(clientId);
    if (!mounted) return;

    setState(() {
      _draftReports = rows;
      _loadingReports = false;

      // auto-select first if exists
      if (_draftReports.isNotEmpty) {
        _reportId = _draftReports.first['id'] as String;
        _reportName = _draftReports.first['name'] as String;
      }
    });
  }

  Future<void> _createNewDraftReport() async {
    if (_clientId == null || _clientName == null) return;

    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Create new draft report"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Report name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Create"),
          ),
        ],
      ),
    );

    if (name == null || name.isEmpty) return;

    final id = "rep_${DateTime.now().millisecondsSinceEpoch}";
    await LocalDb.instance.insertReport(
      id: id,
      clientId: _clientId!,
      clientName: _clientName!,
      name: name,
      scope: 'Professional',
      status: 'Draft',
      periodType: 'CUSTOM',
      periodYear: DateTime.now().year,
      periodNumber: 0,
      periodKey: '',
    );

    await _loadDraftReportsForClient(_clientId!);

    setState(() {
      _reportId = id;
      _reportName = name;
    });
  }

  Future<void> _addNewClientDialog() async {
    final ctrl = TextEditingController();
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add new client"),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            labelText: "Client name",
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text.trim()),
            child: const Text("Add"),
          ),
        ],
      ),
    );

    if (name == null || name.trim().isEmpty) return;

    // Insert directly in DB
    final db = await LocalDb.instance.database;
    final newId = "cli_${DateTime.now().millisecondsSinceEpoch}";
    await db.insert(
      'clients',
      {
        'id': newId,
        'name': name.trim(),
        'scope': _scope,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    await clientStore.load(_scope);

    if (!mounted) return;
    setState(() {
      _clientId = newId;
      _clientName = name.trim();
      _draftReports = [];
      _reportId = null;
      _reportName = null;
    });

    if (_isPro) {
      await _loadDraftReportsForClient(newId);
    }
  }

  Future<String> _persistPickedReceipt(XFile xf) async {
    final dir = await getApplicationDocumentsDirectory();
    final receiptsDir = Directory(p.join(dir.path, 'receipts'));
    if (!await receiptsDir.exists()) {
      await receiptsDir.create(recursive: true);
    }

    final ext = p.extension(xf.path).isNotEmpty ? p.extension(xf.path) : '.jpg';
    final target = p.join(
      receiptsDir.path,
      "rcpt_${DateTime.now().millisecondsSinceEpoch}$ext",
    );

    await File(xf.path).copy(target);
    return target;
  }

  Future<void> _performOCR(String imagePath) async {
    setState(() => _processingOCR = true);

    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      // Extract data from recognized text
      _extractDataFromOCR(recognizedText.text);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Receipt data extracted! Please verify the information.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _processingOCR = false);
      }
    }
  }

  void _extractDataFromOCR(String text) {
    final lines = text.split('\n');
    
    // Try to find amount (look for numbers with currency symbols or decimal points)
    final amountRegex = RegExp(r'[\d,]+\.?\d{0,2}');
    final currencyRegex = RegExp(r'(EUR|AED|USD|GBP|€|\$|£)', caseSensitive: false);
    
    String? extractedAmount;
    String? extractedCurrency;
    String? extractedVendor;
    DateTime? extractedDate;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i].trim();
      
      // Extract vendor (usually first non-empty line)
      if (extractedVendor == null && line.isNotEmpty && line.length > 2) {
        // Avoid lines that are just numbers or dates
        if (!RegExp(r'^\d+[\d\s\.\-\/]*$').hasMatch(line)) {
          extractedVendor = line;
        }
      }

      // Extract amount and currency
      if (extractedAmount == null) {
        final currencyMatch = currencyRegex.firstMatch(line);
        if (currencyMatch != null) {
          extractedCurrency = _normalizeCurrency(currencyMatch.group(0)!);
          
          final amountMatch = amountRegex.firstMatch(line);
          if (amountMatch != null) {
            extractedAmount = amountMatch.group(0)!.replaceAll(',', '');
          }
        } else {
          // Look for standalone amounts (common pattern: TOTAL, SUM, etc.)
          if (line.toUpperCase().contains('TOTAL') || 
              line.toUpperCase().contains('SUM') ||
              line.toUpperCase().contains('AMOUNT')) {
            final amountMatch = amountRegex.firstMatch(line);
            if (amountMatch != null) {
              extractedAmount = amountMatch.group(0)!.replaceAll(',', '');
            }
          }
        }
      }

      // Extract date (common formats: DD/MM/YYYY, DD.MM.YYYY, YYYY-MM-DD)
      if (extractedDate == null) {
        final dateMatch = RegExp(
          r'(\d{1,2})[\/\.\-](\d{1,2})[\/\.\-](\d{2,4})|(\d{4})[\/\.\-](\d{1,2})[\/\.\-](\d{1,2})'
        ).firstMatch(line);
        
        if (dateMatch != null) {
          try {
            if (dateMatch.group(4) != null) {
              // YYYY-MM-DD format
              final year = int.parse(dateMatch.group(4)!);
              final month = int.parse(dateMatch.group(5)!);
              final day = int.parse(dateMatch.group(6)!);
              extractedDate = DateTime(year, month, day);
            } else {
              // DD/MM/YYYY format
              final day = int.parse(dateMatch.group(1)!);
              final month = int.parse(dateMatch.group(2)!);
              var year = int.parse(dateMatch.group(3)!);
              
              // Handle 2-digit years
              if (year < 100) {
                year += 2000;
              }
              
              extractedDate = DateTime(year, month, day);
            }
          } catch (e) {
            // Invalid date, skip
          }
        }
      }
    }

    // Update form fields
    if (extractedVendor != null && _vendorCtrl.text.isEmpty) {
      setState(() {
        _vendorCtrl.text = extractedVendor!;
      });
    }

    if (extractedAmount != null && _amountCtrl.text.isEmpty) {
      setState(() {
        _amountCtrl.text = extractedAmount!;
      });
    }

    if (extractedCurrency != null) {
      setState(() {
        _currency = extractedCurrency!;
      });
    }

    if (extractedDate != null) {
      setState(() {
        _date = extractedDate!;
      });
    }
  }

  String _normalizeCurrency(String currency) {
    switch (currency.toUpperCase()) {
      case '€':
      case 'EUR':
        return 'EUR';
      case '\$':
      case 'USD':
        return 'USD';
      case '£':
      case 'GBP':
        return 'GBP';
      case 'AED':
        return 'AED';
      default:
        return 'EUR';
    }
  }

  Future<void> _pickReceipt(ImageSource source) async {
    final xf = await _picker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (xf == null) return;

    final savedPath = await _persistPickedReceipt(xf);
    if (!mounted) return;

    setState(() => _receiptPath = savedPath);

    // Automatically perform OCR
    await _performOCR(savedPath);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Please fill in all required fields"),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (_clientId == null || _clientName == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Client is required")),
      );
      return;
    }

    // Report selection rules
    String? reportId = _reportId;
    String? reportName = _reportName;

    if (_scope == "Professional") {
      if (reportId == null || reportName == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Select or create a draft report")),
        );
        return;
      }
    } else {
      // Private → auto-create/reuse monthly draft report
      try {
        final rep = await LocalDb.instance.getOrCreatePrivateMonthlyReport(
          clientId: _clientId!,
          clientName: _clientName!,
          year: _date.year,
          month: _date.month,
        );
        reportId = rep['id'] as String;
        reportName = rep['name'] as String;
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Failed to create report: $e")),
        );
        return;
      }
    }

    try {
      final amount = double.parse(_amountCtrl.text.replaceAll(',', '.'));

      final row = <String, dynamic>{
        'id': _uuid.v4(),
        'date': _date.toIso8601String(),
        'vendor': _vendorCtrl.text.trim(),
        'category': _category,
        'client': _clientName!,
        'scope': _scope,
        'currency': _currency,
        'amount': amount,
        'receipt_path': _receiptPath,
        'report_id': reportId,
        'report_name': reportName,
        'reimbursable': _scope == 'Professional' ? 1 : 0,
        'reimbursement_status': 'Not Submitted',
        'reimbursed_amount_eur': 0.0,
        'reimbursement_date': null,
        'reimbursement_payer': null,
        'reimbursement_reference': null,
      };

      await LocalDb.instance.insertExpense(row);
      await expenseStore.loadFromDb();

      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Expense saved successfully!"),
          backgroundColor: Colors.green,
        ),
      );
      
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text("Failed to save expense: $e"),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isLocked = _lockedByPreset;

    return Scaffold(
      appBar: AppBar(title: const Text("Add Expense")),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Scope
            DropdownButtonFormField<String>(
              initialValue: _scope,
              decoration: const InputDecoration(
                labelText: "Scope",
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: "Professional", child: Text("Professional")),
                DropdownMenuItem(value: "Private", child: Text("Private")),
              ],
              onChanged: isLocked
                  ? null
                  : (v) async {
                      if (v == null) return;
                      setState(() {
                        _scope = v;
                        _clientId = null;
                        _clientName = null;
                        _draftReports = [];
                        _reportId = null;
                        _reportName = null;
                      });
                      await clientStore.load(_scope);
                    },
            ),
            const SizedBox(height: 12),

            // Client + Add client
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _clientId,
                    decoration: const InputDecoration(
                      labelText: "Client",
                      border: OutlineInputBorder(),
                    ),
                    items: clientStore.items
                        .where((c) => c.scope == _scope)
                        .map((c) => DropdownMenuItem(value: c.id, child: Text(c.name)))
                        .toList(),
                    onChanged: isLocked
                        ? null
                        : (id) async {
                            if (id == null) return;
                            final c = clientStore.items.firstWhere((x) => x.id == id);
                            setState(() {
                              _clientId = c.id;
                              _clientName = c.name;
                              _draftReports = [];
                              _reportId = null;
                              _reportName = null;
                            });

                            if (_isPro) {
                              await _loadDraftReportsForClient(id);
                            }
                          },
                    validator: (v) => v == null ? "Client required" : null,
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton.icon(
                  onPressed: isLocked ? null : _addNewClientDialog,
                  icon: const Icon(Icons.add),
                  label: const Text("Add"),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Report selection (Professional only - Private auto-creates monthly)
            if (_isPro) ...[
              if (_loadingReports)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: LinearProgressIndicator(),
                )
              else
                DropdownButtonFormField<String>(
                  initialValue: _reportId,
                  decoration: const InputDecoration(
                    labelText: "Report (Draft)",
                    border: OutlineInputBorder(),
                  ),
                  items: _draftReports
                      .map((r) => DropdownMenuItem(
                            value: r['id'] as String,
                            child: Text(r['name'] as String),
                          ))
                      .toList(),
                  onChanged: isLocked
                      ? null
                      : (rid) {
                          if (rid == null) return;
                          final r = _draftReports.firstWhere((x) => x['id'] == rid);
                          setState(() {
                            _reportId = r['id'] as String;
                            _reportName = r['name'] as String;
                          });
                        },
                  validator: (v) => v == null ? "Report required" : null,
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: (isLocked || _clientId == null) ? null : _createNewDraftReport,
                icon: const Icon(Icons.add),
                label: const Text("Create new report"),
              ),
              const SizedBox(height: 12),
            ] else ...[
              // Private scope - show auto-report info
              Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.blue.shade700),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Private expenses are automatically organized into monthly reports',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.blue.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Date picker
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text("Date"),
              subtitle: Text(
                "${_date.year}-${_date.month.toString().padLeft(2, '0')}-${_date.day.toString().padLeft(2, '0')}",
              ),
              trailing: IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
                  );
                  if (picked != null) setState(() => _date = picked);
                },
              ),
            ),
            const SizedBox(height: 12),

            // Category
            DropdownButtonFormField<String>(
              initialValue: _category,
              decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
              items: categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _category = v ?? "Other"),
            ),
            const SizedBox(height: 12),

            // Currency
            DropdownButtonFormField<String>(
              initialValue: _currency,
              decoration: const InputDecoration(labelText: "Currency", border: OutlineInputBorder()),
              items: currencies.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
              onChanged: (v) => setState(() => _currency = v ?? "EUR"),
            ),
            const SizedBox(height: 12),

            // Vendor
            TextFormField(
              controller: _vendorCtrl,
              decoration: const InputDecoration(labelText: "Vendor", border: OutlineInputBorder()),
              validator: (v) => (v == null || v.trim().isEmpty) ? "Required" : null,
            ),
            const SizedBox(height: 12),

            // Amount
            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: "Amount", border: OutlineInputBorder()),
              validator: (v) {
                if (v == null || v.trim().isEmpty) return "Required";
                final parsed = double.tryParse(v.replaceAll(',', '.'));
                if (parsed == null || parsed <= 0) return "Invalid number";
                return null;
              },
            ),

            const SizedBox(height: 12),

            // Receipt actions with OCR
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text("Receipt", style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        if (_processingOCR)
                          const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickReceipt(ImageSource.camera),
                            icon: const Icon(Icons.photo_camera),
                            label: const Text("Camera"),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () => _pickReceipt(ImageSource.gallery),
                            icon: const Icon(Icons.photo_library),
                            label: const Text("Gallery"),
                          ),
                        ),
                      ],
                    ),
                    if (_receiptPath != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        "Attached: ${p.basename(_receiptPath!)}",
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(_receiptPath!),
                          height: 140,
                          fit: BoxFit.cover,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          TextButton.icon(
                            onPressed: () => setState(() => _receiptPath = null),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text("Remove"),
                          ),
                          TextButton.icon(
                            onPressed: _processingOCR ? null : () => _performOCR(_receiptPath!),
                            icon: const Icon(Icons.document_scanner),
                            label: const Text("Re-scan OCR"),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

            FilledButton(
              onPressed: _save,
              child: const Text("Save Expense"),
            ),
          ],
        ),
      ),
    );
  }
}