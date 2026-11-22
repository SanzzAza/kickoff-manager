import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';
import 'package:kickoff_manager/models/models.dart';

void main() {
  test('LiveMatchSession mendukung ganti pemain, ubah taktik, dan adu penalti', () async {
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path =
        '${Directory.systemTemp.path}/live_${DateTime.now().microsecondsSinceEpoch}.db';
    Db.pathOverride = path;
    final db = await Db.openAt(path);
    final svc = GameService(World(db));
    await svc.newGame(
        managerName: 'Sanzz',
        leagueName: 'Super League',
        clubName: 'Persib Bandung');
    final s = await svc.playWeek();
    final partid = s.userMatch!['partid'] as int;

    final session = await svc.startLiveUserMatch(partid, needWinner: true);
    expect(session.userSetup, isNotNull);
    final outPlayer = session.userSetup!.xi.last;
    final inPlayer = session.userSetup!.bench.first;

    // Jalankan 30 menit lalu lakukan pergantian & ubah taktik
    for (var i = 0; i < 30; i++) {
      session.stepMinute();
    }
    expect(session.minute, 30);
    expect(session.stamina.values.any((v) => v < 100), isTrue);

    final subEv = session.substituteUser(outPlayer.jugid, inPlayer.jugid);
    expect(subEv, isNotNull);
    expect(session.userSubsUsed, 1);

    session.updateUserTactics(
        Tactics(mentalidad: Mentality.ofensivo, presion: Pressure.alta));
    expect(session.userSetup!.tactics.mentalidad, Mentality.ofensivo);

    while (!session.isFinished) {
      session.stepMinute();
    }
    final res = session.finalize();
    if (res.homeGoals == res.awayGoals) {
      expect(res.penHome, isNotNull);
      expect(res.penAway, isNotNull);
      expect(res.penHome != res.penAway, isTrue);
    }

    await svc.commitUserMatchResult(partid, res);
    await db.close();
  });

  test('Piala Domestik & manajemen klub (sponsor, tiket, kapten, XI swap)', () async {
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path =
        '${Directory.systemTemp.path}/cup_${DateTime.now().microsecondsSinceEpoch}.db';
    Db.pathOverride = path;
    final db = await Db.openAt(path);
    final svc = GameService(World(db));
    await svc.newGame(
        managerName: 'Sanzz',
        leagueName: 'Primera División',
        clubName: 'Peñarol');

    // Sponsor, harga tiket, kapten, swap XI
    final sponsors = await svc.availableSponsors();
    expect(sponsors.length, 3);
    final msgSp = await svc.selectSponsor(sponsors.first);
    expect(msgSp, contains('ditandatangani'));

    await svc.setTicketPrice(45);
    final user = await svc.userTeam();
    final st = await svc.world.stadium(user.estaid);
    expect(st.precio, 45);

    final setupBefore = await svc.buildSetup(user, await svc.tactics());
    final starterOut = setupBefore.xi.last;
    final reserveIn = setupBefore.bench.first;
    await svc.setCaptain(reserveIn.jugid);
    await svc.swapStarter(starterOut.jugid, reserveIn.jugid);
    final setupAfter = await svc.buildSetup(user, await svc.tactics());
    expect(setupAfter.xi.any((p) => p.jugid == reserveIn.jugid), isTrue);

    // Jalankan 1 musim penuh dan pastikan Piala Domestik mencapai Final
    while (!await svc.seasonFinished()) {
      final w = await svc.playWeek();
      if (w.userMatch != null) {
        await svc.playUserMatch(w.userMatch!['partid'] as int);
      }
    }
    final cupMatches = await db.query('tor_partidos',
        where: 'par_vuelta = 1', orderBy: 'par_fase');
    // 16 Besar (8) + QF (4) + SF (2) + Final (1) = 15 laga piala
    expect(cupMatches.length, 15);
    expect(cupMatches.every((m) => m['par_status'] == 1), isTrue);
    expect(cupMatches.every((m) => (m['par_gana'] as int) > 0), isTrue);

    // Pastikan klasemen liga tetap murni 30 laga per klub (bukan 31-34!)
    final table = await svc.standings();
    expect(table.every((r) => r.pj == 30), isTrue);
    await db.close();
  }, timeout: const Timeout(Duration(minutes: 4)));
}
