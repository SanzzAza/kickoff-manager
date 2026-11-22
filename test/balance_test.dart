import 'dart:io';
import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';
import 'package:kickoff_manager/engine/match_engine.dart';
import 'package:kickoff_manager/models/models.dart';

void main() {
  setUpAll(() { sqfliteFfiInit(); Db.factoryOverride = databaseFactoryFfi; });
  test('balance', () async {
    final path = '${Directory.systemTemp.path}/kickoff_bal.db';
    if (File(path).existsSync()) File(path).deleteSync();
    Db.pathOverride = path;
    final db = await Db.openAt(path);
    final svc = GameService(World(db));
    await svc.newGame(managerName: 'X', leagueName: 'Super League', clubName: 'Persib Bandung');
    final rows = await db.rawQuery('SELECT equi_nombre, equi_poder FROM eq_equipos WHERE equi_paid=13 ORDER BY equi_poder DESC');
    print('Liga ID: ' + rows.map((r) => '${r['equi_nombre']}=${r['equi_poder']}').join(', '));
    final st = await svc.state();
    print('user poder liga: ${st.i('user_equid')}');
    // distribusi skor: tim terkuat vs terlemah
    final best = await svc.world.team(rows.first['equid'] as int? ?? 0);
    final worst = await svc.world.team(rows.last['equid'] as int? ?? 0);
    final users = await svc.userTeam();
    final a = await svc.buildSetup(users, Tactics());
    final b = await svc.buildSetup(users, Tactics());
    print('XI rating user: atk ${a.attackRating} mid ${a.midfieldRating} def ${a.defenseRating}');
    int hg=0, ag=0; final eng = MatchEngine(Random(7));
    for (var i=0;i<40;i++){ final r = eng.simulate(a,b); hg+=r.homeGoals; ag+=r.awayGoals; }
    print('rata-rata sama kuat: ${(hg/40).toStringAsFixed(2)} - ${(ag/40).toStringAsFixed(2)}');
    // kartu/cedera rate
    final r = eng.simulate(a,b);
    final amarillas = r.events.where((e)=>e.type=='amarilla').length;
    final rojas = r.events.where((e)=>e.type=='roja').length;
    final lesiones = r.events.where((e)=>e.type=='lesion').length;
    print('per laga: kuning=$amarillas merah=$rojas cedera=$lesiones shots=${r.homeShots}/${r.awayShots} poss=${r.homePossession}');
    print('ratings: ${r.stats.values.map((s)=>s.rating.toStringAsFixed(1)).take(11).toList()}');
    print('best poder ${best?.poder} worst ${worst?.poder}');
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
