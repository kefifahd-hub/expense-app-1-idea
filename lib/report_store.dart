import 'package:flutter/foundation.dart';
import 'local_db.dart';

/// Lightweight report model used for overview screens
class ReportOverviewItem {
  final String id;
  final String name;
  final String clientId;
  final String clientName;
  final String scope; // Professional | Private
  final String status; // Draft | Submitted | Reimbursed
  final int expenseCount;
  final double totalAmount;

  ReportOverviewItem({
    required this.id,
    required this.name,
    required this.clientId,
    required this.clientName,
    required this.scope,
    required this.status,
    required this.expenseCount,
    required this.totalAmount,
  });

  factory ReportOverviewItem.fromRow(Map<String, dynamic> r) {
    return ReportOverviewItem(
      id: r['id'] as String,
      name: r['name'] as String,
      clientId: r['client_id'] as String,
      clientName: r['client_name'] as String,
      scope: r['scope'] as String,
      status: r['status'] as String,
      expenseCount: (r['expense_count'] ?? 0) as int,
      totalAmount: ((r['total_amount'] ?? 0) as num).toDouble(),
    );
  }
}

class ReportStore extends ChangeNotifier {
  final List<ReportOverviewItem> _items = [];
  List<ReportOverviewItem> get items => List.unmodifiable(_items);

  /// Load reports overview for a given scope + status
  Future<void> loadOverview({
    required String scope,
    required String status,
  }) async {
    final rows = await LocalDb.instance.getReportsWithTotals(
      scope: scope,
      status: status,
    );

    _items
      ..clear()
      ..addAll(rows.map(ReportOverviewItem.fromRow));

    notifyListeners();
  }

  /// Convenience loaders (optional but handy)
  Future<void> loadDrafts(String scope) async {
    await loadOverview(scope: scope, status: 'Draft');
  }

  Future<void> loadSubmitted(String scope) async {
    await loadOverview(scope: scope, status: 'Submitted');
  }

  Future<void> loadReimbursed(String scope) async {
    await loadOverview(scope: scope, status: 'Reimbursed');
  }

  /// Create a new PROFESSIONAL draft report
  Future<ReportOverviewItem> createProfessionalDraft({
    required String clientId,
    required String clientName,
    required String name,
  }) async {
    final id = 'rep_${DateTime.now().millisecondsSinceEpoch}';

    await LocalDb.instance.insertReport(
      id: id,
      clientId: clientId,
      clientName: clientName,
      name: name,
      scope: 'Professional',
      status: 'Draft',
      periodType: 'CUSTOM',
      periodYear: DateTime.now().year,
      periodNumber: 0,
      periodKey: '',
    );

    final item = ReportOverviewItem(
      id: id,
      name: name,
      clientId: clientId,
      clientName: clientName,
      scope: 'Professional',
      status: 'Draft',
      expenseCount: 0,
      totalAmount: 0,
    );

    _items.insert(0, item);
    notifyListeners();
    return item;
  }

  /// Update report status
  Future<void> setStatus({
    required String reportId,
    required String status,
  }) async {
    await LocalDb.instance.updateReportStatus(reportId, status);
  }
}

final reportStore = ReportStore();
