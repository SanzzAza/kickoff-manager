import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';

void main() {
  test('schema', () async {
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path = '${Directory.systemTemp.path}/schema_${DateTime.now().microsecondsSinceEpoch}.db';
    final db = await Db.openAt(path);
    final t = await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
    print(t.map((r) => r['name']).toList());
    await db.update('eq_equipos', {'equi_poder': 5}, where: 'equid = ?', whereArgs: [1]);
    print('update ok');
  });
}
