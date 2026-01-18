import 'package:flutter/material.dart';
import 'expense_store.dart';
import 'package:share_plus/share_plus.dart';
import 'report_service.dart';


class ReportsScreen extends StatefulWidget {
  const ReportsScreen({super.key});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  String _mode = "CW"; // CW / Month
  int _year = DateTime.now().year;
  int _cw = 1;
  int _month = DateTime.now().month;
  String _client = "All";

  List<String> get clients {
    final set = <String>{"All"};
    for (final e in expenseStore.items) {
      set.add(e.client);
    }
    return set.toList()..sort();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Reports")),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          DropdownButtonFormField<String>(
            value: _mode,
            decoration: const InputDecoration(
              labelText: "Report Type",
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: "CW", child: Text("Calendar Week (CW)")),
              DropdownMenuItem(value: "Month", child: Text("Monthly")),
            ],
            onChanged: (v) => setState(() => _mode = v ?? "CW"),
          ),
          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: TextFormField(
                  initialValue: _year.toString(),
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: "Year",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => _year = int.tryParse(v) ?? _year,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _client,
                  decoration: const InputDecoration(
                    labelText: "Client",
                    border: OutlineInputBorder(),
                  ),
                  items: clients
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (v) => setState(() => _client = v ?? "All"),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          if (_mode == "CW")
            TextFormField(
              initialValue: _cw.toString(),
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: "CW (1-53)",
                border: OutlineInputBorder(),
              ),
              onChanged: (v) => _cw = int.tryParse(v) ?? _cw,
            ),

          if (_mode == "Month")
            DropdownButtonFormField<int>(
              value: _month,
              decoration: const InputDecoration(
                labelText: "Month",
                border: OutlineInputBorder(),
              ),
              items: List.generate(
                12,
                (i) => DropdownMenuItem(value: i + 1, child: Text("${i + 1}")),
              ),
              onChanged: (v) => setState(() => _month = v ?? _month),
            ),

          const SizedBox(height: 20),

          ElevatedButton.icon(
  onPressed: () async {
    // Make sure we have the latest DB data
    await expenseStore.loadFromDb();

    final res = await ReportService.generate(
      mode: _mode,
      year: _year,
      cw: _cw,
      month: _month,
      client: _client,
      allExpenses: expenseStore.items,
    );

    await Share.shareXFiles(
      [XFile(res.pdfPath), XFile(res.xlsxPath)],
      text: "Expense report: ${_client} ${_mode == "CW" ? "CW$_cw" : "Month $_month"} $_year",
    );
  },
  icon: const Icon(Icons.file_present),
  label: const Text("Generate Report (Excel + PDF)"),
),

        ],
      ),
    );
  }
}
