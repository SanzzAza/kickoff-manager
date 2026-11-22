import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:kickoff_manager/db/db.dart';
import 'package:kickoff_manager/engine/game_service.dart';
import 'package:kickoff_manager/ui/theme.dart';
import 'package:kickoff_manager/ui/screens/home_shell.dart';
import 'package:kickoff_manager/ui/screens/welcome_screen.dart';
import 'package:kickoff_manager/ui/screens/tactics_screen.dart';
import 'package:kickoff_manager/ui/screens/club_pages.dart';

Future<GameService> fresh() async {
  sqfliteFfiInit();
  Db.factoryOverride = databaseFactoryFfi;
  final path =
      '${Directory.systemTemp.path}/ui_test_${DateTime.now().microsecondsSinceEpoch}.db';
  Db.pathOverride = path;
  final db = await Db.openAt(path);
  return GameService(World(db));
}

/// Biarkan future DB nyata selesai lalu render ulang.
Future<void> settle(WidgetTester t) async {
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 220)));
  await t.pump();
  await t.runAsync(() => Future.delayed(const Duration(milliseconds: 120)));
  await t.pump();
}

void main() {
  testWidgets('welcome & wizard render', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 3.0;
    late GameService svc;
    await t.runAsync(() async => svc = await fresh());
    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: WelcomeScreen(service: svc)));
    await settle(t);
    expect(find.text('MULAI KARIER'), findsOneWidget);

    await t.tap(find.text('MULAI KARIER'));
    await settle(t);
    expect(find.text('Siapa nama manajermu?'), findsOneWidget);

    await t.tap(find.text('Lanjut'));
    await settle(t);
    expect(find.text('Pilih liga'), findsOneWidget);
    expect(find.text('LaLiga'), findsOneWidget);
  });

  testWidgets('home shell + semua tab + halaman klub', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 3.0;
    late GameService svc;
    await t.runAsync(() async {
      svc = await fresh();
      await svc.newGame(
          managerName: 'Budi', leagueName: 'Super League', clubName: 'Persib Bandung');
    });
    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: HomeShell(service: svc)));
    await settle(t);
    expect(find.text('Persib Bandung'), findsWidgets);

    for (final label in ['Skuad', 'Main', 'Klasemen', 'Transfer', 'Klub']) {
      await t.tap(find.text(label).last);
      await settle(t);
      await settle(t);
    }


    await t.pumpWidget(MaterialApp(theme: buildTheme(), home: TacticsScreen(service: svc)));
    await settle(t);
    expect(find.text('Formasi'), findsOneWidget);
    await t.tap(find.text('4-4-2'));
    await settle(t);


    for (final w in [
      TrainingScreen(service: svc),
      StadiumScreen(service: svc),
      FinanceScreen(service: svc),
      HistoryScreen(service: svc),
    ]) {
      await t.pumpWidget(MaterialApp(theme: buildTheme(), home: w));
      await settle(t);
  
    }
  });

  testWidgets('halaman pertandingan bisa dibuka', (t) async {
    t.view.physicalSize = const Size(1080, 2200);
    t.view.devicePixelRatio = 3.0;
    late GameService svc;
    await t.runAsync(() async {
      svc = await fresh();
      await svc.newGame(
          managerName: 'Budi', leagueName: 'Premier League', clubName: 'Arsenal');
      await svc.playWeek();
    });
    await t.pumpWidget(
        MaterialApp(theme: buildTheme(), home: HomeShell(service: svc)));
    await settle(t);
    await t.tap(find.text('Main').last);
    await settle(t);
    await settle(t);
    expect(find.text('KICK OFF'), findsOneWidget);

  });
}
