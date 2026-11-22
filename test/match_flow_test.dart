import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';
import 'package:kickoff_manager/ui/theme.dart';
import 'package:kickoff_manager/ui/screens/match_sim_screen.dart';

Future<void> settle(WidgetTester t) async {
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  await t.pump();
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
  await t.pump();
}

void main() {
  testWidgets('kick off -> live feed -> rating -> lanjut', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 3.0;
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path = '${Directory.systemTemp.path}/mf_${DateTime.now().microsecondsSinceEpoch}.db';
    Db.pathOverride = path;
    late GameService svc;
    await t.runAsync(() async {
      final db = await Db.openAt(path);
      svc = GameService(World(db));
      await svc.newGame(managerName: 'Budi', leagueName: 'Super League', clubName: 'Persib Bandung');
      await svc.playWeek();
    });
    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: MatchSimScreen(service: svc)));
    await settle(t);
    expect(find.text('KICK OFF'), findsOneWidget);

    await t.tap(find.text('KICK OFF'));
    // beri waktu nyata untuk DB menghasilkan hasil laga
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await t.pump();
    // jalankan timer menit (fake time)
    for (var i = 0; i < 30; i++) {
      await t.pump(const Duration(seconds: 1));
    }
    await settle(t);
    await t.pump(const Duration(milliseconds: 300));
    expect(find.text('PERTANDINGAN SELESAI'), findsOneWidget);
    expect(find.text('RATING'), findsOneWidget);

    await t.tap(find.text('RATING'));
    await t.pump(const Duration(milliseconds: 400));
    await settle(t);
    expect(find.text('Rating pemain'), findsOneWidget);
    await t.tapAt(const Offset(540, 300)); // tutup sheet
    await t.pump(const Duration(milliseconds: 400));

    await t.tap(find.text('LANJUT'));
    await settle(t);
    expect(t.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
