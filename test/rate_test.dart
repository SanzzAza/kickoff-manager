import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:kickoff_manager/engine/match_engine.dart';
import 'package:kickoff_manager/models/models.dart';

Player mk(int i, int pos, int poder) => Player(
  jugid: i, nombre: 'P$i', edad: 25, estatura: 180, star: 0, valor: 1000000,
  salario: 1000, perfil: 'D', experiencia: 1, condicion: 100, jstdid: 1,
  poder: poder, potencial: poder, mercado: 0, paid: 0, posid: pos, titular: 1,
  capitan: 0, numero: i, campeonatos: 0, pts: 0, habA: 1, habB: 2,
  ritmo: poder, tembakan: poder, pases: poder, regate: poder, defensa: poder,
  fisik: poder, kiper: pos == 1 ? poder : 30);

List<Player> squad(int base, int offset) {
  final pos = [1,2,2,4,4,5,7,7,9,10,11];
  return List.generate(11, (i) => mk(1000*offset + i, pos[i], base + (i%3)));
}

void main() {
  test('rates', () {
    final eng = MatchEngine(Random(99));
    var hg=0, ag=0, hs=0, as_=0, w=0, d=0, l=0;
    final hStats = <int, int>{};
    for (var i=0;i<300;i++) {
      final home = TeamSetup(xi: squad(70,1), bench: [], tactics: Tactics(), clubPower: 70, name: 'H');
      final away = TeamSetup(xi: squad(70,2), bench: [], tactics: Tactics(), clubPower: 70, name: 'A');
      final r = eng.simulate(home, away);
      hg+=r.homeGoals; ag+=r.awayGoals; hs+=r.homeShots; as_+=r.awayShots;
      if (r.homeGoals>r.awayGoals) w++; else if (r.homeGoals==r.awayGoals) d++; else l++;
      final goals = <int,int>{};
      for (final e in r.events) if (e.type=='gol'||e.type=='penalti_gol') {
        final k = e.minute; goals[k]=(goals[k]??0)+1; }
      for (final k in goals.keys) hStats[k]=(hStats[k]??0)+goals[k]!;
    }
    print('300 laga: gol ${hg/300} - ${ag/300}, shots ${hs/300} - ${as_/300}, W$w D$d L$l');
    print('gol per menit (>1 = banyak): ${hStats.entries.where((e)=>e.value>0).take(10).toList()}');
  });
}
