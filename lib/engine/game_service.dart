// GameService: otak permainan. Alur mengikuti game asli:
// Wizard nueva partida -> fase pramusim (taktik, transfer) -> simulasi
// pekan demi pekan -> akhir musim (promosi, premios, ganti tahun).

import 'dart:convert';
import 'dart:math';
import 'package:sqflite/sqflite.dart';
import '../data/football_data.dart';
import '../db/db.dart';
import '../models/models.dart';
import 'match_engine.dart';
import 'world_generator.dart';

class StandingsRow {
  final int equid;
  final String nombre;
  final String colorA;
  final String colorB;
  int pj = 0, pg = 0, pe = 0, pp = 0, gf = 0, gc = 0, pts = 0;
  List<String> forma = [];
  StandingsRow(this.equid, this.nombre,
      {this.colorA = '#1B5E20', this.colorB = '#FFFFFF'});
  int get dg => gf - gc;
}

class WeekSummary {
  final int week;
  final Map<String, dynamic>? userMatch; // laga user yang belum dimainkan
  final List<String> highlights;
  WeekSummary(this.week, this.userMatch, this.highlights);
}

class GameService {
  final World world;
  final MatchEngine engine;
  GameService(this.world, [Random? rng]) : engine = MatchEngine(rng);

  Database get db => world.db;

  // ---------------- START / STATE ----------------

  Future<bool> hasSave() async {
    final st = await world.state();
    return st['started'] == '1';
  }

  Future<void> newGame({
    required String managerName,
    required String leagueName,
    required String clubName,
  }) async {
    final leagueIdx = leagues.indexWhere((l) => l.name == leagueName);
    final liga = leagues[leagueIdx >= 0 ? leagueIdx : 0];
    final gen = WorldGenerator(db);
    await db.transaction((txn) async {
      gen.executor = txn;
      await gen.buildWorld(
        playerName: managerName,
        leagueName: liga.name,
        clubName: clubName,
        seedPaisIndex: leagues.indexOf(liga) + 1,
      );
    });

    final rows = await db.query('eq_equipos',
        where: 'equi_is_user = 1', whereArgs: []);
    final userEquid = rows.first['equid'] as int;

    await world.setState('started', '1');
    await world.setState('manager', managerName);
    await world.setState('league', liga.name);
    await world.setState('country', liga.country);
    await world.setInt('user_equid', userEquid);
    await world.setInt('season_year', 2026);
    await world.setInt('week', 0);
    await world.setInt('reputation', 55);
    await world.setInt('confidence', 70);
    await world.setInt('trophies', 0);
    await world.setState('tactics', jsonEncode(Tactics().toJson()));
    await world.setInt('training', 0); // 0 seimbang,1 fisik,2 teknis,3 taktik

    await startSeason(2026, first: true);
    await world.addMessage(
      'Selamat datang, $managerName!',
      'Kamu resmi menjadi manajer $clubName di ${liga.name}. '
          'Target dari direksi: finis di 10 besar. Pasar transfer terbuka sampai pekan 1.',
      'info',
      0,
    );
  }

  Future<SaveState> state() => world.state();

  Future<Team> userTeam() async {
    final st = await world.state();
    final t = await world.team(st.i('user_equid'));
    return t!;
  }

  Future<Tactics> tactics() async => (await world.state()).tactics();

  Future<void> saveTactics(Tactics t) async {
    await world.setState('tactics', jsonEncode(t.toJson()));
  }

  Future<int> currentWeek() async => (await world.state()).i('week');

  Future<int> currentSeasonId() async => (await world.state()).i('tempid');

  // ---------------- SEASON / FIXTURES ----------------

  Future<void> startSeason(int year, {bool first = false}) async {
    final prev = await world.state();
    final liga = leagues.firstWhere((l) => l.name == prev['league'],
        orElse: () => leagues.first);
    final tempid = first ? 1 : prev.i('tempid') + 1;
    await world.setInt('tempid', tempid);
    await world.setInt('season_year', year);
    await world.setInt('week', 0);
    await world.setInt('season_started', 1);

    final seedPais = leagues.indexOf(liga) + 1;
    final toridLiga = await _leagueTorneoId(liga.name);
    final teamRows = await db.query('eq_equipos',
        where: 'equi_paid = ?', whereArgs: [seedPais], orderBy: 'equid');
    final teamIds = teamRows.map((r) => r['equid'] as int).toList();
    final powers = <int, int>{};
    for (final id in teamIds) {
      powers[id] = await _powerForTeam(id, teamIds);
    }
    final fixtures = _roundRobin(teamIds);

    await db.transaction((txn) async {
      await txn.insert('tor_temporadas', {
        'tempid': tempid,
        'tem_nombre': '${liga.name} ${year}/${year + 1}',
        'tem_anioinicio': year,
        'tem_aniofin': year + 1,
      });

      await txn.update('eq_equipos', {'equi_poder': 0},
          where: 'equi_paid = ?', whereArgs: [seedPais]);
      for (final id in teamIds) {
        await txn.update(
            'eq_equipos', {'equi_poder': powers[id] ?? 50, 'equi_pts': 0},
            where: 'equid = ?', whereArgs: [id]);
        await txn.insert('tor_temporadas_equipos', {
          'te_equid': id,
          'te_tempid': tempid,
          'te_pj': 0,
          'te_pg': 0,
          'te_pe': 0,
          'te_pp': 0,
          'te_gf': 0,
          'te_gc': 0,
          'te_pts': 0,
          'te_forma': '',
        });
        await txn.update('jug_jugadores',
            {'jug_condicion': 100, 'jug_susp': 0, 'jug_lesion': 0},
            where:
                'jugid IN (SELECT eqju_jugid FROM eq_equipos_jugadores WHERE eqju_equid = ?)',
            whereArgs: [id]);
      }

      var jornada = 0;
      for (final round in fixtures) {
        jornada++;
        for (final m in round) {
          await _insertFixture(toridLiga, tempid, m[0], m[1], jornada, txn: txn);
        }
        for (final m in round) {
          await _insertFixture(
              toridLiga, tempid, m[1], m[0], jornada + fixtures.length,
              txn: txn);
        }
      }
    });
    await world.setInt('total_weeks', fixtures.length * 2);
  }

  Future<int> _leagueTorneoId(String name) async {
    final r = await db.query('tor_torneos',
        where: 'tor_nombre = ?', whereArgs: [name], limit: 1);
    return r.first['torid'] as int;
  }

  Future<int> _powerForTeam(int equid, List<int> all) async {
    final squad = await world.squad(equid);
    if (squad.isEmpty) return 50;
    final sorted = [...squad]..sort((a, b) => b.poder - a.poder);
    final top = sorted.take(11).toList();
    final avg = top.fold<int>(0, (a, p) => a + p.poder) / top.length;
    return avg.round().clamp(30, 99);
  }

  Future<void> _insertFixture(
      int torid, int tempid, int home, int away, int jornada,
      {DatabaseExecutor? txn}) async {
    await (txn ?? db).insert('tor_partidos', {
      'par_torid': torid,
      'par_tempid': tempid,
      'par_estaid': 0,
      'par_equid_local': home,
      'par_equid_visita': away,
      'par_goles_local': 0,
      'par_goles_visita': 0,
      'par_gana': 0,
      'par_fase': jornada,
      'par_jornada': jornada,
      'par_status': 0,
      'par_fecha': 'J$jornada',
      'par_vuelta': 0,
    });
  }

  List<List<List<int>>> _roundRobin(List<int> teams) {
    final t = List.of(teams);
    if (t.length.isOdd) t.add(-1);
    final n = t.length;
    final rounds = <List<List<int>>>[];
    final rotation = List.of(t);
    for (var r = 0; r < n - 1; r++) {
      final round = <List<int>>[];
      for (var i = 0; i < n ~/ 2; i++) {
        final a = rotation[i];
        final b = rotation[n - 1 - i];
        if (a == -1 || b == -1) continue;
        // selang-seling kandang/tandang
        if ((r + i) % 2 == 0) {
          round.add([a, b]);
        } else {
          round.add([b, a]);
        }
      }
      rounds.add(round);
      final last = rotation.removeLast();
      rotation.insert(1, last);
    }
    return rounds;
  }

  // ---------------- MATCH PREPARATION ----------------

  Future<TeamSetup> buildSetup(Team team, Tactics tac, {bool autoXI = true}) async {
    final squad = await world.squad(team.equid);
    var xi = squad.where((p) => p.disponible && p.posid == 1).take(1).toList();
    // Utamakan pemain bertanda titular
    final listed = squad.where((p) => p.titular == 1 && p.disponible).toList()
      ..sort((a, b) => b.poder - a.poder);
    final others = squad.where((p) => p.titular != 1 && p.disponible).toList()
      ..sort((a, b) => b.poder - a.poder);
    final pool = [...listed, ...others];
    final roles = tac.formacion.roles;
    final chosen = <Player>[];
    final used = <int>{};
    if (xi.isNotEmpty) {
      chosen.add(xi.first);
      used.add(xi.first.jugid);
    }
    for (var i = 1; i < roles.length; i++) {
      final role = roles[i];
      Player? best;
      for (final p in pool) {
        if (used.contains(p.jugid)) continue;
        if (_roleOf(p.posid) != role) continue;
        best = p;
        break;
      }
      best ??= pool.firstWhere((p) => !used.contains(p.jugid) && p.posid != 1,
          orElse: () => pool.firstWhere((p) => !used.contains(p.jugid),
              orElse: () => pool.first));
      chosen.add(best);
      used.add(best.jugid);
    }
    while (chosen.length < 11 && pool.length > chosen.length) {
      chosen.add(pool.firstWhere((p) => !used.contains(p.jugid)));
    }
    final bench = pool.where((p) => !used.contains(p.jugid)).take(7).toList();
    return TeamSetup(
      xi: chosen.take(11).toList(),
      bench: bench,
      tactics: tac,
      clubPower: team.poder,
      name: team.nombre,
    );
  }

  int _roleOf(int posid) {
    if (posid == 1) return 1;
    if (posid <= 4) return 2;
    if (posid <= 8) return 3;
    return 4;
  }

  // ---------------- WEEK SIMULATION ----------------

  Future<WeekSummary> playWeek({bool userSimulatedFast = false}) async {
    final st = await world.state();
    final tempid = st.i('tempid');
    final week = st.i('week') + 1;
    final userEquid = st.i('user_equid');

    // Bereskan laga pekan-pekan sebelumnya yang masih menggantung
    final leftovers = await db.query('tor_partidos',
        where: 'par_tempid = ? AND par_status = 0 AND par_jornada < ?',
        whereArgs: [tempid, week]);
    for (final f in leftovers) {
      final h = (await world.team(f['par_equid_local'] as int))!;
      final a = (await world.team(f['par_equid_visita'] as int))!;
      final (hg, ag) = engine.quickScore(
          await buildSetup(h, Tactics()), await buildSetup(a, Tactics()));
      await _saveResult(f, hg, ag, null);
    }

    final fixtures = await db.query('tor_partidos',
        where: 'par_tempid = ? AND par_jornada = ?', whereArgs: [tempid, week]);
    // Kalau jornada sudah lewat (leg kedua pakai nomor jornada besar), cari yang belum main
    final pending = await db.query('tor_partidos',
        where: 'par_tempid = ? AND par_status = 0 AND par_jornada = ?',
        whereArgs: [tempid, week]);
    final list = pending.isNotEmpty ? pending : fixtures;

    Map<String, dynamic>? userMatchInfo;
    final highlights = <String>[];

    for (final f in list) {
      final home = f['par_equid_local'] as int;
      final away = f['par_equid_visita'] as int;
      final isUser = home == userEquid || away == userEquid;

      if (isUser && !userSimulatedFast) {
        userMatchInfo = Map<String, dynamic>.from(f);
        continue; // laga user dimainkan lewat PlayMatchPage
      }

      final homeTeam = (await world.team(home))!;
      final awayTeam = (await world.team(away))!;
      final hSetup = await buildSetup(homeTeam, Tactics());
      final aSetup = await buildSetup(awayTeam, Tactics());
      final (hg, ag) = engine.quickScore(hSetup, aSetup);
      await _saveResult(f, hg, ag, null);
      if (isUser) {
        highlights.add('${homeTeam.nombre} $hg-$ag ${awayTeam.nombre} (disimulasikan)');
      }
    }

    await world.setInt('week', week);
    await _advanceConditions();
    await refreshPowers();
    await _weeklyFinances();
    return WeekSummary(week, userMatchInfo, highlights);
  }

  /// Mainkan laga user secara detail
  Future<MatchResult> playUserMatch(int partid, {bool needWinner = false}) async {
    final st = await world.state();
    final tac = st.tactics();
    final rows =
        await db.query('tor_partidos', where: 'partid = ?', whereArgs: [partid]);
    final f = rows.first;
    final homeId = f['par_equid_local'] as int;
    final awayId = f['par_equid_visita'] as int;
    final homeTeam = (await world.team(homeId))!;
    final awayTeam = (await world.team(awayId))!;
    final hSetup = await buildSetup(homeTeam, homeId == st.i('user_equid') ? tac : Tactics());
    final aSetup = await buildSetup(awayTeam, awayId == st.i('user_equid') ? tac : Tactics());
    final result = engine.simulate(hSetup, aSetup, needWinner: needWinner, homeAdvantage: true);

    await _saveResult(f, result.homeGoals, result.awayGoals, result,
        penHome: result.penHome, penAway: result.penAway);
    await _applyMatchAftermath(result, homeTeam, awayTeam);
    await _financesForMatch(homeTeam, awayTeam, result, partid);
    return result;
  }

  /// Selesaikan sisa laga pekan berjalan (setelah laga user dimainkan).
  Future<List<String>> finishRound({int? playedJornada}) async {
    final st = await world.state();
    final tempid = st.i('tempid');
    final currentW = st.i('week');
    final targetWeek = playedJornada != null && playedJornada > currentW
        ? playedJornada
        : currentW;
    final pending = await db.query('tor_partidos',
        where: 'par_tempid = ? AND par_status = 0 AND par_jornada <= ?',
        whereArgs: [tempid, targetWeek]);
    final out = <String>[];
    for (final f in pending) {
      final h = (await world.team(f['par_equid_local'] as int))!;
      final a = (await world.team(f['par_equid_visita'] as int))!;
      final (hg, ag) = engine.quickScore(
          await buildSetup(h, Tactics()), await buildSetup(a, Tactics()));
      await _saveResult(f, hg, ag, null);
      out.add('${h.nombre} $hg-$ag ${a.nombre}');
    }
    if (targetWeek > currentW) {
      await world.setInt('week', targetWeek);
      await _advanceConditions();
      await refreshPowers();
      await _weeklyFinances();
    }
    return out;
  }

  Future<void> _saveResult(Map<String, dynamic> f, int hg, int ag,
      MatchResult? result,
      {int? penHome,
      int? penAway}) async {
    final partid = f['partid'] as int;
    final tempid = f['par_tempid'] as int;
    final lid = f['par_equid_local'] as int;
    final vid = f['par_equid_visita'] as int;
    await db.update(
        'tor_partidos',
        {
          'par_goles_local': hg,
          'par_goles_visita': ag,
          'par_gana': hg > ag ? lid : (ag > hg ? vid : 0),
          'par_status': 1,
          'par_penal_goles_local': penHome,
          'par_penal_goles_visita': penAway,
        },
        where: 'partid = ?',
        whereArgs: [partid]);

    await _updateTable(lid, hg, ag, tempid);
    await _updateTable(vid, ag, hg, tempid);

    if (result != null) {
      for (final st in result.stats.values) {
        await db.insert('tor_partidos_jugadores', {
          'tpj_partid': partid,
          'tpj_jugid': st.playerId,
          'tpj_equid': st.team == 0 ? lid : vid,
          'tpj_titular': 1,
          'tpj_min': st.minutos,
          'tpj_goles': st.goles,
          'tpj_asis': st.asistencias,
          'tpj_amarilla': st.amarillas,
          'tpj_roja': st.rojas,
          'tpj_rating': double.parse(st.rating.toStringAsFixed(2)),
          'tpj_mvp': result.mvpId == st.playerId ? 1 : 0,
          'tpj_atajadas': st.atajadas,
          'tpj_tiros': st.tiros,
        });
        await _bumpStats(st.playerId, tempid, st.team == 0 ? lid : vid,
            goles: st.goles,
            asis: st.asistencias,
            amarillas: st.amarillas,
            rojas: st.rojas,
            mvp: result.mvpId == st.playerId ? 1 : 0,
            min: st.minutos);
      }
    }
  }

  Future<void> _updateTable(int equid, int gf, int gc, int tempid) async {
    final rows = await db.query('tor_temporadas_equipos',
        where: 'te_equid = ? AND te_tempid = ?', whereArgs: [equid, tempid]);
    if (rows.isEmpty) return;
    final r = rows.first;
    final won = gf > gc;
    final drew = gf == gc;
    var pts = (r['te_pts'] ?? 0) as int;
    pts += won ? 3 : (drew ? 1 : 0);
    final forma = ((r['te_forma'] ?? '') as String);
    final newForma = (forma + (won ? 'G' : drew ? 'E' : 'P'));
    await db.update(
        'tor_temporadas_equipos',
        {
          'te_pj': ((r['te_pj'] ?? 0) as int) + 1,
          'te_pg': ((r['te_pg'] ?? 0) as int) + (won ? 1 : 0),
          'te_pe': ((r['te_pe'] ?? 0) as int) + (drew ? 1 : 0),
          'te_pp': ((r['te_pp'] ?? 0) as int) + (!won && !drew ? 1 : 0),
          'te_gf': ((r['te_gf'] ?? 0) as int) + gf,
          'te_gc': ((r['te_gc'] ?? 0) as int) + gc,
          'te_pts': pts,
          'te_forma': newForma.length > 5
              ? newForma.substring(newForma.length - 5)
              : newForma,
        },
        where: 'te_id = ?',
        whereArgs: [r['te_id']]);
    await db.update('eq_equipos', {'equi_pts': pts},
        where: 'equid = ?', whereArgs: [equid]);
  }

  Future<void> _bumpStats(int jugid, int tempid, int equid,
      {int goles = 0,
      int asis = 0,
      int amarillas = 0,
      int rojas = 0,
      int mvp = 0,
      int min = 0}) async {
    final rows = await db.query('jus_stats',
        where: 'js_jugid = ? AND js_tempid = ?', whereArgs: [jugid, tempid]);
    if (rows.isEmpty) {
      await db.insert('jus_stats', {
        'js_jugid': jugid,
        'js_equid': equid,
        'js_tempid': tempid,
        'js_pj': 1,
        'js_min': min,
        'js_titular': 1,
        'js_amarillas': amarillas,
        'js_rojas': rojas,
        'js_mvps': mvp,
        'js_goles': goles,
        'js_asistencias': asis,
      });
      return;
    }
    final r = rows.first;
    await db.update(
        'jus_stats',
        {
          'js_pj': ((r['js_pj'] ?? 0) as int) + 1,
          'js_min': ((r['js_min'] ?? 0) as int) + min,
          'js_amarillas': ((r['js_amarillas'] ?? 0) as int) + amarillas,
          'js_rojas': ((r['js_rojas'] ?? 0) as int) + rojas,
          'js_mvps': ((r['js_mvps'] ?? 0) as int) + mvp,
          'js_goles': ((r['js_goles'] ?? 0) as int) + goles,
          'js_asistencias': ((r['js_asistencias'] ?? 0) as int) + asis,
        },
        where: 'js_jugid = ? AND js_tempid = ?',
        whereArgs: [jugid, tempid]);
  }

  Future<void> _applyMatchAftermath(
      MatchResult r, Team home, Team away) async {
    // cedera
    for (final id in [...r.homeInjured, ...r.awayInjured]) {
      final weeks = 1 + Random().nextInt(5);
      await db.update('jug_jugadores', {'jug_lesion': weeks},
          where: 'jugid = ?', whereArgs: [id]);
    }
    // skorsing satu laga untuk kartu merah
    for (final id in [...r.homeSuspended, ...r.awaySuspended]) {
      await db.update('jug_jugadores', {'jug_susp': 1},
          where: 'jugid = ?', whereArgs: [id]);
    }
    // kondisi turun
    for (final id in r.stats.keys) {
      await db.rawUpdate(
          'UPDATE jug_jugadores SET jug_condicion = MAX(35, jug_condicion - ?) WHERE jugid = ?',
          [12 + Random().nextInt(8), id]);
    }
  }

  Future<void> refreshPowers() async {
    final st = await world.state();
    final rows = await db.query('eq_equipos',
        where: 'equi_paid = ?', whereArgs: [leagues.indexWhere((l) => l.name == st['league']) + 1]);
    for (final r in rows) {
      final power = await _powerForTeam(r['equid'] as int, const []);
      await db.rawUpdate('UPDATE eq_equipos SET equi_poder = ? WHERE equid = ?',
          [power, r['equid']]);
    }
  }

  Future<void> _advanceConditions() async {
    await db.rawUpdate(
        'UPDATE jug_jugadores SET jug_condicion = MIN(100, jug_condicion + 22)');
    await db.rawUpdate(
        'UPDATE jug_jugadores SET jug_lesion = MAX(0, jug_lesion - 1) WHERE jug_lesion > 0');
    await db.rawUpdate(
        'UPDATE jug_jugadores SET jug_susp = MAX(0, jug_susp - 1) WHERE jug_susp > 0');
  }

  // ---------------- FINANZAS ----------------

  Future<void> _weeklyFinances() async {
    final team = await userTeam();
    final squad = await world.squad(team.equid);
    final wages = squad.fold<int>(0, (a, p) => a + p.salario);
    final stadium = await world.stadium(team.estaid);
    final maintenance = (stadium.capacity * 2.1).round();
    await db.update(
        'eq_equipos',
        {
          'equi_presupuesto': (team.presupuesto - wages - maintenance).clamp(-999999999, 999999999)
        },
        where: 'equid = ?',
        whereArgs: [team.equid]);
  }

  Future<void> _financesForMatch(Team home, Team away, MatchResult r, int partid) async {
    final st = await world.state();
    final userEquid = st.i('user_equid');
    final stadium = await world.stadium(home.estaid);
    // Penonton dipengaruhi hasil & reputasi
    final fill = (0.55 + (home.poder - 55) / 160).clamp(0.25, 0.99).toDouble();
    final asistencia = (stadium.capacity * fill).round();
    final ticket = (asistencia * stadium.precio * 0.86).round();
    final tv = (500000 * home.poder / 60).round();
    final ingresos = ticket + tv;
    // Update partido
    await db.update(
        'tor_partidos',
        {
          'par_ent_ingresos': ingresos,
          'par_esp_general': (asistencia * 0.6).round(),
          'par_esp_plateas': (asistencia * 0.25).round(),
          'par_esp_tribunas': (asistencia * 0.1).round(),
          'par_esp_palcos': (asistencia * 0.05).round(),
        },
        where: 'partid = ?',
        whereArgs: [partid]);
    if (home.equid == userEquid) {
      await db.update('eq_equipos',
          {'equi_presupuesto': home.presupuesto + ingresos},
          where: 'equid = ?', whereArgs: [home.equid]);
      await world.addMessage(
          'Pemasukan pertandingan',
          'Laga kandang melawan ${away.nombre}: $asistencia penonton hadir. '
              'Pendapatan tiket + TV: Rp ${_fmt(ingresos)}.',
          'finance', 0);
    } else {
      final share = (tv * 0.28).round();
      final user = await userTeam();
      await db.update('eq_equipos',
          {'equi_presupuesto': user.presupuesto + share},
          where: 'equid = ?', whereArgs: [user.equid]);
    }
  }

  static String _fmt(num v) {
    final s = v.round().toString();
    final b = StringBuffer();
    for (var i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
      b.write(s[i]);
    }
    return b.toString();
  }

  // ---------------- TABLA & STATS ----------------

  Future<List<StandingsRow>> standings() async {
    final st = await world.state();
    final tempid = st.i('tempid');
    final teams = await world.tableFor(tempid);
    final rows = await world.seasonRows(tempid);
    final list = <StandingsRow>[];
    for (final t in teams) {
      final r = rows[t.equid];
      if (r == null) continue;
      final s = StandingsRow(t.equid, t.nombre,
          colorA: t.colorA, colorB: t.colorB);
      s.pj = (r['te_pj'] ?? 0) as int;
      s.pg = (r['te_pg'] ?? 0) as int;
      s.pe = (r['te_pe'] ?? 0) as int;
      s.pp = (r['te_pp'] ?? 0) as int;
      s.gf = (r['te_gf'] ?? 0) as int;
      s.gc = (r['te_gc'] ?? 0) as int;
      s.pts = (r['te_pts'] ?? 0) as int;
      final f = (r['te_forma'] ?? '') as String;
      s.forma = f.split('').where((c) => c.isNotEmpty).toList();
      list.add(s);
    }
    list.sort((a, b) {
      if (b.pts != a.pts) return b.pts - a.pts;
      if (b.dg != a.dg) return b.dg - a.dg;
      return b.gf - a.gf;
    });
    return list;
  }

  Future<List<Map<String, dynamic>>> userFixtures() async {
    final st = await world.state();
    final tempid = st.i('tempid');
    final equid = st.i('user_equid');
    return db.query('tor_partidos',
        where: 'par_tempid = ? AND (par_equid_local = ? OR par_equid_visita = ?)',
        whereArgs: [tempid, equid, equid],
        orderBy: 'par_jornada');
  }

  Future<Map<String, dynamic>?> nextUserFixture() async {
    final st = await world.state();
    final tempid = st.i('tempid');
    final equid = st.i('user_equid');
    final rows = await db.query('tor_partidos',
        where:
            'par_tempid = ? AND par_status = 0 AND (par_equid_local = ? OR par_equid_visita = ?)',
        whereArgs: [tempid, equid, equid],
        orderBy: 'par_jornada',
        limit: 1);
    return rows.isEmpty ? null : rows.first;
  }

  Future<bool> seasonFinished() async {
    final st = await world.state();
    final tempid = st.i('tempid');
    final rows = await db.rawQuery(
        'SELECT COUNT(*) c FROM tor_partidos WHERE par_tempid = ? AND par_status = 0',
        [tempid]);
    return ((rows.first['c'] as int?) ?? 0) == 0;
  }

  // ---------------- TRANSFER MARKET ----------------

  Future<List<Map<String, dynamic>>> marketPlayers(
      {String? search,
      int? minPoder,
      int? maxPoder,
      int? posRole,
      String? posicion,
      int limit = 60}) async {
    final st = await world.state();
    final userEquid = st.i('user_equid');
    final where = <String>['j.jug_jstdid = 1', 'ej.eqju_equid != $userEquid'];
    final args = <Object>[];
    if (search != null && search.isNotEmpty) {
      where.add('j.jug_nombre LIKE ?');
      args.add('%$search%');
    }
    if (minPoder != null) {
      where.add('j.jug_poder >= ?');
      args.add(minPoder);
    }
    if (maxPoder != null) {
      where.add('j.jug_poder <= ?');
      args.add(maxPoder);
    }
    if (posicion != null) {
      where.add('j.jug_posid = ?');
      args.add(posicion);
    }
    if (posRole != null) {
      final posids = positions.where((p) => p.tipo == posRole).map((p) => p.id).join(',');
      where.add('j.jug_posid IN ($posids)');
    }
    final rows = await db.rawQuery('''
      SELECT j.*, ej.eqju_equid as club, e.equi_nombre as club_nombre
      FROM jug_jugadores j
      JOIN eq_equipos_jugadores ej ON ej.eqju_jugid = j.jugid
      JOIN eq_equipos e ON e.equid = ej.eqju_equid
      WHERE ${where.join(' AND ')}
      ORDER BY j.jug_poder DESC LIMIT ?
    ''', [...args, limit]);
    return rows;
  }

  Future<String?> makeOffer(int jugid, int oferta) async {
    final st = await world.state();
    final userEquid = st.i('user_equid');
    final user = await userTeam();
    final p = await world.player(jugid);
    if (p == null) return 'Pemain tidak ditemukan.';
    final origen = await world.ofPlayerClub(jugid);
    if (user.presupuesto < oferta) return 'Anggaran tidak cukup.';
    final rng = Random();
    // Nilai wajar: 80%-130% nilai pasar
    final ratio = oferta / max(1, p.valor);
    double acepta;
    if (ratio >= 1.35) {
      acepta = 0.97;
    } else if (ratio >= 1.1) {
      acepta = 0.85;
    } else if (ratio >= 0.95) {
      acepta = 0.6;
    } else if (ratio >= 0.8) {
      acepta = 0.3;
    } else if (ratio >= 0.65) {
      acepta = 0.1;
    } else {
      acepta = 0.02;
    }
    // Pemain bintang lebih rewel
    if (p.star == 1) acepta *= 0.7;
    if (user.poder + 20 < p.poder + (origen?.poder ?? 0)) acepta *= 0.8;

    if (rng.nextDouble() > acepta) {
      if (ratio < 0.7) {
        return 'Tawaranmu dianggap menghina. ${origen?.nombre ?? "Klub"} menolak mentah-mentah.';
      }
      if (rng.nextBool()) {
        return '${origen?.nombre ?? "Klub"} menolak tawaran. Mereka ingin ${_fmt((p.valor * 1.15).round())}.';
      }
      return '${p.nombre} belum tertarik pindah ke klubmu.';
    }

    // Transfer disetujui
    await db.delete('eq_equipos_jugadores',
        where: 'eqju_jugid = ?', whereArgs: [jugid]);
    await db.insert('eq_equipos_jugadores',
        {'eqju_equid': userEquid, 'eqju_jugid': jugid});
    await db.update('eq_equipos',
        {'equi_presupuesto': user.presupuesto - oferta},
        where: 'equid = ?', whereArgs: [userEquid]);
    if (origen != null) {
      await db.update('eq_equipos',
          {'equi_presupuesto': origen.presupuesto + oferta},
          where: 'equid = ?', whereArgs: [origen.equid]);
    }
    await db.insert('tor_transferencias_jugadores', {
      'tra_jugid': jugid,
      'tra_equid_origen': origen?.equid ?? 0,
      'tra_equid_destino': userEquid,
      'tra_tipo_transferencia': 'compra',
      'tra_valor': oferta,
      'tra_fecha': 'T${st.i('season_year')}',
      'tra_semana': st.i('week'),
      'tra_nombre': p.nombre,
    });
    // Kontrak baru
    final salario = max(p.salario, (oferta / 120).round());
    await db.update('jug_jugadores', {'jug_salario': salario, 'jug_mercado': 0},
        where: 'jugid = ?', whereArgs: [jugid]);
    await db.insert('jug_contratos', {
      'jc_jugid': jugid,
      'jc_equid': userEquid,
      'jc_inicio': st.i('season_year'),
      'jc_fin': st.i('season_year') + 4,
      'jc_status': 1,
      'jc_salario': salario,
    });
    await world.addMessage('Transfer selesai',
        '${p.nombre} resmi bergabung dengan ${user.nombre} seharga ${_fmt(oferta)}.',
        'transfer', st.i('week'));
    return null; // sukses
  }

  Future<String?> sellPlayer(int jugid) async {
    final st = await world.state();
    final userEquid = st.i('user_equid');
    final user = await userTeam();
    final p = await world.player(jugid);
    if (p == null) return 'Tidak ditemukan';
    final squad = await world.squad(userEquid);
    if (squad.length <= 14) return 'Skuad minimal 14 pemain.';
    final rng = Random();
    final oferta = (p.valor * (0.68 + rng.nextDouble() * 0.42)).round();
    final comprador = await _randomClub();
    await db.delete('eq_equipos_jugadores',
        where: 'eqju_jugid = ?', whereArgs: [jugid]);
    await db.insert('eq_equipos_jugadores',
        {'eqju_equid': comprador.equid, 'eqju_jugid': jugid});
    await db.update('eq_equipos',
        {'equi_presupuesto': user.presupuesto + oferta},
        where: 'equid = ?', whereArgs: [userEquid]);
    await db.insert('tor_transferencias_jugadores', {
      'tra_jugid': jugid,
      'tra_equid_origen': userEquid,
      'tra_equid_destino': comprador.equid,
      'tra_tipo_transferencia': 'venta',
      'tra_valor': oferta,
      'tra_fecha': 'T${st.i('season_year')}',
      'tra_semana': st.i('week'),
      'tra_nombre': p.nombre,
    });
    await world.addMessage('Pemain terjual',
        '${p.nombre} pindah ke ${comprador.nombre}. Dana masuk ${_fmt(oferta)}.',
        'transfer', st.i('week'));
    return null;
  }

  Future<Team> _randomClub() async {
    final st = await world.state();
    final rows = await db.query('eq_equipos',
        where: 'equid != ?', whereArgs: [st.i('user_equid')]);
    final t = rows[Random().nextInt(rows.length)];
    return world.teamFromRow(t);
  }

  Future<void> renewContract(int jugid, int newSalary, int years) async {
    final st = await world.state();
    final season = st.i('season_year');
    await db.update('jug_jugadores', {'jug_salario': newSalary},
        where: 'jugid = ?', whereArgs: [jugid]);
    await db.update('jug_contratos', {'jc_fin': season + years, 'jc_salario': newSalary},
        where: 'jc_jugid = ?', whereArgs: [jugid]);
  }

  // ---------------- TRAINING / STADIUM ----------------

  Future<void> setTraining(int kind) => world.setInt('training', kind);

  Future<void> trainWeek() async {
    final st = await world.state();
    final squad = await world.squad(st.i('user_equid'));
    final kind = st.i('training');
    final rng = Random();
    for (final p in squad) {
      if (p.lesionado) continue;
      final gain = rng.nextDouble() < 0.22 ? 1 : 0;
      if (gain == 0) continue;
      var poder = p.poder;
      final Map<String, int> upd = {};
      switch (kind) {
        case 1: // fisik
          upd['jug_fisico'] = min(99, p.fisik + 1);
          upd['jug_ritmo'] = min(99, p.ritmo + (rng.nextBool() ? 1 : 0));
          break;
        case 2: // teknis
          upd['jug_regate'] = min(99, p.regate + 1);
          upd['jug_pase'] = min(99, p.pases + (rng.nextBool() ? 1 : 0));
          break;
        case 3: // taktik
          upd['jug_defensa'] = min(99, p.defensa + 1);
          upd['jug_tiro'] = min(99, p.tembakan + (rng.nextBool() ? 1 : 0));
          break;
        default:
          upd['jug_pase'] = min(99, p.pases + 1);
          break;
      }
      if (p.poder < p.potencial) poder += 1;
      upd['jug_poder'] = poder;
      await db.update('jug_jugadores', upd, where: 'jugid = ?', whereArgs: [p.jugid]);
    }
  }

  Future<String> expandStadium(String sector, int seats) async {
    final team = await userTeam();
    final st = await world.stadium(team.estaid);
    const costPerSeat = {'general': 120, 'plateas': 320, 'tribunas': 220, 'palcos': 900};
    final cost = seats * (costPerSeat[sector] ?? 200).toInt();
    if (team.presupuesto < cost) {
      return 'Dana tidak cukup. Butuh ${_fmt(cost)}.';
    }
    final maxMap = {
      'general': st.maxGeneral,
      'plateas': st.maxPlateas,
      'tribunas': st.maxTribunas,
      'palcos': st.maxPalcos
    };
    final curMap = {
      'general': st.general,
      'plateas': st.plateas,
      'tribunas': st.tribunas,
      'palcos': st.palcos
    };
    if (curMap[sector]! + seats > maxMap[sector]!) {
      return 'Melebihi kapasitas maksimum tribun.';
    }
    final col = {
      'general': 'es_tot_general',
      'plateas': 'es_tot_plateas',
      'tribunas': 'es_tot_tribunas',
      'palcos': 'es_tot_palcos'
    }[sector]!;
    await db.rawUpdate(
        'UPDATE eq_estadios SET $col = $col + ? WHERE estaid = ?', [seats, st.estaid]);
    await db.update('eq_equipos',
        {'equi_presupuesto': team.presupuesto - cost},
        where: 'equid = ?', whereArgs: [team.equid]);
    return 'Tribun $sector ditambah $seats kursi. Biaya ${_fmt(cost)}.';
  }

  // ---------------- END OF SEASON ----------------

  Future<Map<String, dynamic>> endSeason() async {
    final st = await world.state();
    final tempid = st.i('tempid');
    final year = st.i('season_year');
    final table = await standings();
    final userEquid = st.i('user_equid');
    final userPos = table.indexWhere((r) => r.equid == userEquid) + 1;
    final leagueName = st['league'];
    final champion = table.first;
    final scorers = await world.topScorers(tempid, limit: 1);
    final topScorer = scorers.isNotEmpty ? scorers.first : null;

    // hadiah
    final liga = leagues.firstWhere((l) => l.name == leagueName,
        orElse: () => leagues.first);
    final prize = userPos == 1
        ? liga.prize
        : userPos <= 4
            ? (liga.prize * 0.45).round()
            : userPos <= 10
                ? (liga.prize * 0.22).round()
                : (liga.prize * 0.1).round();
    final user = await userTeam();
    await db.update('eq_equipos',
        {'equi_presupuesto': user.presupuesto + prize},
        where: 'equid = ?', whereArgs: [userEquid]);

    // premi pemain
    if (topScorer != null) {
      await db.insert('jug_premios', {
        'jugid': topScorer.jugid,
        'equid': await world.teamOfPlayer(topScorer.jugid),
        'tipo': 'pichichi',
        'anio': year,
        'tempid': tempid,
        'goles': (await world.scorerGoals(tempid))[topScorer.jugid] ?? 0,
      });
    }
    if (champion.equid == userEquid) {
      await world.setInt('trophies', st.i('trophies') + 1);
      await db.update('eq_equipos', {'equi_rep': 95},
          where: 'equid = ?', whereArgs: [userEquid]);
    }
    await db.insert('historial_temporadas', {
      'hist_tempid': tempid,
      'hist_anio': year,
      'hist_campeon_equid': champion.equid,
      'hist_campeon_nombre': champion.nombre,
      'hist_user_pos': userPos,
      'hist_user_pts': table[userPos - 1].pts,
      'hist_user_equid': userEquid,
      'hist_goleador': topScorer?.nombre ?? '-',
      'hist_goles': topScorer != null
          ? (await world.scorerGoals(tempid))[topScorer.jugid] ?? 0
          : 0,
      'hist_mvp': champion.nombre,
    });

    // naikkan umur & pensiun
    await _agePlayers(year);

    // perbarui valuasi pemain
    await _revalueSquad(userEquid);

    // ganti tahun
    await world.setInt('season_year', year + 1);

    final conf = (st.i('confidence') + (userPos <= 3 ? 12 : userPos <= 8 ? 4 : -8))
        .clamp(5, 99);
    await world.setInt('confidence', conf);

    // PHK bila gagal total, atau tawaran klub lain bila berprestasi
    final sacked = userPos >= table.length - 2 && conf <= 32;
    final offers = <Map<String, dynamic>>[];
    if (sacked) {
      final seed = leagues.indexWhere((l) => l.name == leagueName) + 1;
      final pool = await db.query('eq_equipos',
          where: 'equi_paid = ? AND equid != ?',
          whereArgs: [seed, userEquid],
          orderBy: 'equi_poder ASC',
          limit: 3);
      for (final r in pool) {
        offers.add({
          'equid': r['equid'],
          'nombre': r['equi_nombre'],
          'poder': r['equi_poder'],
          'salario': ((r['equi_poder'] as int) * 70000),
        });
      }
      await world.setInt('confidence', 60);
    } else if (userPos <= 4) {
      final seed = leagues.indexWhere((l) => l.name == leagueName) + 1;
      final pool = await db.query('eq_equipos',
          where: 'equi_paid = ? AND equid != ? AND equi_poder > ?',
          whereArgs: [seed, userEquid, user.poder],
          orderBy: 'equi_poder DESC',
          limit: 3);
      for (final r in pool) {
        offers.add({
          'equid': r['equid'],
          'nombre': r['equi_nombre'],
          'poder': r['equi_poder'],
          'salario': ((r['equi_poder'] as int) * 90000),
        });
      }
    }

    await world.addMessage(
        userPos == 1 ? 'JUARA!' : 'Akhir musim ${year}/${year + 1}',
        userPos == 1
            ? '${user.nombre} juara ${liga.name}! Hadiah ${_fmt(prize)} masuk kas klub.'
            : 'Kamu finis di posisi $userPos. Hadiah liga: ${_fmt(prize)}. '
                'Papan atas: ${table.take(3).map((e) => e.nombre).join(', ')}.',
        'season',
        0);

    return {
      'year': year,
      'userPos': userPos,
      'champion': champion.nombre,
      'championEquid': champion.equid,
      'scorer': topScorer?.nombre ?? '-',
      'scorerGoals': topScorer != null
          ? (await world.scorerGoals(tempid))[topScorer.jugid] ?? 0
          : 0,
      'prize': prize,
      'championUser': champion.equid == userEquid,
      'table': table,
      'sacked': sacked,
      'offers': offers,
    };
  }

  Future<void> _agePlayers(int year) async {
    final rng = Random();
    final rows = await db.query('jug_jugadores', where: 'jug_jstdid = 1');
    final clubs = await db.query('eq_equipos');
    final gen = WorldGenerator(db, rng);

    await db.transaction((txn) async {
      gen.executor = txn;
      for (final r in rows) {
        final p = world.playerFromRow(r);
        final edad = p.edad + 1;
        if (edad >= 39 && rng.nextDouble() < 0.55) {
          await txn.update('jug_jugadores', {'jug_jstdid': 2, 'jug_titular': 0},
              where: 'jugid = ?', whereArgs: [p.jugid]);
          await txn.delete('eq_equipos_jugadores',
              where: 'eqju_jugid = ?', whereArgs: [p.jugid]);
          continue;
        }
        var poder = p.poder;
        if (edad <= 24) {
          poder += rng.nextInt(3);
        } else if (edad >= 31) {
          poder -= 1 + rng.nextInt(3);
        } else {
          poder += rng.nextInt(2) - 1;
        }
        poder = poder.clamp(25, 99);
        final valor = _valueFor(poder, edad, p.potencial);
        await txn.update(
            'jug_jugadores',
            {
              'jug_edad': edad,
              'jug_poder': poder,
              'jug_valor': valor,
              'jug_condicion': 100,
              'jug_salario': (valor / 180).round(),
            },
            where: 'jugid = ?',
            whereArgs: [p.jugid]);
      }

      // Isi ulang skuad yang kosong dengan pemain muda
      for (final c in clubs) {
        final equid = c['equid'] as int;
        final count = await txn.rawQuery(
            'SELECT COUNT(*) c FROM eq_equipos_jugadores WHERE eqju_equid = ?',
            [equid]);
        if (((count.first['c'] as int?) ?? 0) >= 18) continue;
        await gen.fillSquad(equid, (c['equi_poder'] as int?) ?? 60);
      }
    });
  }

  int _valueFor(int poder, int edad, int potencial) {
    final edadF = edad <= 21
        ? 1.45
        : edad <= 25
            ? 1.3
            : edad <= 29
                ? 1.0
                : edad <= 32
                    ? 0.65
                    : 0.35;
    final podF = pow(poder / 50, 4.2).toDouble();
    final potF = 1 + (potencial - poder) / 55;
    return max(50000, (90000 * podF * edadF * potF).round());
  }

  Future<void> _revalueSquad(int equid) async {}

  Future<void> acceptJob(int equid) async {
    await world.setInt('user_equid', equid);
    await db.update('eq_equipos', {'equi_is_user': 0}, where: '1 = 1');
    await db.update('eq_equipos', {'equi_is_user': 1},
        where: 'equid = ?', whereArgs: [equid]);
    final t = await world.team(equid);
    await world.addMessage('Klub baru',
        'Kamu resmi menangani ${t?.nombre}. Tantangan baru dimulai.', 'info', 0);
  }

  Future<void> nextSeason() async {
    final st = await world.state();
    await startSeason(st.i('season_year'), first: false);
  }

  // ---------------- MISC ----------------

  Future<int> unread() => world.unreadMessages();

  Future<void> markMessagesRead() async {
    await db.update('mensajes', {'msg_leido': 1});
  }

  Future<Map<String, dynamic>?> leagueTopScorerInfo() async {
    final st = await world.state();
    final tops = await world.topScorers(st.i('tempid'), limit: 1);
    if (tops.isEmpty) return null;
    return {'player': tops.first, 'goals': (await world.scorerGoals(st.i('tempid')))[tops.first.jugid]};
  }
}

extension on World {
  Future<Team?> ofPlayerClub(int jugid) async {
    final id = await teamOfPlayer(jugid);
    if (id == 0) return null;
    return team(id);
  }
}
