import 'package:flutter/foundation.dart';
import 'local_db.dart';

class ClientItem {
  final String id;
  final String name;
  final String scope; // Professional / Private
  ClientItem({required this.id, required this.name, required this.scope});
}

class ClientStore extends ChangeNotifier {
  final List<ClientItem> _items = [];
  List<ClientItem> get items => List.unmodifiable(_items);

  Future<void> load(String scope) async {
    final rows = await LocalDb.instance.getClients(scope);
    _items
      ..clear()
      ..addAll(rows.map((r) => ClientItem(
            id: r['id'] as String,
            name: r['name'] as String,
            scope: r['scope'] as String,
          )));
    notifyListeners();
  }

  Future<ClientItem> addClient({required String scope, required String name}) async {
    final id = "${scope.substring(0, 3).toLowerCase()}_${DateTime.now().millisecondsSinceEpoch}";
    await LocalDb.instance.insertClient(id: id, name: name, scope: scope);
    final item = ClientItem(id: id, name: name, scope: scope);
    _items.add(item);
    _items.sort((a, b) => a.name.compareTo(b.name));
    notifyListeners();
    return item;
  }
}

final clientStore = ClientStore();
