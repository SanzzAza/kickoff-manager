// Engine pertandingan: simulasi menit-per-menit (mendukung mode live interaktif).
// Terinspirasi struktur AlgPartido.dart pada game aslinya:
// tiap menit dihitung peluang, stamina, momentum, substitusi, perubahan taktik,
// lalu diselesaikan jadi tembakan/gol/penyelamatan/kartu/cedera/rating pemain.

import 'dart:math';
import '../models/models.dart';

class TeamSetup {
  final List<Player> xi; // 11 pemain aktif di lapangan
  final List<Player> bench;
  Tactics tactics;
  final int clubPower;
  final String name;
  final int tacticBonus;
  final double staminaDrainFactor;
  TeamSetup({
    required this.xi,
    required this.bench,
    required this.tactics,
    required this.clubPower,
    required this.name,
    this.tacticBonus = 0,
    this.staminaDrainFactor = 1.0,
  });

  int _avg(Iterable<int> v) =>
      v.isEmpty ? 40 : (v.reduce((a, b) => a + b) / v.length).round();

  List<Player> get _def => xi.where((p) => p.posid >= 2 && p.posid <= 4).toList();
  List<Player> get _mid => xi.where((p) => p.posid >= 5 && p.posid <= 8).toList();
  List<Player> get _att => xi.where((p) => p.posid >= 9).toList();
  Player? get _gk => xi.isEmpty
      ? null
      : xi.firstWhere((p) => p.posid == 1, orElse: () => xi.first);

  bool _hasSkill(Player p, int id) => p.habA == id || p.habB == id;

  int get attackRating {
    final base = _avg(_att.map((p) => p.ataque));
    final mid = _avg(_mid.map((p) => p.creacion));
    var v = (base * 0.72 + mid * 0.28).round() + tacticBonus;
    if (tactics.mentalidad == Mentality.ofensivo) v += 5;
    if (tactics.mentalidad == Mentality.defensivo) v -= 4;
    if (tactics.estilo == Style.directo) v += 2;
    if (_att.any((p) => _hasSkill(p, 9) || _hasSkill(p, 13) || _hasSkill(p, 24))) {
      v += 1;
    }
    return v.clamp(1, 120);
  }

  int get midfieldRating {
    final v = _avg(_mid.map((p) => (p.creacion * 2 + p.defensivo) ~/ 3));
    var r = v + (tacticBonus > 0 ? 1 : 0);
    if (tactics.estilo == Style.posesion) r += 4;
    if (tactics.presion == Pressure.alta) r += 2;
    if (_mid.any((p) => _hasSkill(p, 15) || _hasSkill(p, 16))) r += 1;
    return r.clamp(1, 120);
  }

  int get defenseRating {
    final d = _avg(_def.map((p) => p.defensivo));
    final gk = _gk?.kiper ?? 40;
    var v = (d * 0.78 + gk * 0.22).round() + (tacticBonus > 0 ? 1 : 0);
    if (tactics.mentalidad == Mentality.defensivo) v += 5;
    if (tactics.mentalidad == Mentality.ofensivo) v -= 4;
    if (tactics.linea <= 2) v += 3;
    if (tactics.linea >= 4) v -= 2;
    if (_def.any((p) => _hasSkill(p, 6) || _hasSkill(p, 7) || _hasSkill(p, 11))) {
      v += 1;
    }
    return v.clamp(1, 120);
  }

  int get overall =>
      ((attackRating * 1.05 + midfieldRating * 1.1 + defenseRating * 0.95) / 3)
          .round();

  List<Player> get outfield => xi.where((p) => p.posid != 1).toList();
}

const List<String> _goalPhrases = [
  'melesakkan bola ke sudut kanan gawang',
  'menyelesaikan serangan balik dengan dingin',
  'menembak keras dari tepi kotak penalti',
  'menyundul bola hasil umpan silang',
  'melewati bek lalu menaklukkan kiper',
  'memanfaatkan kesalahan lini belakang',
  'melesat dari sisi kiri lalu menembak silang',
  'mengecoh kiper dengan tembakan rendah',
  'melepaskan tendangan voli spektakuler yang tak terbendung',
  'menyambar bola muntah di depan gawang',
];

const List<String> _assistPhrases = [
  'berhasil mengirim umpan terukur',
  'memberi umpan matang dari sisi lapangan',
  'melakukan kombinasi satu-dua apik dengan',
  'mengirim bola silang mematikan kepada',
  'mencuri bola lalu melepas assist kepada',
];

class LiveMatchSession {
  final TeamSetup home;
  final TeamSetup away;
  final int userSide; // 0 = home, 1 = away, -1 = netral
  final bool needWinner;
  final bool homeAdvantage;
  final Random rng;

  int minute = 0;
  late int totalMinutes;
  bool inExtraTime = false;
  int homeGoals = 0;
  int awayGoals = 0;
  int homeShots = 0;
  int awayShots = 0;
  int homeOnTarget = 0;
  int awayOnTarget = 0;
  double homeTilt = 0; // -0.35 .. +0.35
  int userSubsUsed = 0;
  int aiSubsUsed = 0;
  static const int maxSubs = 5;

  final List<MatchEvent> events = [];
  final Map<int, PlayerMatchStat> stats = {};
  final Map<int, double> stamina = {};
  final Set<int> subbedInIds = {};
  final List<int> injuriesHome = [];
  final List<int> injuriesAway = [];
  final List<int> suspendedHome = [];
  final List<int> suspendedAway = [];

  int _posSampleSum = 0;
  int _posSampleCount = 0;
  MatchResult? _finalized;

  LiveMatchSession({
    required this.home,
    required this.away,
    this.userSide = 0,
    this.needWinner = false,
    this.homeAdvantage = true,
    Random? rng,
  }) : rng = rng ?? Random() {
    totalMinutes = 90 + this.rng.nextInt(5) + 1;
    for (final p in home.xi) {
      stats[p.jugid] = PlayerMatchStat(p.jugid, 0);
      stamina[p.jugid] = p.condicion.toDouble();
    }
    for (final p in away.xi) {
      stats[p.jugid] = PlayerMatchStat(p.jugid, 1);
      stamina[p.jugid] = p.condicion.toDouble();
    }
  }

  bool get isFinished => minute >= totalMinutes;

  int get currentPossessionHome {
    if (_posSampleCount == 0) return 50;
    return (_posSampleSum / _posSampleCount).round().clamp(25, 75);
  }

  /// Nilai momentum 0.0 (dominasi tandang) .. 1.0 (dominasi kandang)
  double get momentumRatio => ((homeTilt + 0.35) / 0.70).clamp(0.05, 0.95);

  TeamSetup? get userSetup =>
      userSide == 0 ? home : (userSide == 1 ? away : null);

  double _gauss(double mean, double sd) {
    final u = rng.nextDouble() +
        rng.nextDouble() +
        rng.nextDouble() +
        rng.nextDouble() +
        rng.nextDouble() +
        rng.nextDouble();
    return mean + (u - 3) * sd;
  }

  Player _pickWeighted(List<Player> pool, double Function(Player) w,
      {Player? fallback}) {
    if (pool.isEmpty) {
      if (fallback != null) return fallback;
      throw StateError('pool pemain kosong');
    }
    final weights = pool.map((p) => max(0.5, w(p))).toList();
    final total = weights.fold<double>(0, (a, b) => a + b);
    var r = rng.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      r -= weights[i];
      if (r <= 0) return pool[i];
    }
    return pool.last;
  }

  double _teamPressure(TeamSetup t) {
    switch (t.tactics.presion) {
      case Pressure.alta:
        return 1.35;
      case Pressure.baja:
        return 0.72;
      default:
        return 1.0;
    }
  }

  double _fatigueFactor(TeamSetup t) {
    if (t.xi.isEmpty) return 1.0;
    final avgStam = t.xi
            .map((p) => stamina[p.jugid] ?? p.condicion.toDouble())
            .reduce((a, b) => a + b) /
        t.xi.length;
    if (avgStam >= 65) return 1.0;
    return (0.82 + (avgStam / 65) * 0.18).clamp(0.75, 1.0);
  }

  void updateUserTactics(Tactics newTac) {
    final u = userSetup;
    if (u == null) return;
    u.tactics = newTac.copy();
  }

  MatchEvent? substituteUser(int outPlayerId, int inPlayerId) {
    final u = userSetup;
    if (u == null || userSubsUsed >= maxSubs) return null;
    final outIdx = u.xi.indexWhere((p) => p.jugid == outPlayerId);
    final inIdx = u.bench.indexWhere((p) => p.jugid == inPlayerId);
    if (outIdx < 0 || inIdx < 0) return null;

    final outP = u.xi[outIdx];
    final inP = u.bench.removeAt(inIdx);
    u.xi[outIdx] = inP;
    userSubsUsed++;
    subbedInIds.add(inP.jugid);
    stats[inP.jugid] = PlayerMatchStat(inP.jugid, userSide);
    stamina[inP.jugid] = inP.condicion.toDouble();
    stats[outP.jugid]?.minutos = max(1, minute);

    final ev = MatchEvent(
      minute,
      'cambio',
      userSide,
      inP.jugid,
      'Pergantian ${u.name}: ${inP.nombre} masuk menggantikan ${outP.nombre}.',
    );
    events.add(ev);
    return ev;
  }

  void _maybeAiSub(int side) {
    final t = side == 0 ? home : away;
    if (side == userSide || aiSubsUsed >= 3 || t.bench.isEmpty) return;
    if (minute < 58 || minute > 84 || rng.nextDouble() > 0.14) return;
    final candidates = t.outfield
        .where((p) => (stamina[p.jugid] ?? 100) < 70 || (stats[p.jugid]?.amarillas ?? 0) >= 1)
        .toList();
    if (candidates.isEmpty) return;
    final outP = candidates[rng.nextInt(candidates.length)];
    final role = outP.posid <= 4 ? 2 : outP.posid <= 8 ? 3 : 4;
    final inIdx = t.bench.indexWhere((b) =>
        b.posid != 1 && ((b.posid <= 4 ? 2 : b.posid <= 8 ? 3 : 4) == role));
    final pickIdx = inIdx >= 0 ? inIdx : t.bench.indexWhere((b) => b.posid != 1);
    if (pickIdx < 0) return;

    final outIdx = t.xi.indexOf(outP);
    if (outIdx < 0) return;
    final inP = t.bench.removeAt(pickIdx);
    t.xi[outIdx] = inP;
    aiSubsUsed++;
    subbedInIds.add(inP.jugid);
    stats[inP.jugid] = PlayerMatchStat(inP.jugid, side);
    stamina[inP.jugid] = inP.condicion.toDouble();
    stats[outP.jugid]?.minutos = max(1, minute);
    events.add(MatchEvent(
      minute,
      'cambio',
      side,
      inP.jugid,
      'Pergantian ${t.name}: ${inP.nombre} menggantikan ${outP.nombre}.',
    ));
  }

  List<MatchEvent> stepMinute() {
    if (isFinished) return const [];
    minute++;
    final newEvents = <MatchEvent>[];

    // Update stamina tiap pemain aktif di lapangan
    for (final sideTeam in [home, away]) {
      final pressMult = sideTeam.tactics.presion == Pressure.alta
          ? 1.35
          : sideTeam.tactics.presion == Pressure.baja
              ? 0.78
              : 1.0;
      for (final p in sideTeam.xi) {
        final fisMult = 1.18 - (p.fisik / 220);
        final workhorse = (p.habA == 17 || p.habB == 17) ? 0.75 : 1.0;
        final drain = (p.posid == 1 ? 0.08 : 0.42) *
            pressMult *
            fisMult *
            workhorse *
            sideTeam.staminaDrainFactor;
        stamina[p.jugid] = ((stamina[p.jugid] ?? 100.0) - drain).clamp(15.0, 100.0);
        final st = stats[p.jugid];
        if (st != null) st.minutos++;
      }
    }

    _maybeAiSub(0);
    _maybeAiSub(1);

    final homeAttack = (home.attackRating * _fatigueFactor(home)).round() +
        (homeAdvantage ? 3 : 0);
    final awayAttack = (away.attackRating * _fatigueFactor(away)).round();
    final homeMid = home.midfieldRating + (homeAdvantage ? 2 : 0);
    final awayMid = away.midfieldRating;
    final homeDef = (home.defenseRating * _fatigueFactor(home)).round() +
        (homeAdvantage ? 2 : 0);
    final awayDef = (away.defenseRating * _fatigueFactor(away)).round();

    var posBase = (55 + (homeMid - awayMid) * 0.55).clamp(28.0, 72.0).toDouble();
    if (home.tactics.estilo == Style.posesion) posBase += 4;
    if (away.tactics.estilo == Style.posesion) posBase -= 4;
    _posSampleSum += posBase.round();
    _posSampleCount++;

    final homeChanceRate =
        (0.125 * pow(1.26, (homeAttack - awayDef) / 18)).clamp(0.045, 0.34);
    final awayChanceRate =
        (0.104 * pow(1.26, (awayAttack - homeDef) / 18)).clamp(0.035, 0.32);

    homeTilt = (homeTilt + _gauss(0, 0.11)).clamp(-0.35, 0.35);

    for (var side = 0; side < 2; side++) {
      final isHome = side == 0;
      final atk = isHome ? home : away;
      final dfn = isHome ? away : home;
      if (atk.xi.isEmpty || dfn.xi.isEmpty) continue;
      var rate = isHome ? homeChanceRate : awayChanceRate;
      rate *= (1 + (isHome ? homeTilt : -homeTilt));
      if (minute > 75) {
        rate *= atk.tactics.mentalidad == Mentality.ofensivo ? 1.20 : 1.08;
      }

      if (rng.nextDouble() > rate) continue;

      final attackers = atk.outfield;
      if (attackers.isEmpty) continue;
      final shooter = _pickWeighted(
          attackers,
          (p) {
            final finisher = (p.habA == 9 ||
                    p.habB == 9 ||
                    p.habA == 13 ||
                    p.habB == 13 ||
                    p.habA == 24 ||
                    p.habB == 24)
                ? 1.22
                : 1.0;
            return (p.posid >= 9 ? 3.4 : p.posid >= 5 ? 1.5 : 0.7) *
                (0.5 + p.poder / 100) *
                (0.75 + (stamina[p.jugid] ?? 100) / 400) *
                finisher;
          });
      final mates = attackers.where((p) => p.jugid != shooter.jugid).toList();
      final assister = mates.isEmpty
          ? null
          : _pickWeighted(
              mates,
              (p) =>
                  (p.posid >= 5 ? 2.2 : 0.8) *
                  ((p.habA == 16 || p.habB == 16 || p.habA == 15 || p.habB == 15)
                      ? 1.35
                      : 1.0));

      if (isHome) {
        homeShots++;
      } else {
        awayShots++;
      }
      stats[shooter.jugid]?.tiros++;

      final gk = dfn.xi.firstWhere((p) => p.posid == 1, orElse: () => dfn.xi.first);
      final gkSkillBonus = (gk.habA == 1 || gk.habB == 1) ? 3 : 0;
      final quality =
          shooter.ataque + (atk.attackRating - dfn.defenseRating) * 0.55;
      final roll = rng.nextDouble() * 100 + _gauss(0, 7);
      final onTargetChance =
          (0.44 + (quality - (gk.kiper + gkSkillBonus)) / 260).clamp(0.24, 0.76);
      final onTarget = rng.nextDouble() < onTargetChance;

      if (!onTarget) {
        final ev = rng.nextDouble() < 0.16
            ? MatchEvent(
                minute,
                'palo',
                side,
                shooter.jugid,
                '${shooter.nombre} menyambar bola, tapi hanya membentur mistar!')
            : MatchEvent(
                minute,
                'fuera_juego',
                side,
                shooter.jugid,
                'Tembakan ${shooter.nombre} melebar tipis dari gawang.');
        events.add(ev);
        newEvents.add(ev);
        stats[shooter.jugid]?.rating += 0.03;
        continue;
      }

      if (isHome) {
        homeOnTarget++;
      } else {
        awayOnTarget++;
      }

      final shooterBoost = (shooter.habA == 9 || shooter.habB == 9) ? 0.03 : 0.0;
      final goalChance =
          (0.275 +
                  shooterBoost +
                  (quality - (dfn.defenseRating + gk.kiper + gkSkillBonus) / 2) / 240)
              .clamp(0.08, 0.52);
      if (roll < goalChance * 100) {
        if (isHome) {
          homeGoals++;
          homeTilt = (homeTilt + 0.12).clamp(-0.35, 0.35);
        } else {
          awayGoals++;
          homeTilt = (homeTilt - 0.12).clamp(-0.35, 0.35);
        }
        stats[shooter.jugid]?.goles++;
        stats[shooter.jugid]?.rating += 1.0;
        if (assister != null) {
          stats[assister.jugid]?.asistencias++;
          stats[assister.jugid]?.rating += 0.45;
        }
        final phrase = _goalPhrases[rng.nextInt(_goalPhrases.length)];
        final assistPhrase = _assistPhrases[rng.nextInt(_assistPhrases.length)];
        final assistText = assister == null
            ? ''
            : ', memanfaatkan aksi ${assister.nombre} yang $assistPhrase';
        final drama = minute >= 88 ? ' MENIT KRUSIAL!' : '';
        final ev = MatchEvent(
          minute,
          'gol',
          side,
          shooter.jugid,
          'GOL!$drama ${shooter.nombre} $phrase$assistText. '
              '${isHome ? homeGoals : awayGoals}-${isHome ? awayGoals : homeGoals}',
        );
        events.add(ev);
        newEvents.add(ev);
      } else {
        stats[gk.jugid]?.atajadas++;
        stats[gk.jugid]?.rating += 0.28;
        final ev = MatchEvent(
            minute,
            'atajada',
            side,
            shooter.jugid,
            'Peluang emas! ${shooter.nombre} menembak, tapi ${gk.nombre} '
                'melakukan penyelamatan hebat.');
        events.add(ev);
        newEvents.add(ev);
      }
    }

    // Pelanggaran, kartu, penalti
    final foulP = 0.135 * (_teamPressure(home) + _teamPressure(away)) / 2;
    if (rng.nextDouble() < foulP) {
      final isHomeFoul = rng.nextBool();
      final fTeam = isHomeFoul ? home : away;
      final oTeam = isHomeFoul ? away : home;
      final sideno = isHomeFoul ? 0 : 1;
      if (fTeam.xi.isNotEmpty && oTeam.xi.isNotEmpty) {
        final offender = _pickWeighted(
            fTeam.def_players.isEmpty ? fTeam.xi : fTeam.def_players,
            (p) => p.defensivo / 100 + 0.2,
            fallback: fTeam.xi.first);
        stats[offender.jugid]?.faltas++;

        if (rng.nextDouble() < 0.030) {
          final taker = _pickWeighted(
              oTeam.outfield, (p) => p.tembakan.toDouble(),
              fallback: oTeam.xi.first);
          final gk = fTeam.xi.firstWhere((p) => p.posid == 1,
              orElse: () => fTeam.xi.first);
          final scored = rng.nextDouble() < 0.76;
          final evPen = MatchEvent(
              minute,
              'penalti_keputusan',
              sideno,
              taker.jugid,
              'PENALTI! ${offender.nombre} melakukan pelanggaran di kotak. Wasit menunjuk titik putih.');
          events.add(evPen);
          newEvents.add(evPen);
          if (scored) {
            if (isHomeFoul) {
              awayGoals++;
            } else {
              homeGoals++;
            }
            stats[taker.jugid]?.goles++;
            stats[taker.jugid]?.rating += 1.0;
            final evG = MatchEvent(
                minute,
                'penalti_gol',
                isHomeFoul ? 1 : 0,
                taker.jugid,
                '${taker.nombre} mengeksekusi penalti dengan sempurna! Skor jadi '
                '${isHomeFoul ? awayGoals : homeGoals}-${isHomeFoul ? homeGoals : awayGoals}');
            events.add(evG);
            newEvents.add(evG);
          } else {
            stats[taker.jugid]?.rating -= 0.35;
            stats[gk.jugid]?.atajadas++;
            stats[gk.jugid]?.rating += 0.6;
            final evM = MatchEvent(
                minute,
                'penalti_fallado',
                sideno,
                taker.jugid,
                '${taker.nombre} gagal! ${gk.nombre} menebak arah dan menahan penalti!');
            events.add(evM);
            newEvents.add(evM);
          }
        } else if (rng.nextDouble() < 0.17) {
          final st = stats[offender.jugid]!;
          if (st.amarillas >= 1 || rng.nextDouble() < 0.035) {
            st.rojas++;
            st.rating -= 1.2;
            final evR = MatchEvent(minute, 'roja', sideno, offender.jugid,
                'KARTU MERAH! ${offender.nombre} diusir keluar lapangan.');
            events.add(evR);
            newEvents.add(evR);
            fTeam.xi.remove(offender);
            if (fTeam == home) {
              suspendedHome.add(offender.jugid);
            } else {
              suspendedAway.add(offender.jugid);
            }
          } else {
            st.amarillas++;
            st.rating -= 0.15;
            final evY = MatchEvent(minute, 'amarilla', sideno, offender.jugid,
                'Kartu kuning untuk ${offender.nombre} karena pelanggaran keras.');
            events.add(evY);
            newEvents.add(evY);
          }
        }
      }
    }

    // Cedera
    if (rng.nextDouble() < 0.0028) {
      final isHomeInj = rng.nextBool();
      final t = isHomeInj ? home : away;
      if (t.outfield.isNotEmpty) {
        final victim = t.outfield[rng.nextInt(t.outfield.length)];
        stats[victim.jugid]?.rating -= 0.1;
        final evI = MatchEvent(
            minute,
            'lesion',
            isHomeInj ? 0 : 1,
            victim.jugid,
            '${victim.nombre} terjatuh dan memegang kakinya. Dia cedera.');
        events.add(evI);
        newEvents.add(evI);
        if (isHomeInj) {
          injuriesHome.add(victim.jugid);
        } else {
          injuriesAway.add(victim.jugid);
        }
      }
    }

    // Cek apakah laga gugur seri di menit akhir 90+ -> lanjut Perpanjangan Waktu 2x15 menit
    if (minute >= totalMinutes && needWinner && !inExtraTime && homeGoals == awayGoals) {
      inExtraTime = true;
      totalMinutes = minute + 30;
      final evEt = MatchEvent(
        minute,
        'babak_tambahan',
        null,
        null,
        'Skor imbang $homeGoals-$awayGoals! Pertandingan berlanjut ke Perpanjangan Waktu!',
      );
      events.add(evEt);
      newEvents.add(evEt);
    }

    return newEvents;
  }

  MatchResult finalize() {
    if (_finalized != null) return _finalized!;
    final homePossession = currentPossessionHome;

    for (final e in stats.entries) {
      final st = e.value;
      final isHomePlayer = st.team == 0;
      final diff = isHomePlayer ? homeGoals - awayGoals : awayGoals - homeGoals;
      st.rating += diff * 0.16;
      st.rating +=
          (isHomePlayer ? (homePossession - 50) : (50 - homePossession)) * 0.008;
      st.rating = st.rating.clamp(3.0, 9.9);
      if (st.minutos == 0) st.minutos = 90;
    }

    int? mvpId;
    double best = -1;
    for (final e in stats.entries) {
      if (e.value.rating > best) {
        best = e.value.rating;
        mvpId = e.key;
      }
    }

    var penHome = 0, penAway = 0;
    if (needWinner && homeGoals == awayGoals) {
      final homeGk = home.xi.firstWhere((p) => p.posid == 1, orElse: () => home.xi.first);
      final awayGk = away.xi.firstWhere((p) => p.posid == 1, orElse: () => away.xi.first);
      final awaySavePenalty = (homeGk.habA == 2 || homeGk.habB == 2) ? 0.08 : 0.0;
      final homeSavePenalty = (awayGk.habA == 2 || awayGk.habB == 2) ? 0.08 : 0.0;
      events.add(MatchEvent(totalMinutes, 'penalti_keputusan', null, null,
          'Skor masih imbang setelah perpanjangan waktu, lanjut ke adu penalti!'));
      while (penHome == penAway) {
        penHome = 0;
        penAway = 0;
        for (var i = 0; i < 5; i++) {
          if (rng.nextDouble() < (0.76 - homeSavePenalty)) penHome++;
          if (rng.nextDouble() < (0.74 - awaySavePenalty)) penAway++;
        }
      }
      events.add(MatchEvent(totalMinutes, 'penalti_gol', penHome > penAway ? 0 : 1, null,
          'Hasil adu penalti: ${home.name} $penHome - $penAway ${away.name}!'));
    }

    _finalized = MatchResult(
      homeGoals: homeGoals,
      awayGoals: awayGoals,
      events: events,
      stats: stats,
      homeShots: homeShots,
      awayShots: awayShots,
      homeOnTarget: homeOnTarget,
      awayOnTarget: awayOnTarget,
      homePossession: homePossession,
      awayPossession: 100 - homePossession,
      homeInjured: injuriesHome,
      awayInjured: injuriesAway,
      homeSuspended: suspendedHome,
      awaySuspended: suspendedAway,
      mvpId: mvpId,
      penHome: needWinner && (penHome + penAway) > 0 ? penHome : null,
      penAway: needWinner && (penHome + penAway) > 0 ? penAway : null,
    );
    return _finalized!;
  }
}

class MatchEngine {
  final Random rng;
  MatchEngine([Random? r]) : rng = r ?? Random();

  LiveMatchSession createSession(
    TeamSetup home,
    TeamSetup away, {
    int userSide = 0,
    bool needWinner = false,
    bool homeAdvantage = true,
  }) {
    return LiveMatchSession(
      home: home,
      away: away,
      userSide: userSide,
      needWinner: needWinner,
      homeAdvantage: homeAdvantage,
      rng: rng,
    );
  }

  MatchResult simulate(
    TeamSetup home,
    TeamSetup away, {
    bool needWinner = false,
    bool homeAdvantage = true,
  }) {
    final s = LiveMatchSession(
      home: home,
      away: away,
      userSide: -1,
      needWinner: needWinner,
      homeAdvantage: homeAdvantage,
      rng: rng,
    );
    while (!s.isFinished) {
      s.stepMinute();
    }
    return s.finalize();
  }

  /// Simulasi cepat untuk laga tim AI (tanpa log menit): pakai Poisson
  /// berdasarkan selisih kekuatan.
  (int, int) quickScore(TeamSetup home, TeamSetup away) {
    final att = home.attackRating + 3;
    final dfn = away.defenseRating;
    final hx = (1.42 * pow(1.35, (att - dfn) / 22)).clamp(0.15, 5.0).toDouble();
    final ax = (1.12 * pow(1.35, (away.attackRating - home.defenseRating) / 22))
        .clamp(0.12, 5.0)
        .toDouble();
    return (_poisson(hx), _poisson(ax));
  }

  int _poisson(double lambda) {
    final l = exp(-lambda);
    var k = 0;
    var p = 1.0;
    do {
      k++;
      p *= rng.nextDouble();
    } while (p > l);
    return k - 1;
  }
}

extension on TeamSetup {
  List<Player> get def_players =>
      xi.where((p) => p.posid >= 2 && p.posid <= 4).toList();
}
