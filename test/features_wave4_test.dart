import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';
import 'package:kickoff_manager/engine/match_engine.dart';
import 'package:kickoff_manager/models/models.dart';
import 'package:kickoff_manager/ui/theme.dart';
import 'package:kickoff_manager/ui/screens/new_game_screen.dart';
import 'package:kickoff_manager/ui/screens/career_extras_screens.dart';

Future<GameService> freshDb(String tag) async {
  sqfliteFfiInit();
  Db.factoryOverride = databaseFactoryFfi;
  final path =
      '${Directory.systemTemp.path}/${tag}_${DateTime.now().microsecondsSinceEpoch}.db';
  Db.pathOverride = path;
  final db = await Db.openAt(path);
  return GameService(World(db));
}

void main() {
  test('Karakter Manajer, Trait Bonus, Uji Coba, Pemain Kustom, Pindah Klub, Editor',
      () async {
    final svc = await freshDb('w4_core');
    const prof = ManagerProfile(
      name: 'Coach Bima',
      nationality: 'ID',
      hairStyle: 1,
      skinTone: 2,
      outfitStyle: 0,
      suitColor: 1,
      glasses: true,
      beard: true,
      trait: ManagerTrait.scout,
    );
    await svc.newGame(
      managerName: 'Coach Bima',
      leagueName: 'Super League',
      clubName: 'Persib Bandung',
      profile: prof,
    );

    final st = await svc.state();
    expect(st.managerProfile().glasses, isTrue);
    expect(st.managerProfile().trait, ManagerTrait.scout);
    // Trait Pemburu Bakat langsung mulai Akademi Lv 2
    expect(st.i('academy_level'), 2);

    // Pemain kustom akademi
    final userBefore = await svc.userTeam();
    final sqBefore = await svc.world.squad(userBefore.equid);
    final customMsg = await svc.createCustomAcademyPlayer(
      nombre: 'Garuda Putra',
      edad: 17,
      posid: 10,
      perfil: 'I',
      skillId: 9,
      numero: 77,
    );
    expect(customMsg, contains('Garuda Putra'));
    final sqAfter = await svc.world.squad(userBefore.equid);
    expect(sqAfter.length, sqBefore.length + 1);
    final created = sqAfter.firstWhere((p) => p.nombre == 'Garuda Putra');
    expect(PlayerSkillCatalog.skillsFor(created).first.id, 9);

    // Uji coba (friendly) tidak mengubah poin klasemen
    final fInfo = await svc.friendlyInfo();
    final opps = fInfo['opponents'] as List<Team>;
    expect(opps.isNotEmpty, isTrue);
    final fRes = await svc.playFriendly(opps.first.equid);
    expect(fRes['error'], isNull);
    final tableAfterFriendly = await svc.standings();
    expect(tableAfterFriendly.every((r) => r.pj == 0), isTrue);

    // Editor klub & pemain
    await svc.updateClubInfo(
      userBefore.equid,
      nombre: 'Persib Juara',
      abrev: 'PSJ',
      colorA: '#1565C0',
      colorB: '#FFFFFF',
    );
    final editedTeam = await svc.userTeam();
    expect(editedTeam.nombre, 'Persib Juara');
    await svc.updatePlayerInfo(
      created.jugid,
      nombre: 'Garuda Super',
      posid: 9,
      numero: 10,
      poder: 82,
    );
    final sqEdited = await svc.world.squad(userBefore.equid);
    expect(sqEdited.any((p) => p.nombre == 'Garuda Super' && p.poder == 82), isTrue);

    // Pindah klub lewat bursa manajer
    final jobs = await svc.availableJobs(leagueFilter: 'Super League');
    expect(jobs.isNotEmpty, isTrue);
    final target = jobs.first['team'] as Team;
    await svc.resignAndJoin(target.equid);
    expect((await svc.userTeam()).equid, target.equid);

    await svc.db.close();
  });

  test('Extra Time di laga gugur & Penghargaan Lengkap Akhir Musim', () async {
    final svc = await freshDb('w4_et');
    await svc.newGame(
      managerName: 'Taktisi',
      leagueName: 'Primera División',
      clubName: 'Peñarol',
      profile: const ManagerProfile(
        name: 'Taktisi',
        trait: ManagerTrait.tactician,
      ),
    );
    final t = await svc.userTeam();
    final setup = await svc.buildSetup(t, Tactics());
    expect(setup.tacticBonus, 3);

    // Simulasikan full season lalu verifikasi penghargaan lengkap tercatat
    while (!await svc.seasonFinished()) {
      final w = await svc.playWeek();
      if (w.userMatch != null) {
        await svc.playUserMatch(w.userMatch!['partid'] as int);
      }
    }
    final endInfo = await svc.endSeason();
    expect(endInfo['bestPlayer'], isNotNull);
    expect(endInfo['bestGk'], isNotNull);
    expect(endInfo['youngPlayer'], isNotNull);
    final awards = await svc.allSeasonAwards();
    expect(awards.any((a) => a['tipo'] == 'ballon_dor'), isTrue);
    expect(awards.any((a) => a['tipo'] == 'golden_glove'), isTrue);
    expect(awards.any((a) => a['tipo'] == 'golden_boy'), isTrue);

    await svc.db.close();
  }, timeout: const Timeout(Duration(minutes: 4)));

  testWidgets('UI Kustomisasi Manajer & Layar Ekstra Render Bersih', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 3.0;
    late GameService svc;
    await t.runAsync(() async {
      svc = await freshDb('w4_ui');
      await svc.newGame(
        managerName: 'Coach Uji',
        leagueName: 'Super League',
        clubName: 'Persib Bandung',
      );
    });

    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: NewGameScreen(service: svc)));
    await t.pumpAndSettle();
    expect(find.text('Buat Karakter Manajer'), findsOneWidget);
    expect(find.text('Kustomisasi Penampilan'), findsOneWidget);

    for (final screen in [
      FriendlyMatchScreen(service: svc),
      JobMarketScreen(service: svc),
      ClubEditorScreen(service: svc),
    ]) {
      await t.pumpWidget(MaterialApp(theme: buildTheme(), home: screen));
      await t.runAsync(() => Future.delayed(const Duration(milliseconds: 220)));
      await t.pump();
    }
  });
}
