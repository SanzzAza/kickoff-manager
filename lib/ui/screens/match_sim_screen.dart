import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../audio/sound_service.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'tactics_screen.dart';

class MatchSimScreen extends StatefulWidget {
  final GameService service;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onMatchFinished;
  const MatchSimScreen({
    super.key,
    required this.service,
    this.refreshSignal,
    this.onMatchFinished,
  });
  @override
  State<MatchSimScreen> createState() => _MatchSimScreenState();
}

class _MatchSimScreenState extends State<MatchSimScreen> {
  Map<String, dynamic>? fixture;
  Team? home;
  Team? away;
  Team? userTeam;
  MatchResult? result;
  bool playing = false;
  bool paused = false;
  bool fast = false;
  bool halfTimeShown = false;
  int minute = 0;
  int homeGoals = 0, awayGoals = 0;
  final visible = <MatchEvent>[];
  Timer? timer;
  int speedMultiplier = 1;
  int eventIndex = 0;
  bool needWinner = false;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onSignal);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onSignal);
    timer?.cancel();
    super.dispose();
  }

  void _onSignal() {
    if (!mounted) return;
    // Hanya muat ulang otomatis bila tidak sedang di tengah laga aktif.
    if (!playing && result == null) {
      _load();
    }
  }

  Future<void> _load() async {
    timer?.cancel();
    final t = await widget.service.userTeam();
    final f = await widget.service.nextUserFixture();
    if (!mounted) return;
    setState(() {
      userTeam = t;
      fixture = f;
      home = null;
      away = null;
      result = null;
      playing = false;
      paused = false;
      fast = false;
      halfTimeShown = false;
      visible.clear();
      minute = 0;
      homeGoals = awayGoals = 0;
      eventIndex = 0;
    });
    if (f != null) {
      final h = await widget.service.world.team(f['par_equid_local'] as int);
      final a = await widget.service.world.team(f['par_equid_visita'] as int);
      if (!mounted) return;
      setState(() {
        home = h;
        away = a;
      });
    }
  }

  Future<void> _startMatch() async {
    if (fixture == null || playing) return;
    timer?.cancel();
    setState(() {
      playing = true;
      paused = false;
      halfTimeShown = false;
      visible.clear();
      minute = 0;
      homeGoals = awayGoals = 0;
      eventIndex = 0;
    });
    if (!fast) {
      SoundService.instance.playKickoff();
    }
    try {
      final res = await widget.service.playUserMatch(
          fixture!['partid'] as int, needWinner: needWinner);
      if (!mounted) return;
      result = res;
      if (fast) {
        SoundService.instance.playFulltime();
        setState(() {
          playing = false;
          minute = 90;
          homeGoals = res.homeGoals;
          awayGoals = res.awayGoals;
          visible
            ..clear()
            ..add(MatchEvent(
              90,
              'final',
              null,
              null,
              'Peluit panjang berbunyi! Skor akhir ${res.homeGoals}-${res.awayGoals}.',
            ))
            ..addAll(res.events.reversed);
          eventIndex = res.events.length;
        });
        return;
      }
      visible.insert(
        0,
        MatchEvent(
          0,
          'inicio',
          null,
          null,
          'Kick-off! Pertandingan ${home?.nombre ?? ""} vs ${away?.nombre ?? ""} dimulai.',
        ),
      );
      _tick();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        playing = false;
        fast = false;
      });
    }
  }

  void _playSfxForEvent(MatchEvent e) {
    switch (e.type) {
      case 'gol':
      case 'penalti_gol':
        SoundService.instance.playGoal();
        break;
      case 'amarilla':
      case 'roja':
      case 'penalti_keputusan':
        SoundService.instance.playFoul();
        break;
      case 'palo':
      case 'penalti_fallado':
        SoundService.instance.playMiss();
        break;
    }
  }

  void _tick() {
    timer?.cancel();
    if (paused) return;
    // Basis 1x = 650ms per menit (~58 detik per laga) agar komentar nyaman dibaca
    final delayMs = (650 / speedMultiplier).round().clamp(40, 1000);
    timer = Timer(Duration(milliseconds: delayMs), () {
      if (!mounted || result == null) return;
      if (paused) return;
      final r = result!;
      MatchEvent? soundEvent;
      var finishedNow = false;
      setState(() {
        minute = (minute + 1).clamp(0, 90);
        if (minute == 45 && !halfTimeShown) {
          halfTimeShown = true;
          visible.insert(
            0,
            MatchEvent(
              45,
              'inicio',
              null,
              null,
              'Turun minum! Skor sementara $homeGoals-$awayGoals.',
            ),
          );
        }
        while (eventIndex < r.events.length &&
            (minute >= 90 || r.events[eventIndex].minute <= minute)) {
          final e = r.events[eventIndex];
          visible.insert(0, e);
          if (e.type == 'gol' || e.type == 'penalti_gol') {
            if (e.team == 0) {
              homeGoals++;
            } else {
              awayGoals++;
            }
          }
          soundEvent = e;
          eventIndex++;
        }
        if (minute >= 90 && eventIndex >= r.events.length) {
          homeGoals = r.homeGoals;
          awayGoals = r.awayGoals;
          playing = false;
          finishedNow = true;
          visible.insert(
            0,
            MatchEvent(
              90,
              'final',
              null,
              null,
              'Peluit panjang berbunyi! Skor akhir ${r.homeGoals}-${r.awayGoals}.',
            ),
          );
        }
      });

      if (finishedNow) {
        timer?.cancel();
        SoundService.instance.playFulltime();
        return;
      }
      if (soundEvent != null) {
        _playSfxForEvent(soundEvent!);
      }
      if (minute < 90 || eventIndex < r.events.length) _tick();
    });
  }

  void _togglePause() {
    if (result == null || !playing) return;
    setState(() {
      paused = !paused;
    });
    if (!paused) {
      _tick();
    } else {
      timer?.cancel();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (userTeam == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ruang Pertandingan'),
        actions: [
          IconButton(
            tooltip: SoundService.instance.enabled ? 'Matikan suara' : 'Nyalakan suara',
            onPressed: () {
              setState(() {
                SoundService.instance.enabled = !SoundService.instance.enabled;
              });
              if (!SoundService.instance.enabled) {
                SoundService.instance.stopAll();
              } else {
                SoundService.instance.playTap();
              }
            },
            icon: Icon(
              SoundService.instance.enabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              size: 20,
            ),
          ),
          if (playing && result != null)
            IconButton(
              tooltip: paused ? 'Lanjutkan' : 'Jeda',
              onPressed: _togglePause,
              icon: Icon(paused ? Icons.play_arrow : Icons.pause, size: 22),
            ),
          TextButton(
            onPressed: () {
              setState(() {
                speedMultiplier = speedMultiplier == 1
                    ? 2
                    : speedMultiplier == 2
                        ? 4
                        : speedMultiplier == 4
                            ? 8
                            : 1;
              });
            },
            child: Text(
              '${speedMultiplier}x',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                color: AppColors.accent,
              ),
            ),
          ),
          IconButton(
              onPressed: playing ? null : _load,
              icon: const Icon(Icons.refresh, size: 20)),
        ],
      ),
      body: fixture == null
          ? const EmptyState(
              icon: Icons.sports_soccer,
              text: 'Belum ada laga tersisa musim ini.\nTutup musim di tab Klub untuk lanjut ke musim baru.')
          : Column(
              children: [
                _scoreboard(),
                if (result == null) _preMatch() else _liveFeed(),
              ],
            ),
    );
  }

  Widget _scoreboard() {
    final isHomeUser = home?.equid == userTeam!.equid;
    return Container(
      margin: const EdgeInsets.all(14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF0E3B27), Color(0xFF102019)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.line),
      ),
      child: Column(
        children: [
          Text(
              result == null
                  ? 'PEKAN ${fixture!['par_jornada']}'
                  : minute >= 90
                      ? 'PERTANDINGAN SELESAI'
                      : paused
                          ? "DIJEDA · $minute'"
                          : "LIVE · $minute'",
              style: TextStyle(
                  fontSize: 11,
                  letterSpacing: 1.4,
                  fontWeight: FontWeight.w800,
                  color: minute >= 90
                      ? AppColors.muted
                      : paused
                          ? AppColors.accent
                          : AppColors.primary)),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _teamSide(home, isHomeUser)),
              Column(
                children: [
                  Text('$homeGoals - $awayGoals',
                      style: const TextStyle(
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  if (result?.penHome != null)
                    Text('pen ${result!.penHome}-${result!.penAway}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                ],
              ),
              Expanded(child: _teamSide(away, !isHomeUser)),
            ],
          ),
          if (result != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                    child: _miniStat(
                        '${result!.homeShots}-${result!.awayShots}', 'Tembakan')),
                Expanded(
                    child: _miniStat(
                        '${result!.homeOnTarget}-${result!.awayOnTarget}', 'On target')),
                Expanded(
                    child: _miniStat(
                        '${result!.homePossession}%-${result!.awayPossession}%',
                        'Bola')),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _teamSide(Team? t, bool isUser) {
    if (t == null) return const SizedBox();
    return Column(
      children: [
        CrestWidget(
          nombre: t.nombre,
          colorA: t.colorA,
          colorB: t.colorB,
          size: 46,
        ),
        const SizedBox(height: 8),
        Text(t.nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: isUser ? AppColors.primary : AppColors.text)),
        const SizedBox(height: 4),
        PowerBadge(t.poder),
      ],
    );
  }

  Widget _miniStat(String v, String l) => Column(
        children: [
          Text(v, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
          Text(l, style: const TextStyle(fontSize: 9.5, color: AppColors.muted)),
        ],
      );

  Widget _preMatch() {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Column(
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Rencana pertandingan',
                        style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text(
                        'Starting XI dipilih otomatis dari pemain terbaik yang '
                        'tersedia. Pemain cedera/skorsing tidak diikutkan.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(context,
                              MaterialPageRoute(
                                  builder: (_) =>
                                      TacticsScreen(service: widget.service))),
                          icon: const Icon(Icons.psychology, size: 16),
                          label: const Text('Ubah taktik'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: playing ? null : _startMatch,
              icon: const Icon(Icons.play_arrow_rounded),
              label: const Text('KICK OFF'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54)),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: playing
                  ? null
                  : () {
                      setState(() => fast = true);
                      _startMatch();
                    },
              icon: const Icon(Icons.bolt, size: 18),
              label: const Text('Simulasi instan'),
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(46)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _liveFeed() {
    final done = minute >= 90 && eventIndex >= (result?.events.length ?? 0);
    return Expanded(
      child: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              itemCount: visible.length + 1,
              itemBuilder: (context, i) {
                if (i == visible.length) {
                  if (!done) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      child: Center(
                          child: paused
                              ? TextButton.icon(
                                  onPressed: _togglePause,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Lanjutkan laga'),
                                )
                              : const SizedBox(
                                  height: 20,
                                  width: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2))),
                    );
                  }
                  return const SizedBox(height: 4);
                }
                return _eventTile(visible[i]);
              },
            ),
          ),
          if (done)
            SafeArea(
              top: false,
              child: Container(
                padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
                decoration: const BoxDecoration(
                  color: AppColors.surface,
                  border: Border(top: BorderSide(color: AppColors.line)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _showRatings,
                        style: OutlinedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: const Text('RATING'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: () async {
                          final round = fixture?['par_jornada'] as int?;
                          await widget.service
                              .finishRound(playedJornada: round);
                          await widget.service.trainWeek();
                          await _load();
                          widget.onMatchFinished?.call();
                        },
                        style: ElevatedButton.styleFrom(
                            minimumSize: const Size.fromHeight(48)),
                        child: const Text('LANJUT'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showRatings() async {
    final r = result;
    if (r == null) return;
    final rows = <List<dynamic>>[];
    for (final st in r.stats.values) {
      final p = await widget.service.world.player(st.playerId);
      if (p == null) continue;
      rows.add([p, st]);
    }
    rows.sort((a, b) =>
        (b[1] as PlayerMatchStat).rating.compareTo((a[1] as PlayerMatchStat).rating));
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.8,
        builder: (ctx, ctrl) => ListView(
          controller: ctrl,
          padding: const EdgeInsets.all(16),
          children: [
            const Text('Rating pemain',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            const Text('Skala 3.0 - 9.9 · MVP ditandai bintang',
                style: TextStyle(fontSize: 11, color: AppColors.muted)),
            const SizedBox(height: 12),
            ...rows.map((row) {
              final p = row[0] as Player;
              final st = row[1] as PlayerMatchStat;
              final isMvp = r.mvpId == p.jugid;
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  children: [
                    SizedBox(
                        width: 30,
                        child: Text(Squads.positionName(p.posid),
                            style: TextStyle(
                                fontSize: 9.5,
                                fontWeight: FontWeight.w800,
                                color: Squads.positionColor(p.posid)))),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            Flexible(
                                child: Text(p.nombre,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13))),
                            if (isMvp)
                              const Padding(
                                padding: EdgeInsets.only(left: 4),
                                child: Icon(Icons.star,
                                    size: 13, color: AppColors.gold),
                              ),
                          ]),
                          Text(
                              '${st.goles} gol · ${st.asistencias} assist · ${st.tiros} tembakan'
                              '${st.atajadas > 0 ? " · ${st.atajadas} penyelamatan" : ""}'
                              '${st.amarillas > 0 ? " · kartu kuning" : ""}'
                              '${st.rojas > 0 ? " · kartu merah" : ""}',
                              style: const TextStyle(
                                  fontSize: 10.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: Squads.powerColor((st.rating * 10).round())
                            .withOpacity(0.16),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(st.rating.toStringAsFixed(1),
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              color: Squads.powerColor((st.rating * 10).round()))),
                    ),
                  ],
                ),
              );
            }),
          ],
        ),
      ),
    );
  }

  Widget _eventTile(MatchEvent e) {
    IconData icon;
    Color color = AppColors.muted;
    switch (e.type) {
      case 'gol':
        icon = Icons.sports_soccer;
        color = AppColors.primary;
        break;
      case 'penalti_gol':
        icon = Icons.sports_soccer;
        color = AppColors.accent;
        break;
      case 'penalti_fallado':
        icon = Icons.block;
        color = AppColors.danger;
        break;
      case 'amarilla':
        icon = Icons.square;
        color = const Color(0xFFFFEB3B);
        break;
      case 'roja':
        icon = Icons.square;
        color = AppColors.danger;
        break;
      case 'lesion':
        icon = Icons.healing;
        color = Colors.orangeAccent;
        break;
      case 'atajada':
        icon = Icons.back_hand;
        color = const Color(0xFF64B5F6);
        break;
      case 'palo':
        icon = Icons.linear_scale;
        color = AppColors.accent;
        break;
      case 'fuera_juego':
        icon = Icons.flag;
        color = AppColors.muted;
        break;
      case 'penalti_keputusan':
        icon = Icons.sports;
        color = AppColors.accent;
        break;
      case 'inicio':
      case 'final':
        icon = Icons.sports;
        color = AppColors.primary;
        break;
      default:
        icon = Icons.info_outline;
    }
    final isHighlight = e.type == 'gol' || e.type == 'penalti_gol' || e.type == 'final';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 26,
            child: Text("${e.minute}'",
                style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted)),
          ),
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(e.text,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.35,
                    color: isHighlight ? AppColors.text : AppColors.muted,
                    fontWeight: isHighlight ? FontWeight.w700 : FontWeight.w400)),
          ),
        ],
      ),
    );
  }
}
