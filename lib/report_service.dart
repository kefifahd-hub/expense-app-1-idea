import 'dart:io';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'expense_store.dart';

class ReportResult {
  final String pdfPath;
  final String xlsxPath;

  ReportResult({required this.pdfPath, required this.xlsxPath});
}

class ReportService {
  /// mode: "CW" or "Month"
  /// client: "All" or exact client name
  static Future<ReportResult> generate({
    required String mode,
    required int year,
    required int cw,
    required int month,
    required String client,
    required List<Expense> allExpenses,
  }) async {
    // 1) Filter
    final filtered = allExpenses.where((e) {
      if (client != "All" && e.client != client) return false;
      if (e.date.year != year) return false;

      if (mode == "CW") {
        return isoWeekNumber(e.date) == cw;
      } else {
        return e.date.month == month;
      }
    }).toList();

    filtered.sort((a, b) => b.date.compareTo(a.date));

    // 2) Summaries
    final totalByCategory = <String, double>{};
    double totalAll = 0;
    double totalBusiness = 0;
    double totalPersonal = 0;

    double reimbursableTotalAssumedEur = 0;
    double reimbursedTotalEur = 0;
    double pendingTotalEur = 0;

    for (final e in filtered) {
      final amt = e.amount; // NOTE: currently "as entered" (EUR if currency=EUR)
      totalAll += amt;
      if (e.type == "Business") totalBusiness += amt;
      if (e.type == "Personal") totalPersonal += amt;

      totalByCategory[e.category] = (totalByCategory[e.category] ?? 0) + amt;

      // Reimbursement (assumed EUR for now; FX comes later)
      if (e.reimbursable) {
        reimbursableTotalAssumedEur += amt;
        reimbursedTotalEur += e.reimbursedAmountEur;
        final pending = (amt - e.reimbursedAmountEur);
        if (pending > 0) pendingTotalEur += pending;
      }
    }

    // 3) Build files
    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;

    final periodLabel = mode == "CW"
        ? "CW${cw.toString().padLeft(2, '0')}_$year"
        : "M${month.toString().padLeft(2, '0')}_$year";

    final safeClient = client.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final baseName = "report_${safeClient}_$periodLabel_$ts";

    final xlsxPath = "${dir.path}/$baseName.xlsx";
    final pdfPath = "${dir.path}/$baseName.pdf";

    // Excel
    final xlsxBytes = _buildExcel(
      filtered: filtered,
      client: client,
      mode: mode,
      year: year,
      cw: cw,
      month: month,
      totalByCategory: totalByCategory,
      totalAll: totalAll,
      totalBusiness: totalBusiness,
      totalPersonal: totalPersonal,
      reimbursableTotalAssumedEur: reimbursableTotalAssumedEur,
      reimbursedTotalEur: reimbursedTotalEur,
      pendingTotalEur: pendingTotalEur,
    );
    await File(xlsxPath).writeAsBytes(xlsxBytes);

    // PDF
    final pdfBytes = await _buildPdf(
      filtered: filtered,
      client: client,
      mode: mode,
      year: year,
      cw: cw,
      month: month,
      totalByCategory: totalByCategory,
      totalAll: totalAll,
      totalBusiness: totalBusiness,
      totalPersonal: totalPersonal,
      reimbursableTotalAssumedEur: reimbursableTotalAssumedEur,
      reimbursedTotalEur: reimbursedTotalEur,
      pendingTotalEur: pendingTotalEur,
    );
    await File(pdfPath).writeAsBytes(pdfBytes);

    return ReportResult(pdfPath: pdfPath, xlsxPath: xlsxPath);
  }

  static Uint8List _buildExcel({
    required List<Expense> filtered,
    required String client,
    required String mode,
    required int year,
    required int cw,
    required int month,
    required Map<String, double> totalByCategory,
    required double totalAll,
    required double totalBusiness,
    required double totalPersonal,
    required double reimbursableTotalAssumedEur,
    required double reimbursedTotalEur,
    required double pendingTotalEur,
  }) {
    final excel = Excel.createExcel();

    final summary = excel['Summary'];
    summary.appendRow([
      TextCellValue('Client'),
      TextCellValue(client),
      TextCellValue('Period'),
      TextCellValue(mode == "CW"
          ? "CW${cw.toString().padLeft(2, '0')} $year"
          : "Month ${month.toString().padLeft(2, '0')} $year"),
    ]);

    summary.appendRow([TextCellValue('')]);

    summary.appendRow([
      TextCellValue('Totals (Assumed EUR)'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    summary.appendRow([
      TextCellValue('Total'),
      DoubleCellValue(totalAll),
      TextCellValue('Business'),
      DoubleCellValue(totalBusiness),
    ]);

    summary.appendRow([
      TextCellValue('Personal'),
      DoubleCellValue(totalPersonal),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    summary.appendRow([TextCellValue('')]);

    summary.appendRow([
      TextCellValue('Reimbursement (Assumed EUR)'),
      TextCellValue(''),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    summary.appendRow([
      TextCellValue('Reimbursable Total'),
      DoubleCellValue(reimbursableTotalAssumedEur),
      TextCellValue('Reimbursed'),
      DoubleCellValue(reimbursedTotalEur),
    ]);

    summary.appendRow([
      TextCellValue('Pending'),
      DoubleCellValue(pendingTotalEur),
      TextCellValue(''),
      TextCellValue(''),
    ]);

    summary.appendRow([TextCellValue('')]);
    summary.appendRow([TextCellValue('By Category'), TextCellValue('Amount (Assumed EUR)')]);

    final cats = totalByCategory.keys.toList()..sort();
    for (final c in cats) {
      summary.appendRow([TextCellValue(c), DoubleCellValue(totalByCategory[c] ?? 0)]);
    }

    final items = excel['Expenses'];
    items.appendRow([
      TextCellValue('Date'),
      TextCellValue('Vendor'),
      TextCellValue('Category'),
      TextCellValue('Client'),
      TextCellValue('Type'),
      TextCellValue('Currency'),
      TextCellValue('Amount'),
      TextCellValue('Reimbursable'),
      TextCellValue('Reimb. Status'),
      TextCellValue('Reimbursed EUR'),
      TextCellValue('Has Receipt'),
    ]);

    for (final e in filtered) {
      items.appendRow([
        TextCellValue(_yyyyMmDd(e.date)),
        TextCellValue(e.vendor),
        TextCellValue(e.category),
        TextCellValue(e.client),
        TextCellValue(e.type),
        TextCellValue(e.currency),
        DoubleCellValue(e.amount),
        TextCellValue(e.reimbursable ? 'Yes' : 'No'),
        TextCellValue(e.reimbursementStatus),
        DoubleCellValue(e.reimbursedAmountEur),
        TextCellValue(e.receiptPath != null ? 'Yes' : 'No'),
      ]);
    }

    final bytes = excel.save();
    return Uint8List.fromList(bytes ?? []);
  }

  static Future<Uint8List> _buildPdf({
    required List<Expense> filtered,
    required String client,
    required String mode,
    required int year,
    required int cw,
    required int month,
    required Map<String, double> totalByCategory,
    required double totalAll,
    required double totalBusiness,
    required double totalPersonal,
    required double reimbursableTotalAssumedEur,
    required double reimbursedTotalEur,
    required double pendingTotalEur,
  }) async {
    final doc = pw.Document();

    final periodStr = mode == "CW"
        ? "CW${cw.toString().padLeft(2, '0')} $year"
        : "Month ${month.toString().padLeft(2, '0')} $year";

    // Page 1 summary
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) {
          final cats = totalByCategory.keys.toList()..sort();

          return [
            pw.Text("Expense Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Text("Client: $client"),
            pw.Text("Period: $periodStr"),
            pw.SizedBox(height: 12),

            pw.Text("Totals (Assumed EUR)", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['Total', 'Business', 'Personal'],
              data: [
                [_fmt(totalAll), _fmt(totalBusiness), _fmt(totalPersonal)],
              ],
            ),

            pw.SizedBox(height: 12),
            pw.Text("Reimbursement (Assumed EUR)", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['Reimbursable Total', 'Reimbursed', 'Pending'],
              data: [
                [_fmt(reimbursableTotalAssumedEur), _fmt(reimbursedTotalEur), _fmt(pendingTotalEur)],
              ],
            ),

            pw.SizedBox(height: 12),
            pw.Text("By Category (Assumed EUR)", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['Category', 'Amount'],
              data: [
                for (final c in cats) [c, _fmt(totalByCategory[c] ?? 0)],
              ],
            ),

            pw.SizedBox(height: 16),
            pw.Text("Expenses", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),
            pw.Table.fromTextArray(
              headers: ['Date', 'Vendor', 'Category', 'Type', 'Amount', 'Receipt'],
              data: [
                for (final e in filtered)
                  [
                    _yyyyMmDd(e.date),
                    _short(e.vendor, 20),
                    _short(e.category, 14),
                    _short(e.type, 10),
                    "${_fmt(e.amount)} ${e.currency}",
                    e.receiptPath != null ? 'Yes' : 'No',
                  ],
              ],
            ),

            // Receipt pages start after summary (still in same pdf)
            pw.SizedBox(height: 18),
            pw.Text("Receipts", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
            pw.SizedBox(height: 6),

            for (final e in filtered)
              if (e.receiptPath != null)
                ...await _receiptBlock(e),
          ];
        },
      ),
    );

    return doc.save();
  }

  static Future<List<pw.Widget>> _receiptBlock(Expense e) async {
    final widgets = <pw.Widget>[];

    widgets.add(
      pw.Container(
        padding: const pw.EdgeInsets.all(8),
        margin: const pw.EdgeInsets.only(bottom: 10),
        decoration: pw.BoxDecoration(border: pw.Border.all(width: 0.8)),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              "${_yyyyMmDd(e.date)} • ${e.client} • ${e.category}",
              style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold),
            ),
            pw.Text("${e.vendor} • ${e.type} • ${_fmt(e.amount)} ${e.currency}", style: const pw.TextStyle(fontSize: 10)),
            pw.SizedBox(height: 8),
          ],
        ),
      ),
    );

    try {
      final file = File(e.receiptPath!);
      if (await file.exists()) {
        final bytes = await file.readAsBytes();
        final img = pw.MemoryImage(bytes);

        widgets.add(
          pw.Container(
            margin: const pw.EdgeInsets.only(bottom: 18),
            child: pw.Image(img, fit: pw.BoxFit.contain),
          ),
        );
      } else {
        widgets.add(pw.Text("Receipt file not found on device: ${e.receiptPath}", style: const pw.TextStyle(fontSize: 10)));
      }
    } catch (err) {
      widgets.add(pw.Text("Failed to load receipt image: $err", style: const pw.TextStyle(fontSize: 10)));
    }

    return widgets;
  }

  // ISO week number (Mon-based)
  static int isoWeekNumber(DateTime date) {
    final d = DateTime(date.year, date.month, date.day);
    final weekday = d.weekday; // Mon=1..Sun=7
    final thursday = d.add(Duration(days: 4 - weekday));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final firstWeekThursday = firstThursday.add(Duration(days: 4 - firstThursday.weekday));
    final diff = thursday.difference(firstWeekThursday).inDays;
    return 1 + (diff ~/ 7);
  }

  static String _yyyyMmDd(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  static String _fmt(double v) => v.toStringAsFixed(2);

  static String _short(String s, int max) => s.length <= max ? s : "${s.substring(0, max - 1)}…";
}
