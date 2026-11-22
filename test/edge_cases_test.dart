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

void main() {
  test('engine tidak crash walau skuad menyusut karena kartu merah', () {
    final eng = MatchEngine(Random(3));
    for (var run = 0; run < 200; run++) {
      // skuad super minim: 2 pemain saja
      final home = TeamSetup(
          xi: [mk(1, 1, 60), mk(2, 10, 60)],
          bench: [],
          tactics: Tactics(),
          clubPower: 60,
          name: 'H');
      final away = TeamSetup(
          xi: [mk(11, 1, 60), mk(12, 9, 60)],
          bench: [],
          tactics: Tactics(),
          clubPower: 60,
          name: 'A');
      final r = eng.simulate(home, away);
      expect(r.homeGoals, greaterThanOrEqualTo(0));
    }
  });

  test('quickScore stabil untuk tim sangat lemah vs sangat kuat', () {
    final eng = MatchEngine(Random(5));
    final weak = TeamSetup(
        xi: List.generate(11, (i) => mk(i + 1, i == 0 ? 1 : 10, 30)),
        bench: [], tactics: Tactics(), clubPower: 30, name: 'Lemah');
    final strong = TeamSetup(
        xi: List.generate(11, (i) => mk(i + 20, i == 0 ? 1 : 10, 95)),
        bench: [], tactics: Tactics(), clubPower: 95, name: 'Kuat');
    var total = 0;
    for (var i = 0; i < 100; i++) {
      final (h, a) = eng.quickScore(weak, strong);
      expect(h, inInclusiveRange(0, 9));
      expect(a, inInclusiveRange(0, 9));
      total += a;
    }
    expect(total, greaterThan(0)); // tim kuat tetap bisa mencetak gol
  });
}
