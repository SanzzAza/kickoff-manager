import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';
import 'package:kickoff_manager/models/models.dart';

void main() {
  test('season stats', () async {
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path = '${Directory.systemTemp.path}/ss_${DateTime.now().microsecondsSinceEpoch}.db';
    Db.pathOverride = path;
    final db = await Db.openAt(path);
    final svc = GameService(World(db));
    await svc.newGame(managerName: 'B', leagueName: 'Super League', clubName: 'Persib Bandung');
    final user = await svc.userTeam();
    final st = await svc.state();
    print('user poder ${user.poder}');
    for (final eq in [user.equid, (await svc.standings())[1].equid, (await svc.standings())[9].equid]) {
      final t = (await svc.world.team(eq))!;
      final s = await svc.buildSetup(t, Tactics());
      print('${t.nombre}: poder ${t.poder} atk ${s.attackRating} mid ${s.midfieldRating} def ${s.defenseRating}');
      print('   XI: ${s.xi.map((p)=>"${p.nombre.split(' ').last}(${p.posid},${p.poder})").join(' ')}');
    }
    // 20 user matches simulated
    var gf=0, ga=0, n=0;
    while (n < 10) {
      final s = await svc.playWeek();
      if (s.userMatch == null) continue;
      final r = await svc.playUserMatch(s.userMatch!['partid'] as int);
      gf += r.homeGoals; ga += r.awayGoals; n++;
      print('M$n: ${r.homeGoals}-${r.awayGoals} shots ${r.homeShots}/${r.awayShots} poss ${r.homePossession}');
    }
    print('rata2 user: ${gf/n} - ${ga/n}');
    final all = await db.rawQuery('SELECT AVG(par_goles_local+par_goles_visita) a, COUNT(*) c FROM tor_partidos WHERE par_status=1');
    print('rata2 gol liga: ${all.first['a']} dari ${all.first['c']} laga');
  }, timeout: const Timeout(Duration(minutes: 15)));
}
