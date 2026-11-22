import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../audio/sound_service.dart';
import '../../engine/game_service.dart';
import '../../engine/match_engine.dart';
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
  LiveMatchSession? session;
  MatchResult? result;
  bool playing = false;
  bool paused = false;
  bool fast = false;
  bool halfTimeShown = false;
  bool committed = false;
  int minute = 0;
  int homeGoals = 0, awayGoals = 0;
  final visible = <MatchEvent>[];
  Timer? timer;
  int speedMultiplier = 1;
  double ballX = 0.5;
  double ballY = 0.5;

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
    SoundService.instance.stopAmbience();
    super.dispose();
  }

  void _onSignal() {
    if (!mounted) return;
    if (!playing && result == null) {
      _load();
    }
  }

  Future<void> _load() async {
    timer?.cancel();
    SoundService.instance.stopAmbience();
    final t = await widget.service.userTeam();
    final f = await widget.service.nextUserFixture();
    if (!mounted) return;
    setState(() {
      userTeam = t;
      fixture = f;
      home = null;
      away = null;
      session = null;
      result = null;
      playing = false;
      paused = false;
      fast = false;
      halfTimeShown = false;
      committed = false;
      visible.clear();
      minute = 0;
      homeGoals = awayGoals = 0;
      ballX = 0.5;
      ballY = 0.5;
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

  bool get _isCup => (fixture?['par_vuelta'] as int? ?? 0) == 1;

  String _cupPhaseLabel() {
    final fase = fixture?['par_fase'] as int? ?? 1;
    switch (fase) {
      case 1:
        return 'PIALA DOMESTIK · 16 BESAR';
      case 2:
        return 'PIALA DOMESTIK · PEREMPAT FINAL';
      case 3:
        return 'PIALA DOMESTIK · SEMIFINAL';
      default:
        return 'FINAL PIALA DOMESTIK';
    }
  }

  Future<void> _startMatch() async {
    if (fixture == null || playing) return;
    timer?.cancel();
    setState(() {
      playing = true;
      paused = false;
      halfTimeShown = false;
      committed = false;
      visible.clear();
      minute = 0;
      homeGoals = awayGoals = 0;
      ballX = 0.5;
      ballY = 0.5;
      result = null;
    });
    if (!fast) {
      SoundService.instance.playKickoff();
      SoundService.instance.startAmbience();
    }
    try {
      final s = await widget.service.startLiveUserMatch(
        fixture!['partid'] as int,
        needWinner: _isCup,
      );
      if (!mounted) return;
      session = s;

      if (fast) {
        while (!s.isFinished) {
          s.stepMinute();
        }
        final res = s.finalize();
        await widget.service.commitUserMatchResult(
          fixture!['partid'] as int,
          res,
        );
        if (!mounted) return;
        SoundService.instance.playFulltime();
        setState(() {
          result = res;
          committed = true;
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
        });
        return;
      }

      setState(() {
        visible.insert(
          0,
          MatchEvent(
            0,
            'inicio',
            null,
            null,
            'Kick-off! ${home?.nombre ?? ""} vs ${away?.nombre ?? ""} dimulai.',
          ),
        );
      });
      _tick();
    } catch (_) {
      SoundService.instance.stopAmbience();
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

  void _updateBallFor(LiveMatchSession s, List<MatchEvent> stepEvents) {
    if (stepEvents.isNotEmpty) {
      final last = stepEvents.last;
      if (last.type == 'gol' || last.type == 'atajada' || last.type == 'palo') {
        ballX = last.team == 0 ? 0.90 : 0.10;
        ballY = 0.50;
        return;
      }
      if (last.type == 'penalti_keputusan' || last.type == 'penalti_gol') {
        ballX = last.team == 1 ? 0.88 : 0.12;
        ballY = 0.50;
        return;
      }
    }
    ballX = (0.20 + s.momentumRatio * 0.60).clamp(0.12, 0.88);
    ballY = 0.30 + ((s.minute * 17) % 40) / 100.0;
  }

  void _tick() {
    timer?.cancel();
    if (paused || session == null) return;
    final delayMs = (650 / speedMultiplier).round().clamp(40, 1000);
    timer = Timer(Duration(milliseconds: delayMs), () async {
      if (!mounted || session == null || paused) return;
      final s = session!;
      final stepEvents = s.stepMinute();
      MatchEvent? soundEvent;
      var finishedNow = false;

      setState(() {
        minute = s.minute.clamp(0, 90);
        homeGoals = s.homeGoals;
        awayGoals = s.awayGoals;
        _updateBallFor(s, stepEvents);

        if (s.minute == 45 && !halfTimeShown) {
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

        for (final e in stepEvents) {
          visible.insert(0, e);
          soundEvent = e;
        }

        if (s.isFinished) {
          final res = s.finalize();
          result = res;
          minute = 90;
          homeGoals = res.homeGoals;
          awayGoals = res.awayGoals;
          playing = false;
          finishedNow = true;
          // tambahkan event adu penalti bila baru dihasilkan di finalize()
          for (final e in res.events) {
            if (e.minute >= s.totalMinutes &&
                !visible.any((v) => v.text == e.text && v.minute == e.minute)) {
              visible.insert(0, e);
            }
          }
          visible.insert(
            0,
            MatchEvent(
              90,
              'final',
              null,
              null,
              'Peluit panjang berbunyi! Skor akhir ${res.homeGoals}-${res.awayGoals}.',
            ),
          );
        }
      });

      if (finishedNow && result != null && !committed) {
        committed = true;
        timer?.cancel();
        SoundService.instance.stopAmbience();
        SoundService.instance.playFulltime();
        await widget.service.commitUserMatchResult(
          fixture!['partid'] as int,
          result!,
        );
        return;
      }

      if (soundEvent != null) {
        _playSfxForEvent(soundEvent!);
      }
      if (!s.isFinished) _tick();
    });
  }

  void _togglePause() {
    if (session == null || !playing) return;
    setState(() {
      paused = !paused;
    });
    if (!paused) {
      SoundService.instance.startAmbience();
      _tick();
    } else {
      timer?.cancel();
      SoundService.instance.stopAmbience();
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
            tooltip:
                SoundService.instance.enabled ? 'Matikan suara' : 'Nyalakan suara',
            onPressed: () {
              setState(() {
                SoundService.instance.enabled = !SoundService.instance.enabled;
              });
              if (!SoundService.instance.enabled) {
                SoundService.instance.stopAll();
              } else {
                SoundService.instance.playTap();
                if (playing && !paused) SoundService.instance.startAmbience();
              }
            },
            icon: Icon(
              SoundService.instance.enabled
                  ? Icons.volume_up_outlined
                  : Icons.volume_off_outlined,
              size: 20,
            ),
          ),
          if (playing && session != null)
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
              text:
                  'Belum ada laga tersisa musim ini.\nTutup musim di tab Klub untuk lanjut ke musim baru.')
          : Column(
              children: [
                _scoreboard(),
                if (session == null && result == null)
                  _preMatch()
                else
                  _liveFeed(),
              ],
            ),
    );
  }

  Widget _scoreboard() {
    final isHomeUser = home?.equid == userTeam!.equid;
    final s = session;
    final done = result != null;
    final shotsH = result?.homeShots ?? s?.homeShots ?? 0;
    final shotsA = result?.awayShots ?? s?.awayShots ?? 0;
    final onH = result?.homeOnTarget ?? s?.homeOnTarget ?? 0;
    final onA = result?.awayOnTarget ?? s?.awayOnTarget ?? 0;
    final possH = result?.homePossession ?? s?.currentPossessionHome ?? 50;
    final possA = 100 - possH;

    return Container(
      margin: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
            colors: _isCup
                ? const [Color(0xFF3E2D0C), Color(0xFF1A170D)]
                : const [Color(0xFF0E3B27), Color(0xFF102019)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
            color: _isCup ? AppColors.gold.withOpacity(0.5) : AppColors.line),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_isCup)
                const Padding(
                  padding: EdgeInsets.only(right: 5),
                  child: Icon(Icons.emoji_events, size: 13, color: AppColors.gold),
                ),
              Text(
                  session == null && result == null
                      ? (_isCup
                          ? _cupPhaseLabel()
                          : 'PEKAN ${fixture!['par_jornada']}')
                      : done
                          ? 'PERTANDINGAN SELESAI'
                          : paused
                              ? "DIJEDA · $minute'"
                              : "LIVE · $minute'",
                  style: TextStyle(
                      fontSize: 11,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w800,
                      color: done
                          ? AppColors.muted
                          : paused
                              ? AppColors.accent
                              : _isCup && session == null
                                  ? AppColors.gold
                                  : AppColors.primary)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _teamSide(home, isHomeUser)),
              Column(
                children: [
                  Text('$homeGoals - $awayGoals',
                      style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 2)),
                  if (result?.penHome != null)
                    Text('pen ${result!.penHome}-${result!.penAway}',
                        style: const TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: AppColors.gold)),
                ],
              ),
              Expanded(child: _teamSide(away, !isHomeUser)),
            ],
          ),
          if (s != null || result != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(child: _miniStat('$shotsH-$shotsA', 'Tembakan')),
                Expanded(child: _miniStat('$onH-$onA', 'On target')),
                Expanded(child: _miniStat('$possH%-$possA%', 'Bola')),
              ],
            ),
            if (!done && s != null) ...[
              const SizedBox(height: 10),
              // Mini 2D radar + momentum
              SizedBox(
                height: 52,
                width: double.infinity,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: CustomPaint(
                    painter: _MiniPitchPainter(
                      ballX: ballX,
                      ballY: ballY,
                      homeColor: _parseColor(home?.colorA ?? '#00C853'),
                      awayColor: _parseColor(away?.colorA ?? '#E53935'),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Text(home?.abrev ?? 'HOM',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: s.momentumRatio,
                        minHeight: 5,
                        backgroundColor: Colors.redAccent.withOpacity(0.45),
                        valueColor:
                            const AlwaysStoppedAnimation(AppColors.primary),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(away?.abrev ?? 'AWY',
                      style: const TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted)),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Color _parseColor(String hex) {
    try {
      return Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  Widget _teamSide(Team? t, bool isUser) {
    if (t == null) return const SizedBox();
    return Column(
      children: [
        CrestWidget(
          nombre: t.nombre,
          colorA: t.colorA,
          colorB: t.colorB,
          size: 44,
        ),
        const SizedBox(height: 6),
        Text(t.nombre,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12.5,
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
                    Text(
                        _isCup
                            ? 'Laga Sistem Gugur (Adu Penalti bila seri)'
                            : 'Rencana pertandingan',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13)),
                    const SizedBox(height: 8),
                    const Text(
                        'Saat laga berlangsung, kamu bisa mengganti pemain '
                        '(maks 5) dan mengubah taktik secara langsung.',
                        style: TextStyle(fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => Navigator.push(
                              context,
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
    final done = result != null;
    final s = session;
    return Expanded(
      child: Column(
        children: [
          if (!done && s != null && s.userSetup != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: s.userSubsUsed >= LiveMatchSession.maxSubs
                          ? null
                          : _openLiveSubs,
                      icon: const Icon(Icons.swap_vert, size: 16),
                      label: Text(
                          'Ganti (${s.userSubsUsed}/${LiveMatchSession.maxSubs})',
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _openLiveTactics,
                      icon: const Icon(Icons.tune, size: 16),
                      label: Text(
                          'Taktik (${s.userSetup!.tactics.mentalidad})',
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 8)),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
              itemCount: visible.length + 1,
              itemBuilder: (context, i) {
                if (i == visible.length) {
                  if (!done) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      child: Center(
                          child: paused
                              ? TextButton.icon(
                                  onPressed: _togglePause,
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Lanjutkan laga'),
                                )
                              : const SizedBox(
                                  height: 18,
                                  width: 18,
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

  Future<void> _openLiveSubs() async {
    final s = session;
    final u = s?.userSetup;
    if (s == null || u == null) return;
    final wasPaused = paused;
    if (!wasPaused) _togglePause();

    Player? selectedOut;
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.78,
          builder: (_, ctrl) => ListView(
            controller: ctrl,
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                  'Pergantian Pemain (${s.userSubsUsed}/${LiveMatchSession.maxSubs})',
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(
                  selectedOut == null
                      ? '1. Pilih pemain di lapangan yang ingin ditarik keluar'
                      : '2. Pilih pemain cadangan pengganti ${selectedOut!.nombre}',
                  style: const TextStyle(fontSize: 11.5, color: AppColors.accent)),
              const SizedBox(height: 10),
              if (selectedOut == null)
                ...u.xi.map((p) {
                  final stam = (s.stamina[p.jugid] ?? 100).round();
                  final yc = s.stats[p.jugid]?.amarillas ?? 0;
                  return ListTile(
                    dense: true,
                    leading: CircleAvatar(
                      radius: 15,
                      backgroundColor:
                          Squads.positionColor(p.posid).withOpacity(0.18),
                      child: Text(Squads.positionName(p.posid),
                          style: TextStyle(
                              fontSize: 9,
                              fontWeight: FontWeight.w800,
                              color: Squads.positionColor(p.posid))),
                    ),
                    title: Row(
                      children: [
                        Flexible(
                            child: Text(p.nombre,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13))),
                        if (yc > 0)
                          const Padding(
                            padding: EdgeInsets.only(left: 5),
                            child: Icon(Icons.square,
                                size: 11, color: Colors.yellow),
                          ),
                      ],
                    ),
                    subtitle: Text('Stamina $stam% · OVR ${p.poder}',
                        style: TextStyle(
                            fontSize: 11,
                            color: stam < 60
                                ? AppColors.danger
                                : AppColors.muted)),
                    trailing: const Text('Keluar',
                        style: TextStyle(
                            fontSize: 11, color: AppColors.primary)),
                    onTap: () => setSheet(() => selectedOut = p),
                  );
                })
              else ...[
                TextButton.icon(
                  onPressed: () => setSheet(() => selectedOut = null),
                  icon: const Icon(Icons.arrow_back, size: 16),
                  label: const Text('Pilih pemain lain'),
                ),
                ...u.bench.map((b) => ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor:
                            Squads.positionColor(b.posid).withOpacity(0.18),
                        child: Text(Squads.positionName(b.posid),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Squads.positionColor(b.posid))),
                      ),
                      title: Text(b.nombre,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('OVR ${b.poder} · Kondisi ${b.condicion}%',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                      trailing: FilledButton(
                        onPressed: () {
                          final ev = s.substituteUser(
                              selectedOut!.jugid, b.jugid);
                          if (ev != null) {
                            setState(() {
                              visible.insert(0, ev);
                            });
                            SoundService.instance.playTap();
                          }
                          Navigator.pop(ctx);
                        },
                        child: const Text('Masuk'),
                      ),
                    )),
              ],
            ],
          ),
        ),
      ),
    );
    if (!wasPaused && mounted && paused && !s.isFinished) _togglePause();
  }

  Future<void> _openLiveTactics() async {
    final s = session;
    final u = s?.userSetup;
    if (s == null || u == null) return;
    final wasPaused = paused;
    if (!wasPaused) _togglePause();

    var tac = u.tactics.copy();
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Instruksi Taktik Live',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              const Text('Mentalitas',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: Mentality.all
                    .map((m) => ChoiceChip(
                          label: Text(m),
                          selected: tac.mentalidad == m,
                          onSelected: (_) =>
                              setSheet(() => tac.mentalidad = m),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 12),
              const Text('Pressing',
                  style: TextStyle(fontSize: 11, color: AppColors.muted)),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: Pressure.all
                    .map((p) => ChoiceChip(
                          label: Text(p),
                          selected: tac.presion == p,
                          onSelected: (_) => setSheet(() => tac.presion = p),
                        ))
                    .toList(),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  s.updateUserTactics(tac);
                  setState(() {
                    visible.insert(
                      0,
                      MatchEvent(
                        minute,
                        'inicio',
                        s.userSide,
                        null,
                        'Instruksi baru: ${tac.mentalidad}, pressing ${tac.presion}.',
                      ),
                    );
                  });
                  SoundService.instance.playTap();
                  Navigator.pop(ctx);
                },
                style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(46)),
                child: const Text('TERAPKAN TAKTIK'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!wasPaused && mounted && paused && !s.isFinished) _togglePause();
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
      case 'cambio':
        icon = Icons.swap_horiz;
        color = const Color(0xFF81C784);
        break;
      case 'inicio':
      case 'final':
        icon = Icons.sports;
        color = AppColors.primary;
        break;
      default:
        icon = Icons.info_outline;
    }
    final isHighlight = e.type == 'gol' ||
        e.type == 'penalti_gol' ||
        e.type == 'final' ||
        e.type == 'roja';
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

class _MiniPitchPainter extends CustomPainter {
  final double ballX;
  final double ballY;
  final Color homeColor;
  final Color awayColor;
  _MiniPitchPainter({
    required this.ballX,
    required this.ballY,
    required this.homeColor,
    required this.awayColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final bg = Paint()..color = const Color(0xFF113825);
    canvas.drawRect(Offset.zero & size, bg);
    final line = Paint()
      ..color = Colors.white.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRect(Rect.fromLTWH(2, 2, size.width - 4, size.height - 4), line);
    canvas.drawLine(
        Offset(size.width / 2, 2), Offset(size.width / 2, size.height - 2), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 10, line);
    canvas.drawRect(Rect.fromLTWH(2, size.height * 0.22, 16, size.height * 0.56), line);
    canvas.drawRect(
        Rect.fromLTWH(size.width - 18, size.height * 0.22, 16, size.height * 0.56),
        line);

    // 22 titik formasi sederhana
    final shift = (ballX - 0.5) * 0.14;
    final hPaint = Paint()..color = homeColor;
    final aPaint = Paint()..color = awayColor;
    const hPts = [
      [0.06, 0.5],
      [0.20, 0.2], [0.18, 0.4], [0.18, 0.6], [0.20, 0.8],
      [0.36, 0.25], [0.34, 0.5], [0.36, 0.75],
      [0.52, 0.25], [0.54, 0.5], [0.52, 0.75],
    ];
    for (var i = 0; i < hPts.length; i++) {
      final px = ((hPts[i][0] + (i == 0 ? 0 : shift)).clamp(0.05, 0.92)) * size.width;
      final py = hPts[i][1] * size.height;
      canvas.drawCircle(Offset(px, py), 2.5, hPaint);

      final ax = ((1.0 - hPts[i][0] + (i == 0 ? 0 : shift)).clamp(0.08, 0.95)) * size.width;
      final ay = (1.0 - hPts[i][1]) * size.height;
      canvas.drawCircle(Offset(ax, ay), 2.5, aPaint);
    }

    // Bola
    final bx = ballX * size.width;
    final by = ballY * size.height;
    canvas.drawCircle(Offset(bx, by), 4.5, Paint()..color = Colors.black45);
    canvas.drawCircle(Offset(bx, by), 3.6, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _MiniPitchPainter old) =>
      old.ballX != ballX || old.ballY != ballY;
}
