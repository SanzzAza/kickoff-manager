import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';

void main() {
  test('Akademi Muda, Agen Bebas, Pinjaman, dan Laporan Intai', () async {
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path =
        '${Directory.systemTemp.path}/w3a_${DateTime.now().microsecondsSinceEpoch}.db';
    Db.pathOverride = path;
    final db = await Db.openAt(path);
    final svc = GameService(World(db));
    await svc.newGame(
        managerName: 'Sanzz',
        leagueName: 'Super League',
        clubName: 'Persib Bandung');

    // 1. Akademi: upgrade, scout, promote wonderkid
    final user = await svc.userTeam();
    final squadBefore = await svc.world.squad(user.equid);
    final ac1 = await svc.academyInfo();
    expect(ac1['level'], 1);
    final upMsg = await svc.upgradeAcademy();
    expect(upMsg, contains('Level 2'));
    final scMsg = await svc.scoutAcademy();
    expect(scMsg, contains('3 calon wonderkid'));
    final ac2 = await svc.academyInfo();
    expect((ac2['prospects'] as List).length, 3);
    await svc.promoteProspect(0);
    final squadAfterPromo = await svc.world.squad(user.equid);
    expect(squadAfterPromo.length, squadBefore.length + 1);

    // 2. Agen Bebas (Gratis)
    final freeAgents = await svc.marketPlayers(freeAgentsOnly: true, minPoder: 40);
    expect(freeAgents.isNotEmpty, isTrue);
    final faId = freeAgents.first['jugid'] as int;
    final faErr = await svc.signFreeAgent(faId);
    expect(faErr, isNull);
    expect((await svc.world.squad(user.equid)).any((p) => p.jugid == faId), isTrue);

    // 3. Pinjam pemain 1 musim (cari pemain rating realistis agar kas cukup)
    final targets =
        await svc.marketPlayers(minPoder: 55, maxPoder: 68, limit: 10);
    final loanTarget = targets.firstWhere((r) => (r['club'] as int? ?? 0) != 0);
    final loanId = loanTarget['jugid'] as int;
    final origClub = loanTarget['club'] as int;
    final loanErr = await svc.loanPlayer(loanId);
    expect(loanErr, isNull);
    expect((await svc.world.squad(user.equid)).any((p) => p.jugid == loanId), isTrue);

    // 4. Scout report & manager stats
    final w1 = await svc.playWeek();
    final f = w1.userMatch!;
    final oppId = f['par_equid_local'] == user.equid
        ? f['par_equid_visita'] as int
        : f['par_equid_local'] as int;
    final scout = await svc.scoutReportFor(oppId);
    expect(scout['atk'], isNotNull);
    expect((scout['keyPlayers'] as List).isNotEmpty, isTrue);

    await svc.playUserMatch(f['partid'] as int);
    final stats = await svc.managerStats();
    expect(stats['played'], 1);

    // Selesaikan musim dan pastikan pemain pinjaman kembali ke klub asal
    while (!await svc.seasonFinished()) {
      final w = await svc.playWeek();
      if (w.userMatch != null) {
        await svc.playUserMatch(w.userMatch!['partid'] as int);
      }
    }
    await svc.endSeason();
    expect((await svc.world.teamOfPlayer(loanId)), origClub);
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 4)));

  test('Piala Kontinental berjalan hingga Final tanpa mengganggu klasemen liga', () async {
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path =
        '${Directory.systemTemp.path}/w3b_${DateTime.now().microsecondsSinceEpoch}.db';
    Db.pathOverride = path;
    final db = await Db.openAt(path);
    final svc = GameService(World(db));
    await svc.newGame(
        managerName: 'Sanzz',
        leagueName: 'Primera División',
        clubName: 'Peñarol');

    while (!await svc.seasonFinished()) {
      final w = await svc.playWeek();
      if (w.userMatch != null) {
        await svc.playUserMatch(w.userMatch!['partid'] as int);
      }
    }

    final conti = await db.query('tor_partidos',
        where: 'par_vuelta = 2', orderBy: 'par_fase');
    expect(conti.length, 15);
    expect(conti.every((m) => m['par_status'] == 1), isTrue);
    expect(conti.every((m) => (m['par_gana'] as int) > 0), isTrue);

    // Klasemen liga Primera División (16 tim) tetap tepat 30 laga per tim
    final table = await svc.standings();
    expect(table.every((r) => r.pj == 30), isTrue);
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 4)));
}
