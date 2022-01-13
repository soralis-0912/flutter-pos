import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:posapp/database_factory.dart';
import 'package:posapp/provider/src.dart';

void main() {
  var mockTable = TableModel(-1);
  var storage = DatabaseFactory().create('local-storage');
  var mockTracker = Supplier(database: storage);

  setUpAll(() async {
    // must set up like this to "overwrite" existing data
    storage = DatabaseFactory().create('local-storage', 'test', {}, 'model_test');
    await storage.open();
  });
  tearDownAll(() async {
    storage.close();
    await Future.delayed(const Duration(milliseconds: 500));
    File('test/model_test').deleteSync(); // delete the newly created storage file
  });
  tearDown(() async {
    try {
      await storage.destroy();
    } on Exception catch (e) {
      if (kDebugMode) {
        print('\x1B[94m $e\x1B[0m');
      }
    }
  });

  setUp(() async {
    mockTracker = Supplier(
      database: storage,
      mockModels: [
        TableModel(0)
          ..putIfAbsent(Dish(1, 'test1', 100)).quantity = 5
          ..putIfAbsent(Dish(5, 'test5', 500)).quantity = 10
          ..putIfAbsent(Dish(3, 'test3', 300)).quantity = 15,
      ],
    );
    mockTable = mockTracker.getTable(0);
  });

  test('mockTable total quantity should be 30', () {
    expect(mockTable.totalMenuItemQuantity, 30);
  });

  test('Table should go back to blank state after checkout', () async {
    await mockTracker.checkout(mockTable);
    await mockTable.printClear();
    expect(mockTable.totalMenuItemQuantity, 0);
    expect(mockTable.status, TableStatus.empty);
  });

  test('Order should persist to local storage after checkout', () async {
    await mockTracker.checkout(mockTable, DateTime.parse('20200201 11:00:00'));
    await mockTable.printClear();
    var items = await storage.get(DateTime.parse('20200201 11:00:00'));
    expect(items, isNotNull);
    expect(items[0].checkoutTime, DateTime.parse('20200201 11:00:00'));
    expect(items[0].id, 0);
    expect(() => items[1], throwsRangeError);
  });

  test('OrderID increase by 1 after first order', () async {
    await mockTracker.checkout(mockTable, DateTime.parse('20200201 11:00:00'));
    await mockTable.printClear();

    // create new order
    final mockTable2 = TableModel(0)..putIfAbsent(Dish(1, 'test1', 100)).quantity = 5;

    await mockTracker.checkout(mockTable, DateTime.parse('20200201 13:00:00'));
    await mockTable2.printClear();

    var items = await storage.get(DateTime.parse('20200201 13:00:00'));
    expect(items.length, 2);
    expect(items[0].id, 0);
    expect(items[1].id, 1);
  });
}