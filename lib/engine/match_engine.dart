// Engine pertandingan: simulasi menit-per-menit.
// Terinspirasi struktur AlgPartido.dart pada game aslinya:
// tiap menit dihitung peluang, lalu diselesaikan jadi tembakan/gol/penyelamatan,
// plus kartu, cedera, dan rating pemain.

import 'dart:math';
import '../models/models.dart';

class TeamSetup {
  final List<Player> xi; // 11 pemain
  final List<Player> bench;
  final Tactics tactics;
  final int clubPower;
  final String name;
  TeamSetup({
    required this.xi,
    required this.bench,
    required this.tactics,
    required this.clubPower,
    required this.name,
  });

  int _avg(Iterable<int> v) =>
      v.isEmpty ? 40 : (v.reduce((a, b) => a + b) / v.length).round();

  List<Player> get _def => xi.where((p) => p.posid >= 2 && p.posid <= 4).toList();
  List<Player> get _mid => xi.where((p) => p.posid >= 5 && p.posid <= 8).toList();
  List<Player> get _att => xi.where((p) => p.posid >= 9).toList();
  Player get _gk => xi.firstWhere((p) => p.posid == 1, orElse: () => xi.first);

  int get attackRating {
    final base = _avg(_att.map((p) => p.ataque));
    final mid = _avg(_mid.map((p) => p.creacion));
    var v = (base * 0.72 + mid * 0.28).round();
    if (tactics.mentalidad == Mentality.ofensivo) v += 5;
    if (tactics.mentalidad == Mentality.defensivo) v -= 4;
    if (tactics.estilo == Style.directo) v += 2;
    return v.clamp(1, 120);
  }

  int get midfieldRating {
    final v = _avg(_mid.map((p) => (p.creacion * 2 + p.defensivo) ~/ 3));
    var r = v;
    if (tactics.estilo == Style.posesion) r += 4;
    if (tactics.presion == Pressure.alta) r += 2;
    return r.clamp(1, 120);
  }

  int get defenseRating {
    final d = _avg(_def.map((p) => p.defensivo));
    final gk = _gk.kiper;
    var v = (d * 0.78 + gk * 0.22).round();
    if (tactics.mentalidad == Mentality.defensivo) v += 5;
    if (tactics.mentalidad == Mentality.ofensivo) v -= 4;
    if (tactics.linea <= 2) v += 3;
    if (tactics.linea >= 4) v -= 2;
    return v.clamp(1, 120);
  }

  int get overall =>
      ((attackRating * 1.05 + midfieldRating * 1.1 + defenseRating * 0.95) / 3)
          .round();

  List<Player> get outfield => xi.where((p) => p.posid != 1).toList();
}

class MatchEngine {
  final Random rng;
  MatchEngine([Random? r]) : rng = r ?? Random();

  double _gauss(double mean, double sd) {
    final u = rng.nextDouble() + rng.nextDouble() + rng.nextDouble() +
        rng.nextDouble() + rng.nextDouble() + rng.nextDouble();
    return mean + (u - 3) * sd;
  }

  Player _pickWeighted(List<Player> pool, double Function(Player) w) {
    final weights = pool.map((p) => max(0.5, w(p))).toList();
    final total = weights.fold<double>(0, (a, b) => a + b);
    var r = rng.nextDouble() * total;
    for (var i = 0; i < pool.length; i++) {
      r -= weights[i];
      if (r <= 0) return pool[i];
    }
    return pool.last;
  }

  static const List<String> _goalPhrases = [
    'melesakkan bola ke sudut kanan gawang',
    'menyelesaikan serangan balik dengan dingin',
    'menembak keras dari tepi kotak penalti',
    'menyundul bola hasil umpan silang',
    'melewati bek lalu menaklukkan kiper',
    'memanfaatkan kesalahan lini belakang',
    'melesat dari sisi kiri lalu menembak silang',
    'mengecoh kiper dengan tembakan rendah',
  ];

  static const List<String> _assistPhrases = [
    'berhasil mengirim umpan terukur',
    'memberi umpan matang dari sisi lapangan',
    'melakukan kombinasi satu-dua apik dengan',
    'mengirim bola silang mematikan kepada',
    'mencuri bola lalu melepas assist kepada',
  ];

  MatchResult simulate(
    TeamSetup home,
    TeamSetup away, {
    bool needWinner = false,
    bool homeAdvantage = true,
  }) {
    final events = <MatchEvent>[];
    final stats = <int, PlayerMatchStat>{};
    for (final p in [...home.xi, ...away.xi]) {
      stats[p.jugid] = PlayerMatchStat(p.jugid, home.xi.contains(p) ? 0 : 1);
    }

    var homeGoals = 0;
    var awayGoals = 0;
    var homeShots = 0, awayShots = 0, homeOnTarget = 0, awayOnTarget = 0;

    final homeAttack = home.attackRating + (homeAdvantage ? 3 : 0);
    final awayAttack = away.attackRating;
    final homeMid = home.midfieldRating + (homeAdvantage ? 2 : 0);
    final awayMid = away.midfieldRating;
    final homeDef = home.defenseRating + (homeAdvantage ? 2 : 0);
    final awayDef = away.defenseRating;

    // Penguasaan bola berdasar lini tengah + gaya main
    var possessionBase =
        (55 + (homeMid - awayMid) * 0.55).clamp(28.0, 72.0).toDouble();
    if (home.tactics.estilo == Style.posesion) possessionBase += 4;
    if (away.tactics.estilo == Style.posesion) possessionBase -= 4;
    final homePossession = possessionBase.round().clamp(25, 75);

    // Peluang dasar: total tembakan rata-rata ~12 per tim
    final homeChanceRate =
        (0.125 * pow(1.26, (homeAttack - awayDef) / 18)).clamp(0.045, 0.34);
    final awayChanceRate =
        (0.104 * pow(1.26, (awayAttack - homeDef) / 18)).clamp(0.035, 0.32);

    double homeTilt = 0;
    final injuriesHome = <int>[];
    final injuriesAway = <int>[];
    final suspendedHome = <int>[];
    final suspendedAway = <int>[];

    final totalMinutes = 90 + rng.nextInt(5) + 1;

    for (var minute = 1; minute <= totalMinutes; minute++) {
      // momentum berjalan: mempengaruhi peluang sedikit
      homeTilt = (homeTilt + _gauss(0, 0.11)).clamp(-0.35, 0.35);

      for (var side = 0; side < 2; side++) {
        final isHome = side == 0;
        final atk = isHome ? home : away;
        final dfn = isHome ? away : home;
        var rate = isHome ? homeChanceRate : awayChanceRate;
        rate *= (1 + (isHome ? homeTilt : -homeTilt));
        if (minute > 75) {
          // menit akhir lebih terbuka
          rate *= atk.tactics.mentalidad == Mentality.ofensivo ? 1.18 : 1.08;
        }

        if (rng.nextDouble() > rate) continue;

        final attackers = atk.outfield;
        if (attackers.isEmpty) continue;
        final shooter = _pickWeighted(
            attackers,
            (p) => p.posid == 1
                ? 0.2
                : (p.posid >= 9 ? 3.4 : p.posid >= 5 ? 1.5 : 0.7) *
                    (0.5 + p.poder / 100));
        final assister = _pickWeighted(
            attackers.where((p) => p.jugid != shooter.jugid).toList(),
            (p) => p.posid >= 5 ? 2.2 : 0.8);

        if (isHome) {
          homeShots++;
        } else {
          awayShots++;
        }
        stats[shooter.jugid]!.tiros++;

        final gk = dfn.xi.firstWhere((p) => p.posid == 1, orElse: () => dfn.xi.first);
        final quality = shooter.ataque + (atk.attackRating - dfn.defenseRating) * 0.55;
        final roll = rng.nextDouble() * 100 + _gauss(0, 7);
        final onTargetChance =
            (0.44 + (quality - gk.kiper) / 260).clamp(0.24, 0.76);
        final onTarget = rng.nextDouble() < onTargetChance;

        if (!onTarget) {
          if (rng.nextDouble() < 0.16) {
            events.add(MatchEvent(
                minute,
                'palo',
                side,
                shooter.jugid,
                '${shooter.nombre} menyambar bola, tapi hanya membentur mistar!'));
          } else {
            events.add(MatchEvent(
                minute,
                'fuera_juego',
                side,
                shooter.jugid,
                'Tembakan ${shooter.nombre} melebar tipis dari gawang.'));
          }
          stats[shooter.jugid]!.rating += 0.03;
          continue;
        }

        if (isHome) {
          homeOnTarget++;
        } else {
          awayOnTarget++;
        }

        final goalChance =
            (0.275 + (quality - (dfn.defenseRating + gk.kiper) / 2) / 240)
                .clamp(0.08, 0.52);
        if (roll < goalChance * 100) {
          if (isHome) {
            homeGoals++;
          } else {
            awayGoals++;
          }
          stats[shooter.jugid]!.goles++;
          stats[shooter.jugid]!.rating += 1.0;
          if (assister.jugid != shooter.jugid) {
            stats[assister.jugid]!.asistencias++;
            stats[assister.jugid]!.rating += 0.45;
          }
          final phrase = _goalPhrases[rng.nextInt(_goalPhrases.length)];
          final assistPhrase = _assistPhrases[rng.nextInt(_assistPhrases.length)];
          events.add(MatchEvent(
            minute,
            'gol',
            side,
            shooter.jugid,
            'GOL! ${shooter.nombre} $phrase, memanfaatkan aksi ${assister.nombre} '
                'yang $assistPhrase. ${isHome ? homeGoals : awayGoals}-${isHome ? awayGoals : homeGoals}',
          ));
        } else {
          stats[gk.jugid]!.atajadas++;
          stats[gk.jugid]!.rating += 0.28;
          events.add(MatchEvent(
              minute,
              'atajada',
              side,
              shooter.jugid,
              'Peluang emas! ${shooter.nombre} menembak, tapi ${gk.nombre} '
                  'melakukan penyelamatan hebat.'));
        }
      }

      // Pelanggaran, kartu, cedera, penalti
      final foulP =
          0.135 * (atk_teamPressure(home) + atk_teamPressure(away)) / 2;
      if (rng.nextDouble() < foulP) {
        final isHomeFoul = rng.nextBool();
        final fTeam = isHomeFoul ? home : away;
        final oTeam = isHomeFoul ? away : home;
        final sideno = isHomeFoul ? 0 : 1;
        final offender = _pickWeighted(fTeam.def_players.isEmpty
            ? fTeam.xi
            : fTeam.def_players, (p) => p.defensivo / 100 + 0.2);
        stats[offender.jugid]!.faltas++;

        if (rng.nextDouble() < 0.030) {
          // penalti
          final taker = _pickWeighted(oTeam.outfield, (p) => p.tembakan.toDouble());
          final gk = fTeam.xi.firstWhere((p) => p.posid == 1, orElse: () => fTeam.xi.first);
          final scored = rng.nextDouble() < 0.76;
          events.add(MatchEvent(minute, 'penalti_keputusan', sideno, taker.jugid,
              'PENALTI! ${offender.nombre} melakukan pelanggaran di kotak. Wasit menunjuk titik putih.'));
          if (scored) {
            if (isHomeFoul) {
              awayGoals++;
            } else {
              homeGoals++;
            }
            stats[taker.jugid]!.goles++;
            stats[taker.jugid]!.rating += 1.0;
            events.add(MatchEvent(minute, 'penalti_gol', sideno, taker.jugid,
                '${taker.nombre} mengeksekusi penalti dengan sempurna! Skor jadi '
                '${isHomeFoul ? awayGoals : homeGoals}-${isHomeFoul ? homeGoals : awayGoals}'));
          } else {
            stats[taker.jugid]!.rating -= 0.35;
            stats[gk.jugid]!.atajadas++;
            stats[gk.jugid]!.rating += 0.6;
            events.add(MatchEvent(minute, 'penalti_fallado', sideno, taker.jugid,
                '${taker.nombre} gagal! ${gk.nombre} menebak arah dan menahan penalti!'));
          }
        } else if (rng.nextDouble() < 0.17) {
          final st = stats[offender.jugid]!;
          if (st.amarillas >= 1 || rng.nextDouble() < 0.035) {
            st.rojas++;
            st.rating -= 1.2;
            events.add(MatchEvent(minute, 'roja', sideno, offender.jugid,
                'KARTU MERAH! ${offender.nombre} diusir keluar lapangan.'));
            fTeam.xi.remove(offender);
            if (fTeam == home) {
              suspendedHome.add(offender.jugid);
            } else {
              suspendedAway.add(offender.jugid);
            }
          } else {
            st.amarillas++;
            st.rating -= 0.15;
            events.add(MatchEvent(minute, 'amarilla', sideno, offender.jugid,
                'Kartu kuning untuk ${offender.nombre} karena pelanggaran keras.'));
          }
        }
      }

      // Cedera
      if (rng.nextDouble() < 0.0028) {
        final isHome = rng.nextBool();
        final t = isHome ? home : away;
        final victim = t.outfield[rng.nextInt(t.outfield.length)];
        stats[victim.jugid]!.rating -= 0.1;
        events.add(MatchEvent(minute, 'lesion', isHome ? 0 : 1, victim.jugid,
            '${victim.nombre} terjatuh dan memegang kakinya. Dia harus keluar lapangan.'));
        if (isHome) {
          injuriesHome.add(victim.jugid);
        } else {
          injuriesAway.add(victim.jugid);
        }
      }
    }

    // Rating akhir: menyesuaikan hasil tim + penampilan
    for (final e in stats.entries) {
      final st = e.value;
      st.minutos = 90;
      final isHomePlayer = st.team == 0;
      final diff = isHomePlayer ? homeGoals - awayGoals : awayGoals - homeGoals;
      st.rating += diff * 0.16;
      st.rating += (isHomePlayer ? (homePossession - 50) : (50 - homePossession)) * 0.008;
      st.rating = st.rating.clamp(3.0, 9.9);
      st.minutos = 90;
    }

    // MVP: rating tertinggi
    int? mvpId;
    double best = -1;
    for (final e in stats.entries) {
      if (e.value.rating > best) {
        best = e.value.rating;
        mvpId = e.key;
      }
    }

    // Adu penalti bila butuh pemenang (format gugur)
    var penHome = 0, penAway = 0;
    if (needWinner && homeGoals == awayGoals) {
      events.add(MatchEvent(totalMinutes, 'penalti_keputusan', null, null,
          'Skor imbang, pertandingan dilanjutkan ke adu penalti!'));
      while (penHome == penAway) {
        penHome = 0;
        penAway = 0;
        for (var i = 0; i < 5; i++) {
          if (rng.nextDouble() < 0.76) penHome++;
          if (rng.nextDouble() < 0.74) penAway++;
        }
      }
    }

    return MatchResult(
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
  }

  double atk_teamPressure(TeamSetup t) {
    switch (t.tactics.presion) {
      case Pressure.alta:
        return 1.35;
      case Pressure.baja:
        return 0.72;
      default:
        return 1.0;
    }
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
