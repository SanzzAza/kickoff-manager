import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
  });

  test('world generation + full season', () async {
    final path = '${Directory.systemTemp.path}/kickoff_test.db';
    final f = File(path);
    if (await f.exists()) await f.delete();
    Db.pathOverride = path;
    final db = await Db.openAt(path);
    final svc = GameService(World(db));

    final sw = Stopwatch()..start();
    await svc.newGame(
        managerName: 'Test Manager',
        leagueName: 'Super League',
        clubName: 'Persib Bandung');
    print('WAKTU generate world: ${sw.elapsedMilliseconds} ms');

    final teams = await db.rawQuery('SELECT COUNT(*) c FROM eq_equipos');
    final players = await db.rawQuery('SELECT COUNT(*) c FROM jug_jugadores');
    print('Tim: ${teams.first['c']}, Pemain: ${players.first['c']}');

    var table = await svc.standings();
    print('Tim di liga: ${table.length}');
    expect(table.length, 18);

    // simulasi 5 pekan penuh, laga user dimainkan detail
    for (var w = 0; w < 5; w++) {
      final summary = await svc.playWeek();
      if (summary.userMatch != null) {
        final res = await svc.playUserMatch(summary.userMatch!['partid'] as int);
        print('Pekan ${summary.week}: hasil user '
            '${res.homeGoals}-${res.awayGoals}, events ${res.events.length}, '
            'shots ${res.homeShots}/${res.awayShots}');
      }
    }
    table = await svc.standings();
    print('--- Klasemen setelah 5 pekan ---');
    for (var i = 0; i < 6; i++) {
      final r = table[i];
      print('${i + 1}. ${r.nombre}  PJ${r.pj} ${r.pg}-${r.pe}-${r.pp} '
          'GF${r.gf} GC${r.gc} PTS${r.pts}');
    }
    final team = await svc.userTeam();
    print('Kas: ${team.presupuesto}');
    final unread = await svc.unread();
    print('Pesan: $unread');
    final market = await svc.marketPlayers(minPoder: 55, limit: 5);
    print('Market sample: ${market.map((m) => m['jug_nombre']).take(3).toList()}');
    if (market.isNotEmpty) {
      final target = market.first;
      final res = await svc.makeOffer(target['jugid'] as int,
          ((target['jug_valor'] as int) * 1.4).round());
      print('Tawaran transfer hasil: ${res ?? "SUKSES"}');
    }
    final tr = await svc.world.topScorers(
        (await svc.state()).i('tempid'));
    print('Top skor: ${tr.take(3).map((p) => p.nombre).toList()}');
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 10)));
}
