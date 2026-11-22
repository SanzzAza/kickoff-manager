import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';

void main() {
  test('full season + next season', () async {
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path = '${Directory.systemTemp.path}/fs_${DateTime.now().microsecondsSinceEpoch}.db';
    Db.pathOverride = path;
    final db = await Db.openAt(path);
    final svc = GameService(World(db));
    final sw = Stopwatch()..start();
    await svc.newGame(managerName: 'Budi', leagueName: 'Super League', clubName: 'Persib Bandung');
    print('generate: ${sw.elapsedMilliseconds}ms');
    var weeks = 0;
    while (!await svc.seasonFinished()) {
      final s = await svc.playWeek();
      if (s.userMatch != null) {
        final r = await svc.playUserMatch(s.userMatch!['partid'] as int);
        if (weeks < 3) print('W${s.week}: ${r.homeGoals}-${r.awayGoals} (${r.events.length} events)');
      }
      weeks++;
      if (weeks > 60) break;
    }
    print('pekan dimainkan: $weeks, total ${sw.elapsedMilliseconds}ms');
    final table = await svc.standings();
    print('klasemen akhir: ${table.take(4).map((r) => "${r.nombre}(${r.pts})").join(", ")}');
    final info = await svc.endSeason();
    print('juara ${info['champion']}, posisi user ${info['userPos']}, hadiah ${info['prize']}, sacked=${info['sacked']}');
    await svc.nextSeason();
    final t2 = await svc.standings();
    final st = await svc.state();
    print('musim baru: tahun ${st.i('season_year')}, tim ${t2.length}, pekan 0? ${st.i('week')==0}');
    // main 3 pekan musim baru
    for (var i=0;i<3;i++){ final s = await svc.playWeek(); if (s.userMatch!=null) await svc.playUserMatch(s.userMatch!['partid'] as int); }
    final t3 = await svc.standings();
    print('setelah 3 pekan: ${t3.take(3).map((r)=>"${r.nombre} ${r.pj}pj ${r.pts}pts").join(", ")}');
    final team = await svc.userTeam();
    print('kas akhir: ${team.presupuesto}');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
