import 'package:flutter/foundation.dart';
import 'local_db.dart';

class ReportItem {
  final String id;
  final String name;
  final String clientId;
  final String clientName;
  
  ReportItem({
    required this.id,
    required this.name,
    required this.clientId,
    required this.clientName,
  });
}

class ReportStore extends ChangeNotifier {
  final List<ReportItem> _drafts = [];
  List<ReportItem> get drafts => List.unmodifiable(_drafts);

  Future<void> loadDraftsForClient(String clientId) async {
    final rows = await LocalDb.instance.getReportsForClient(clientId);
    _drafts
      ..clear()
      ..addAll(rows.map((r) => ReportItem(
            id: r['id'] as String,
            name: r['name'] as String,
            clientId: r['client_id'] as String,
            clientName: r['client_name'] as String,
          )));
    notifyListeners();
  }

  Future<ReportItem> createDraft({
    required String clientId,
    required String clientName,
    required String name,
  }) async {
    final id = "rep_${DateTime.now().millisecondsSinceEpoch}";
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
    
    final item = ReportItem(
      id: id,
      name: name,
      clientId: clientId,
      clientName: clientName,
    );
    _drafts.add(item);
    notifyListeners();
    return item;
  }
}

final reportStore = ReportStore();