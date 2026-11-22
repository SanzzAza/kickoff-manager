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
    final toridCup = await _cupTorneoId(liga.country);
    final teamRows = await db.query('eq_equipos',
        where: 'equi_paid = ?', whereArgs: [seedPais], orderBy: 'equid');
    final teamIds = teamRows.map((r) => r['equid'] as int).toList();
    final powers = <int, int>{};
    for (final id in teamIds) {
      powers[id] = await _powerForTeam(id, teamIds);
    }
    final fixtures = _roundRobin(teamIds);
    final leagueRounds = fixtures.length * 2;
    final totalWeeks = leagueRounds + 4;
    final c1 = 6;
    final c2 = (totalWeeks * 0.38).round();
    final c3 = (totalWeeks * 0.66).round();
    final c4 = totalWeeks - 2;
    final cupWeeks = [c1, c2, c3, c4];
    final cupWeekSet = cupWeeks.toSet();
    final leagueWeekSlots = <int>[];
    for (var w = 1; w <= totalWeeks; w++) {
      if (!cupWeekSet.contains(w)) leagueWeekSlots.add(w);
    }

    // 16 peserta Piala Domestik (selalu sertakan klub user)
    final userEquid = prev.i('user_equid');
    final cupPool = List.of(teamIds)..remove(userEquid);
    cupPool.shuffle(Random());
    final cupTeams = [userEquid, ...cupPool.take(15)]..shuffle(Random());

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

      var rIdx = 0;
      for (final round in fixtures) {
        final w1 = leagueWeekSlots[rIdx];
        final w2 = leagueWeekSlots[rIdx + fixtures.length];
        rIdx++;
        for (final m in round) {
          await _insertFixture(toridLiga, tempid, m[0], m[1], w1, txn: txn);
        }
        for (final m in round) {
          await _insertFixture(toridLiga, tempid, m[1], m[0], w2, txn: txn);
        }
      }

      // Jadwalkan babak 16 Besar Piala Domestik (par_vuelta = 1, par_fase = 1)
      if (toridCup != null && cupTeams.length >= 2) {
        final pairs = (cupTeams.length ~/ 2) * 2;
        for (var i = 0; i < pairs; i += 2) {
          await _insertFixture(
            toridCup,
            tempid,
            cupTeams[i],
            cupTeams[i + 1],
            c1,
            fase: 1,
            vuelta: 1,
            txn: txn,
          );
        }
      }
    });
    await world.setState('cup_weeks', jsonEncode(cupWeeks));
    await world.setState('sponsor_name', '');
    await world.setInt('sponsor_bonus', 0);
    await world.setInt('sponsor_target', 0);
    await world.setState('pending_offer', '');
    await world.setInt('total_weeks', totalWeeks);
  }

  Future<int> _leagueTorneoId(String name) async {
    final r = await db.query('tor_torneos',
        where: 'tor_nombre = ? AND tor_organizacion = 1',
        whereArgs: [name],
        limit: 1);
    return r.first['torid'] as int;
  }

  Future<int?> _cupTorneoId(String country) async {
    final r = await db.query('tor_torneos',
        where: 'tor_nombre = ? AND tor_organizacion = 3',
        whereArgs: ['Copa $country'],
        limit: 1);
    if (r.isEmpty) return null;
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
      {int? fase, int vuelta = 0, DatabaseExecutor? txn}) async {
    await (txn ?? db).insert('tor_partidos', {
      'par_torid': torid,
      'par_tempid': tempid,
      'par_estaid': 0,
      'par_equid_local': home,
      'par_equid_visita': away,
      'par_goles_local': 0,
      'par_goles_visita': 0,
      'par_gana': 0,
      'par_fase': fase ?? jornada,
      'par_jornada': jornada,
      'par_status': 0,
      'par_fecha': vuelta == 1 ? 'Piala B${fase ?? 1}' : 'J$jornada',
      'par_vuelta': vuelta,
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
    var xi = squad.where((p) => p.disponible && p.posid == 1).toList()
      ..sort((a, b) {
        final t = (b.titular == 1 ? 1 : 0) - (a.titular == 1 ? 1 : 0);
        return t != 0 ? t : b.poder - a.poder;
      });
    xi = xi.take(1).toList();
    // Utamakan pemain bertanda titular
    final listed = squad.where((p) => p.titular == 1 && p.disponible).toList()
      ..sort((a, b) => b.poder - a.poder);
    final others = squad.where((p) => p.titular != 1 && p.disponible).toList()
      ..sort((a, b) => b.poder - a.poder);
    final pool = [...listed, ...others];

    // Jika user sudah menentukan 11 pemain inti secara manual, hormati pilihan tersebut.
    if (listed.length == 11) {
      final gkIdx = listed.indexWhere((p) => p.posid == 1);
      final ordered = List<Player>.from(listed);
      if (gkIdx > 0) {
        final gk = ordered.removeAt(gkIdx);
        ordered.insert(0, gk);
      }
      final used = ordered.map((p) => p.jugid).toSet();
      final bench = pool.where((p) => !used.contains(p.jugid)).take(7).toList();
      return TeamSetup(
        xi: ordered,
        bench: bench,
        tactics: tac,
        clubPower: team.poder,
        name: team.nombre,
      );
    }
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
      await _simAiFixture(f);
    }

    final pending = await db.query('tor_partidos',
        where: 'par_tempid = ? AND par_status = 0 AND par_jornada = ?',
        whereArgs: [tempid, week]);
    final list = pending;

    Map<String, dynamic>? userMatchInfo;
    final highlights = <String>[];

    for (final f in list) {
      final home = f['par_equid_local'] as int;
      final away = f['par_equid_visita'] as int;
      final isUser = home == userEquid || away == userEquid;

      if (isUser && !userSimulatedFast) {
        userMatchInfo = Map<String, dynamic>.from(f);
        continue; // laga user dimainkan lewat MatchSimScreen
      }

      final (hNombre, hg, ag, aNombre) = await _simAiFixture(f);
      if (isUser) {
        highlights.add('$hNombre $hg-$ag $aNombre (disimulasikan)');
      }
    }

    await _advanceCupBracketIfReady(tempid);
    await world.setInt('week', week);
    await _advanceConditions();
    await refreshPowers();
    await _weeklyFinances();
    await _maybeAiTransfer(week);
    await _maybeIncomingOffer(week);
    return WeekSummary(week, userMatchInfo, highlights);
  }

  Future<(String, int, int, String)> _simAiFixture(
      Map<String, dynamic> f) async {
    final h = (await world.team(f['par_equid_local'] as int))!;
    final a = (await world.team(f['par_equid_visita'] as int))!;
    final isCup = (f['par_vuelta'] as int? ?? 0) == 1;
    final (hg, ag) = engine.quickScore(
        await buildSetup(h, Tactics()), await buildSetup(a, Tactics()));
    int? penH, penA;
    if (isCup && hg == ag) {
      if (Random().nextBool()) {
        penH = 5;
        penA = 4;
      } else {
        penH = 4;
        penA = 5;
      }
    }
    await _saveResult(f, hg, ag, null, penHome: penH, penAway: penA);
    return (h.nombre, hg, ag, a.nombre);
  }

  /// Siapkan sesi pertandingan live interaktif untuk user.
  Future<LiveMatchSession> startLiveUserMatch(int partid,
      {bool needWinner = false}) async {
    final st = await world.state();
    final tac = st.tactics();
    final rows =
        await db.query('tor_partidos', where: 'partid = ?', whereArgs: [partid]);
    final f = rows.first;
    final homeId = f['par_equid_local'] as int;
    final awayId = f['par_equid_visita'] as int;
    final userEquid = st.i('user_equid');
    final isCup = (f['par_vuelta'] as int? ?? 0) == 1;
    final homeTeam = (await world.team(homeId))!;
    final awayTeam = (await world.team(awayId))!;
    final hSetup =
        await buildSetup(homeTeam, homeId == userEquid ? tac : Tactics());
    final aSetup =
        await buildSetup(awayTeam, awayId == userEquid ? tac : Tactics());
    final userSide = homeId == userEquid ? 0 : (awayId == userEquid ? 1 : -1);
    return engine.createSession(
      hSetup,
      aSetup,
      userSide: userSide,
      needWinner: needWinner || isCup,
      homeAdvantage: true,
    );
  }

  /// Simpan hasil dari sesi live interaktif ke database & kas.
  Future<void> commitUserMatchResult(int partid, MatchResult result) async {
    final rows =
        await db.query('tor_partidos', where: 'partid = ?', whereArgs: [partid]);
    final f = rows.first;
    final homeTeam = (await world.team(f['par_equid_local'] as int))!;
    final awayTeam = (await world.team(f['par_equid_visita'] as int))!;
    await _saveResult(f, result.homeGoals, result.awayGoals, result,
        penHome: result.penHome, penAway: result.penAway);
    await _applyMatchAftermath(result, homeTeam, awayTeam);
    await _financesForMatch(homeTeam, awayTeam, result, partid);
    await _advanceCupBracketIfReady(f['par_tempid'] as int);
  }

  /// Mainkan laga user sekaligus (dipakai oleh test/simulasi instan).
  Future<MatchResult> playUserMatch(int partid, {bool needWinner = false}) async {
    final session = await startLiveUserMatch(partid, needWinner: needWinner);
    while (!session.isFinished) {
      session.stepMinute();
    }
    final result = session.finalize();
    await commitUserMatchResult(partid, result);
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
      final (hn, hg, ag, an) = await _simAiFixture(f);
      out.add('$hn $hg-$ag $an');
    }
    await _advanceCupBracketIfReady(tempid);
    if (targetWeek > currentW) {
      await world.setInt('week', targetWeek);
      await _advanceConditions();
      await refreshPowers();
      await _weeklyFinances();
      await _maybeAiTransfer(targetWeek);
      await _maybeIncomingOffer(targetWeek);
    }
    return out;
  }

  Future<void> _advanceCupBracketIfReady(int tempid) async {
    final st = await world.state();
    final rawCupWeeks = st['cup_weeks'];
    if (rawCupWeeks == null || rawCupWeeks.isEmpty) return;
    final cupWeeks = (jsonDecode(rawCupWeeks) as List).cast<int>();
    if (cupWeeks.length < 4) return;

    final allCup = await db.query('tor_partidos',
        where: 'par_tempid = ? AND par_vuelta = 1',
        whereArgs: [tempid],
        orderBy: 'par_fase, partid');
    if (allCup.isEmpty) return;

    final currentFase = allCup
        .map((r) => (r['par_fase'] as int?) ?? 1)
        .reduce((a, b) => a > b ? a : b);
    final faseMatches =
        allCup.where((r) => (r['par_fase'] as int? ?? 1) == currentFase).toList();
    if (faseMatches.any((r) => (r['par_status'] as int? ?? 0) == 0)) {
      return; // babak piala ini belum selesai semua
    }

    if (currentFase >= 4) {
      // Final selesai -> umumkan juara piala!
      final finalMatch = faseMatches.first;
      final winnerId = finalMatch['par_gana'] as int? ?? 0;
      if (winnerId > 0) {
        final alreadyAwarded = await db.query('mensajes',
            where: 'msg_tipo = ? AND msg_semana = ?',
            whereArgs: ['cup_win_$tempid', tempid]);
        if (alreadyAwarded.isEmpty) {
          final winner = await world.team(winnerId);
          final userEquid = st.i('user_equid');
          final torid = finalMatch['par_torid'] as int;
          final torRow = await db.query('tor_torneos',
              where: 'torid = ?', whereArgs: [torid], limit: 1);
          final cupName =
              torRow.isNotEmpty ? (torRow.first['tor_nombre'] as String) : 'Piala Domestik';
          final prize =
              torRow.isNotEmpty ? (torRow.first['tor_premio_equipos'] as int? ?? 2000000) : 2000000;
          if (winnerId == userEquid && winner != null) {
            await world.setInt('trophies', st.i('trophies') + 1);
            await db.update('eq_equipos',
                {'equi_presupuesto': winner.presupuesto + prize},
                where: 'equid = ?', whereArgs: [userEquid]);
          }
          await world.addMessage(
            winnerId == userEquid ? 'JUARA $cupName!' : 'Juara $cupName',
            winnerId == userEquid
                ? 'Luar biasa! ${winner?.nombre} menjuarai $cupName dan meraih hadiah ${_fmt(prize)}!'
                : '${winner?.nombre ?? "Klub"} menjuarai $cupName musim ini.',
            'cup_win_$tempid',
            tempid,
          );
        }
      }
      return;
    }

    final nextFase = currentFase + 1;
    final winners = faseMatches
        .map((r) => r['par_gana'] as int? ?? 0)
        .where((id) => id > 0)
        .toList();
    if (winners.length < 2) return;

    final torid = faseMatches.first['par_torid'] as int;
    final nextWeek = cupWeeks[nextFase - 1];
    final pairs = (winners.length ~/ 2) * 2;
    await db.transaction((txn) async {
      for (var i = 0; i < pairs; i += 2) {
        await _insertFixture(
          torid,
          tempid,
          winners[i],
          winners[i + 1],
          nextWeek,
          fase: nextFase,
          vuelta: 1,
          txn: txn,
        );
      }
    });
  }

  Future<void> _saveResult(Map<String, dynamic> f, int hg, int ag,
      MatchResult? result,
      {int? penHome,
      int? penAway}) async {
    final partid = f['partid'] as int;
    final tempid = f['par_tempid'] as int;
    final lid = f['par_equid_local'] as int;
    final vid = f['par_equid_visita'] as int;
    final isCup = (f['par_vuelta'] as int? ?? 0) == 1;
    int winnerId = hg > ag ? lid : (ag > hg ? vid : 0);
    if (winnerId == 0 && penHome != null && penAway != null && penHome != penAway) {
      winnerId = penHome > penAway ? lid : vid;
    }
    await db.update(
        'tor_partidos',
        {
          'par_goles_local': hg,
          'par_goles_visita': ag,
          'par_gana': winnerId,
          'par_status': 1,
          'par_penal_goles_local': penHome,
          'par_penal_goles_visita': penAway,
        },
        where: 'partid = ?',
        whereArgs: [partid]);

    if (!isCup) {
      await _updateTable(lid, hg, ag, tempid);
      await _updateTable(vid, ag, hg, tempid);
    }

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
    // Penonton dipengaruhi harga tiket, kualitas tim, & gengsi big match
    final priceFactor = (38 - stadium.precio) / 180.0;
    final bigMatch = away.poder >= 76 || (home.poder - away.poder).abs() <= 4;
    final hypeBoost = bigMatch ? 0.10 : 0.0;
    final fill = (0.55 + (home.poder - 55) / 160 + priceFactor + hypeBoost)
        .clamp(0.25, 0.99)
        .toDouble();
    final asistencia = (stadium.capacity * fill).round();
    final ticket = (asistencia * stadium.precio * 0.86).round();
    final tv = (500000 * home.poder / 60).round();
    final ingresos = ticket + tv;
    if (bigMatch && (home.equid == userEquid || away.equid == userEquid)) {
      await world.addMessage(
        'Big Match: ${home.nombre} ${r.homeGoals}-${r.awayGoals} ${away.nombre}',
        'Sebanyak $asistencia penonton memadati ${stadium.nombre} pada laga penuh gengsi ini.',
        'info',
        st.i('week'),
      );
    }
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
    final sponsorBonus = (st.i('sponsor_target') > 0 && userPos <= st.i('sponsor_target'))
        ? st.i('sponsor_bonus')
        : 0;
    final user = await userTeam();
    await db.update('eq_equipos',
        {'equi_presupuesto': user.presupuesto + prize + sponsorBonus},
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

  // ---------------- LIVING WORLD & MANUAL CONTROLS ----------------

  Future<void> swapStarter(int starterId, int reserveId) async {
    final st = await world.state();
    final tac = st.tactics();
    final team = await userTeam();
    final currentXi = (await buildSetup(team, tac)).xi.map((p) => p.jugid).toSet();
    currentXi.remove(starterId);
    currentXi.add(reserveId);
    await db.update('jug_jugadores', {'jug_titular': 0},
        where:
            'jugid IN (SELECT eqju_jugid FROM eq_equipos_jugadores WHERE eqju_equid = ?)',
        whereArgs: [team.equid]);
    for (final id in currentXi) {
      await db.update('jug_jugadores', {'jug_titular': 1},
          where: 'jugid = ?', whereArgs: [id]);
    }
  }

  Future<void> setCaptain(int jugid) async {
    final st = await world.state();
    final userEquid = st.i('user_equid');
    await db.update('jug_jugadores', {'jug_capitan': 0},
        where:
            'jugid IN (SELECT eqju_jugid FROM eq_equipos_jugadores WHERE eqju_equid = ?)',
        whereArgs: [userEquid]);
    await db.update('jug_jugadores', {'jug_capitan': 1},
        where: 'jugid = ?', whereArgs: [jugid]);
  }

  Future<void> setTicketPrice(int price) async {
    final t = await userTeam();
    await db.update('eq_estadios', {'es_precio': price.clamp(10, 90)},
        where: 'estaid = ?', whereArgs: [t.estaid]);
  }

  Future<List<Map<String, dynamic>>> availableSponsors() async {
    final team = await userTeam();
    final base = (team.poder * 350000).round();
    return [
      {
        'name': sponsorsLow[team.equid % sponsorsLow.length],
        'upfront': (base * 0.6).round(),
        'bonus': (base * 0.5).round(),
        'target': 12,
        'desc': 'Target aman: finis 12 besar',
      },
      {
        'name': 'Nusantara Air',
        'upfront': (base * 0.8).round(),
        'bonus': base,
        'target': 6,
        'desc': 'Target papan atas: finis 6 besar',
      },
      {
        'name': 'Garuda Global',
        'upfront': base,
        'bonus': (base * 1.8).round(),
        'target': 2,
        'desc': 'Target juara: finis 2 besar',
      },
    ];
  }

  Future<String> selectSponsor(Map<String, dynamic> sp) async {
    final st = await world.state();
    if ((st['sponsor_name'] ?? '').isNotEmpty) {
      return 'Sponsor musim ini sudah dikontrak (${st['sponsor_name']}).';
    }
    final user = await userTeam();
    final upfront = sp['upfront'] as int;
    await db.update('eq_equipos',
        {'equi_presupuesto': user.presupuesto + upfront},
        where: 'equid = ?', whereArgs: [user.equid]);
    await world.setState('sponsor_name', sp['name'] as String);
    await world.setInt('sponsor_bonus', sp['bonus'] as int);
    await world.setInt('sponsor_target', sp['target'] as int);
    await world.addMessage(
      'Kontrak Sponsor: ${sp['name']}',
      'Dana awal ${_fmt(upfront)} masuk kas klub! Bonus ${_fmt(sp['bonus'] as int)} cair bila finis ${sp['target']} besar.',
      'finance',
      st.i('week'),
    );
    return 'Kontrak sponsor ${sp['name']} ditandatangani! Dana masuk ${_fmt(upfront)}.';
  }

  Future<Map<String, dynamic>?> pendingOffer() async {
    final st = await world.state();
    final raw = st['pending_offer'];
    if (raw == null || raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  Future<String> respondIncomingOffer(bool accept) async {
    final offer = await pendingOffer();
    await world.setState('pending_offer', '');
    if (offer == null) return 'Tawaran sudah kedaluwarsa.';
    if (!accept) {
      return 'Tawaran ${offer['buyer_name']} untuk ${offer['player_name']} ditolak.';
    }
    final st = await world.state();
    final userEquid = st.i('user_equid');
    final jugid = offer['jugid'] as int;
    final buyerId = offer['buyer_equid'] as int;
    final amount = offer['amount'] as int;
    final squad = await world.squad(userEquid);
    if (squad.length <= 14) return 'Skuad minimal 14 pemain, tidak bisa dijual.';
    final user = await userTeam();

    await db.delete('eq_equipos_jugadores',
        where: 'eqju_jugid = ?', whereArgs: [jugid]);
    await db.insert('eq_equipos_jugadores',
        {'eqju_equid': buyerId, 'eqju_jugid': jugid});
    await db.update('eq_equipos',
        {'equi_presupuesto': user.presupuesto + amount},
        where: 'equid = ?', whereArgs: [userEquid]);
    await db.insert('tor_transferencias_jugadores', {
      'tra_jugid': jugid,
      'tra_equid_origen': userEquid,
      'tra_equid_destino': buyerId,
      'tra_tipo_transferencia': 'venta',
      'tra_valor': amount,
      'tra_fecha': 'T${st.i('season_year')}',
      'tra_semana': st.i('week'),
      'tra_nombre': offer['player_name'],
    });
    await world.addMessage(
      'Penjualan selesai',
      '${offer['player_name']} resmi dilepas ke ${offer['buyer_name']} seharga ${_fmt(amount)}.',
      'transfer',
      st.i('week'),
    );
    return '${offer['player_name']} terjual ke ${offer['buyer_name']} (${_fmt(amount)})!';
  }

  Future<void> _maybeIncomingOffer(int week) async {
    if (week % 4 != 3) return;
    final st = await world.state();
    if ((st['pending_offer'] ?? '').isNotEmpty) return;
    final userEquid = st.i('user_equid');
    final squad = await world.squad(userEquid);
    if (squad.length <= 16 || Random().nextDouble() > 0.55) return;
    final candidates = squad.where((p) => p.posid != 1).toList()
      ..sort((a, b) => b.poder - a.poder);
    if (candidates.isEmpty) return;
    final target = candidates[Random().nextInt(min(6, candidates.length))];
    final buyer = await _randomClub();
    final amount = (target.valor * (1.05 + Random().nextDouble() * 0.35)).round();
    final payload = {
      'jugid': target.jugid,
      'player_name': target.nombre,
      'player_poder': target.poder,
      'buyer_equid': buyer.equid,
      'buyer_name': buyer.nombre,
      'amount': amount,
    };
    await world.setState('pending_offer', jsonEncode(payload));
    await world.addMessage(
      'Tawaran masuk: ${target.nombre}',
      '${buyer.nombre} menawar ${target.nombre} (OVR ${target.poder}) seharga ${_fmt(amount)}. '
          'Buka halaman Klub untuk menerima atau menolak.',
      'transfer',
      week,
    );
  }

  Future<void> _maybeAiTransfer(int week) async {
    if (week % 3 != 0) return;
    final st = await world.state();
    final userEquid = st.i('user_equid');
    final rows = await db.rawQuery('''
      SELECT j.jugid, j.jug_nombre, j.jug_valor, ej.eqju_equid as orig
      FROM jug_jugadores j
      JOIN eq_equipos_jugadores ej ON ej.eqju_jugid = j.jugid
      WHERE j.jug_jstdid = 1 AND ej.eqju_equid != ? AND j.jug_mercado = 1
      ORDER BY RANDOM() LIMIT 1
    ''', [userEquid]);
    if (rows.isEmpty) return;
    final r = rows.first;
    final origId = r['orig'] as int;
    final count = await db.rawQuery(
        'SELECT COUNT(*) c FROM eq_equipos_jugadores WHERE eqju_equid = ?',
        [origId]);
    if (((count.first['c'] as int?) ?? 0) <= 16) return;
    final buyer = await _randomClub();
    if (buyer.equid == origId) return;
    final jugid = r['jugid'] as int;
    final val = (r['jug_valor'] as int?) ?? 500000;
    await db.delete('eq_equipos_jugadores',
        where: 'eqju_jugid = ?', whereArgs: [jugid]);
    await db.insert('eq_equipos_jugadores',
        {'eqju_equid': buyer.equid, 'eqju_jugid': jugid});
    await db.insert('tor_transferencias_jugadores', {
      'tra_jugid': jugid,
      'tra_equid_origen': origId,
      'tra_equid_destino': buyer.equid,
      'tra_tipo_transferencia': 'compra',
      'tra_valor': val,
      'tra_fecha': 'T${st.i('season_year')}',
      'tra_semana': week,
      'tra_nombre': r['jug_nombre'],
    });
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
