import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';
import 'package:kickoff_manager/ui/theme.dart';
import 'package:kickoff_manager/ui/screens/home_shell.dart';
import 'package:kickoff_manager/ui/screens/match_sim_screen.dart';

Future<void> settle(WidgetTester t) async {
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 200)));
  await t.pump();
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 150)));
  await t.pump();
}

void main() {
  testWidgets('kick off -> live feed -> rating -> lanjut -> laga berikutnya aktif',
      (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 3.0;
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path =
        '${Directory.systemTemp.path}/mf_${DateTime.now().microsecondsSinceEpoch}.db';
    Db.pathOverride = path;
    late GameService svc;
    await t.runAsync(() async {
      final db = await Db.openAt(path);
      svc = GameService(World(db));
      await svc.newGame(
          managerName: 'Budi',
          leagueName: 'Super League',
          clubName: 'Persib Bandung');
      await svc.playWeek();
    });
    await t.pumpWidget(
        MaterialApp(theme: buildTheme(), home: MatchSimScreen(service: svc)));
    await settle(t);
    expect(find.text('KICK OFF'), findsOneWidget);

    await t.tap(find.text('KICK OFF'));
    // beri waktu nyata untuk DB menghasilkan hasil laga
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await t.pump();
    // jalankan timer menit (fake time, basis 650ms/menit => ~60 detik)
    for (var i = 0; i < 75; i++) {
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
    await t.tapAt(const Offset(180, 60)); // tutup sheet (scrim di atas sheet)
    await t.pump(const Duration(milliseconds: 500));

    await t.tap(find.text('LANJUT'));
    await settle(t);
    await settle(t);
    expect(find.text('KICK OFF'), findsOneWidget);

    // Pastikan KICK OFF untuk laga berikutnya tetap aktif (tidak terkunci)
    await t.ensureVisible(find.text('Simulasi instan'));
    await t.tap(find.text('Simulasi instan'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 600)));
    await t.pump();
    expect(find.text('PERTANDINGAN SELESAI'), findsOneWidget);
    expect(t.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 6)));

  testWidgets('pindah ke musim berikutnya di HomeShell tetap bisa main',
      (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 3.0;
    sqfliteFfiInit();
    Db.factoryOverride = databaseFactoryFfi;
    final path =
        '${Directory.systemTemp.path}/ms_${DateTime.now().microsecondsSinceEpoch}.db';
    Db.pathOverride = path;
    late GameService svc;
    await t.runAsync(() async {
      final db = await Db.openAt(path);
      svc = GameService(World(db));
      await svc.newGame(
          managerName: 'Budi',
          leagueName: 'Primera División',
          clubName: 'Peñarol');
      while (!await svc.seasonFinished()) {
        final s = await svc.playWeek();
        if (s.userMatch != null) {
          await svc.playUserMatch(s.userMatch!['partid'] as int);
        }
      }
    });
    await t.pumpWidget(
        MaterialApp(theme: buildTheme(), home: HomeShell(service: svc)));
    await settle(t);

    // Buka tab Main di akhir musim 1 -> kosong
    await t.tap(find.text('Main').last);
    await settle(t);
    expect(find.textContaining('Belum ada laga tersisa'), findsOneWidget);

    // Kembali ke Klub, tutup musim, dan mulai musim baru
    await t.tap(find.text('Klub').last);
    await settle(t);
    expect(find.text('TUTUP MUSIM'), findsOneWidget);
    await t.tap(find.text('TUTUP MUSIM'));
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1500)));
    await t.pump();
    await settle(t);
    final nextBtn = find.byKey(const Key('next_season_btn'));
    expect(nextBtn, findsOneWidget);
    await t.ensureVisible(nextBtn);
    await t.tap(nextBtn);
    await t.runAsync(() => Future.delayed(const Duration(milliseconds: 1000)));
    await t.pump();
    await settle(t);

    // Pindah lagi ke tab Main -> harus langsung muncul laga musim 2 & tombol KICK OFF
    await t.tap(find.text('Main').last);
    await settle(t);
    await settle(t);
    expect(find.text('KICK OFF'), findsOneWidget);
    expect(t.takeException(), isNull);
  }, timeout: const Timeout(Duration(minutes: 6)));
}
