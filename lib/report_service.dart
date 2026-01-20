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
  /// OLD generator kept (by CW / Month).
  static Future<ReportResult> generate({
    required String mode,
    required int year,
    required int cw,
    required int month,
    required String client,
    required List<Expense> allExpenses,
  }) async {
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

    return _generateFiles(
      filtered: filtered,
      clientLabel: client,
      modeLabel: mode == "CW"
          ? "CW${cw.toString().padLeft(2, '0')} $year"
          : "Month ${month.toString().padLeft(2, '0')} $year",
      baseNamePrefix: "report_${client.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_')}",
    );
  }

  /// NEW: generate report files from a specific report selection
  static Future<ReportResult> generateForReport({
    required String reportName,
    required String scope,
    required List<Expense> reportExpenses,
  }) async {
    final filtered = List<Expense>.from(reportExpenses)
      ..sort((a, b) => b.date.compareTo(a.date));

    final safeName = reportName.replaceAll(RegExp(r'[^a-zA-Z0-9_-]'), '_');
    final basePrefix = "report_${scope}_$safeName";

    return _generateFiles(
      filtered: filtered,
      clientLabel: reportName,
      modeLabel: "Report ($scope)",
      baseNamePrefix: basePrefix,
    );
  }

  static Future<ReportResult> _generateFiles({
    required List<Expense> filtered,
    required String clientLabel,
    required String modeLabel,
    required String baseNamePrefix,
  }) async {
    final totalByCategory = <String, double>{};
    double totalAll = 0;
    double totalBusiness = 0;
    double totalPersonal = 0;

    double reimbursableTotalAssumedEur = 0;
    double reimbursedTotalEur = 0;
    double pendingTotalEur = 0;

    for (final e in filtered) {
      final amt = e.amount;
      totalAll += amt;
      if (e.type == "Business") totalBusiness += amt;
      if (e.type == "Personal") totalPersonal += amt;

      totalByCategory[e.category] = (totalByCategory[e.category] ?? 0) + amt;

      if (e.reimbursable) {
        reimbursableTotalAssumedEur += amt;
        reimbursedTotalEur += e.reimbursedAmountEur;
        final pending = (amt - e.reimbursedAmountEur);
        if (pending > 0) pendingTotalEur += pending;
      }
    }

    final dir = await getApplicationDocumentsDirectory();
    final ts = DateTime.now().millisecondsSinceEpoch;

    final baseName = "${baseNamePrefix}_$ts";
    final xlsxPath = "${dir.path}/$baseName.xlsx";
    final pdfPath = "${dir.path}/$baseName.pdf";

    final xlsxBytes = _buildExcel(
      filtered: filtered,
      title: clientLabel,
      periodLabel: modeLabel,
      totalByCategory: totalByCategory,
      totalAll: totalAll,
      totalBusiness: totalBusiness,
      totalPersonal: totalPersonal,
      reimbursableTotalAssumedEur: reimbursableTotalAssumedEur,
      reimbursedTotalEur: reimbursedTotalEur,
      pendingTotalEur: pendingTotalEur,
    );
    await File(xlsxPath).writeAsBytes(xlsxBytes);

    final pdfBytes = await _buildPdf(
      filtered: filtered,
      title: clientLabel,
      periodLabel: modeLabel,
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
    required String title,
    required String periodLabel,
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
    summary.appendRow([TextCellValue('Report'), TextCellValue(title)]);
    summary.appendRow([TextCellValue('Period'), TextCellValue(periodLabel)]);
    summary.appendRow([TextCellValue('')]);

    summary.appendRow([TextCellValue('Totals (Assumed EUR)')]);
    summary.appendRow([TextCellValue('Total'), DoubleCellValue(totalAll)]);
    summary.appendRow([TextCellValue('Business'), DoubleCellValue(totalBusiness)]);
    summary.appendRow([TextCellValue('Personal'), DoubleCellValue(totalPersonal)]);

    summary.appendRow([TextCellValue('')]);
    summary.appendRow([TextCellValue('Reimbursement (Assumed EUR)')]);
    summary.appendRow([TextCellValue('Reimbursable Total'), DoubleCellValue(reimbursableTotalAssumedEur)]);
    summary.appendRow([TextCellValue('Reimbursed'), DoubleCellValue(reimbursedTotalEur)]);
    summary.appendRow([TextCellValue('Pending'), DoubleCellValue(pendingTotalEur)]);

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
      TextCellValue('Scope'),
      TextCellValue('Currency'),
      TextCellValue('Amount'),
      TextCellValue('Report'),
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
        TextCellValue(e.scope),
        TextCellValue(e.currency),
        DoubleCellValue(e.amount),
        TextCellValue(e.reportName ?? ''),
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
    required String title,
    required String periodLabel,
    required Map<String, double> totalByCategory,
    required double totalAll,
    required double totalBusiness,
    required double totalPersonal,
    required double reimbursableTotalAssumedEur,
    required double reimbursedTotalEur,
    required double pendingTotalEur,
  }) async {
    final doc = pw.Document();

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (context) => [
          pw.Text('Expense Report', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 6),
          pw.Text('Report: $title'),
          pw.Text('Period: $periodLabel'),
          pw.SizedBox(height: 12),

          pw.Text('Totals (Assumed EUR)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Bullet(text: 'Total: ${totalAll.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Business: ${totalBusiness.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Personal: ${totalPersonal.toStringAsFixed(2)}'),
          pw.SizedBox(height: 8),

          pw.Text('Reimbursement (Assumed EUR)', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Bullet(text: 'Reimbursable Total: ${reimbursableTotalAssumedEur.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Reimbursed: ${reimbursedTotalEur.toStringAsFixed(2)}'),
          pw.Bullet(text: 'Pending: ${pendingTotalEur.toStringAsFixed(2)}'),
          pw.SizedBox(height: 8),

          pw.Text('By Category', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Table.fromTextArray(
            headers: ['Category', 'Amount (Assumed EUR)'],
            data: (totalByCategory.keys.toList()..sort())
                .map((c) => [c, (totalByCategory[c] ?? 0).toStringAsFixed(2)])
                .toList(),
          ),

          pw.SizedBox(height: 14),
          pw.Text('Expenses', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.Table.fromTextArray(
            headers: ['Date', 'Vendor', 'Category', 'Client', 'Scope', 'Amt', 'Cur', 'Report'],
            data: filtered.map((e) {
              return [
                _yyyyMmDd(e.date),
                e.vendor,
                e.category,
                e.client,
                e.scope,
                e.amount.toStringAsFixed(2),
                e.currency,
                e.reportName ?? '',
              ];
            }).toList(),
            cellStyle: const pw.TextStyle(fontSize: 9),
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold),
          ),
        ],
      ),
    );

    return doc.save();
  }

  static String _yyyyMmDd(DateTime d) =>
      "${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}";

  // ISO week (same as before)
  static int isoWeekNumber(DateTime date) {
    final thursday = date.add(Duration(days: 3 - ((date.weekday + 6) % 7)));
    final firstThursday = DateTime(thursday.year, 1, 4);
    final diff = thursday.difference(firstThursday);
    return 1 + (diff.inDays ~/ 7);
  }
}
