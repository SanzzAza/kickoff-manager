import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

class TableScreen extends StatefulWidget {
  final GameService service;
  final ValueListenable<int>? refreshSignal;
  const TableScreen({super.key, required this.service, this.refreshSignal});
  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen>
    with SingleTickerProviderStateMixin {
  late TabController tab;
  List<StandingsRow>? table;
  List<Map<String, dynamic>> scorers = [];
  List<Map<String, dynamic>> assisters = [];
  List<Map<String, dynamic>> cupMatches = [];
  List<Map<String, dynamic>> contiMatches = [];
  Map<int, Team> teamCache = {};
  Team? userTeam;
  int userEquid = 0;

  @override
  void initState() {
    super.initState();
    tab = TabController(length: 5, vsync: this);
    widget.refreshSignal?.addListener(_onSignal);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onSignal);
    tab.dispose();
    super.dispose();
  }

  void _onSignal() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final st = await widget.service.state();
    final tempid = st.i('tempid');
    final t = await widget.service.standings();
    final top = await widget.service.world.topScorers(tempid, limit: 15);
    final goals = await widget.service.world.scorerGoals(tempid);
    final topA = await widget.service.world.topAssisters(tempid, limit: 15);
    final assists = await widget.service.world.assisterCounts(tempid);
    final cup = await widget.service.world.cupFixtures(tempid, vuelta: 1);
    final conti = await widget.service.world.cupFixtures(tempid, vuelta: 2);
    final ut = await widget.service.userTeam();

    final ids = <int>{
      for (final m in [...cup, ...conti]) ...[
        m['par_equid_local'] as int,
        m['par_equid_visita'] as int,
      ],
    };
    final cache = <int, Team>{};
    for (final id in ids) {
      final team = await widget.service.world.team(id);
      if (team != null) cache[id] = team;
    }

    if (!mounted) return;
    setState(() {
      table = t;
      userEquid = ut.equid;
      userTeam = ut;
      teamCache = cache;
      cupMatches = cup;
      contiMatches = conti;
      scorers = top
          .map((p) => {'player': p, 'goals': goals[p.jugid] ?? 0})
          .toList();
      assisters = topA
          .map((p) => {'player': p, 'assists': assists[p.jugid] ?? 0})
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kompetisi'),
        bottom: TabBar(
          controller: tab,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.text,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(text: 'Tabel'),
            Tab(text: 'Piala'),
            Tab(text: 'Kontinental'),
            Tab(text: 'Statistik'),
            Tab(text: 'Jadwal'),
          ],
        ),
      ),
      body: table == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: tab,
              children: [
                _tableView(),
                _bracketView(cupMatches, 'Piala Domestik', AppColors.gold),
                _bracketView(
                    contiMatches,
                    'Piala Kontinental\n(Finis 4 besar liga untuk lolos di musim berikutnya)',
                    const Color(0xFF4FC3F7)),
                _statsView(),
                _fixturesView(),
              ],
            ),
    );
  }

  Widget _tableView() {
    final t = table!;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            color: AppColors.surface,
            child: Row(
              children: const [
                SizedBox(width: 22, child: Text('#', style: _hStyle)),
                SizedBox(width: 34),
                Expanded(child: Text('Klub', style: _hStyle)),
                SizedBox(
                    width: 26,
                    child: Text('PJ', style: _hStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 26,
                    child: Text('SG', style: _hStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 30,
                    child:
                        Text('PTS', style: _hStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...t.asMap().entries.map((e) {
            final r = e.value;
            final isUser = r.equid == userEquid;
            return InkWell(
              onTap: () => _showClubSheet(r),
              child: Container(
                color: isUser ? AppColors.primaryDark.withOpacity(0.22) : null,
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                child: Row(
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text('${e.key + 1}',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                              color: e.key < 4
                                  ? AppColors.primary
                                  : e.key > t.length - 4
                                      ? AppColors.danger
                                      : AppColors.muted)),
                    ),
                    SizedBox(
                        width: 34,
                        child: Center(
                            child: CrestWidget(
                                nombre: r.nombre,
                                colorA: r.colorA,
                                colorB: r.colorB,
                                size: 22))),
                    Expanded(
                      child: Text(r.nombre,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 12.5,
                              fontWeight:
                                  isUser ? FontWeight.w800 : FontWeight.w500)),
                    ),
                    SizedBox(
                        width: 26,
                        child: Text('${r.pj}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12))),
                    SizedBox(
                        width: 26,
                        child: Text(r.dg > 0 ? '+${r.dg}' : '${r.dg}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(fontSize: 12))),
                    SizedBox(
                        width: 30,
                        child: Text('${r.pts}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                fontSize: 13, fontWeight: FontWeight.w800))),
                  ],
                ),
              ),
            );
          }),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: const [
                _Legend(color: AppColors.primary, text: 'Zona Kontinental'),
                SizedBox(width: 14),
                _Legend(color: AppColors.danger, text: 'Degradasi'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _bracketView(
      List<Map<String, dynamic>> matches, String emptyTitle, Color accent) {
    if (matches.isEmpty) {
      return EmptyState(
          icon: Icons.emoji_events_outlined,
          text: 'Belum ada jadwal $emptyTitle musim ini.');
    }
    final byFase = <int, List<Map<String, dynamic>>>{};
    for (final m in matches) {
      final f = (m['par_fase'] as int?) ?? 1;
      byFase.putIfAbsent(f, () => []).add(m);
    }
    final fases = byFase.keys.toList()..sort((a, b) => b.compareTo(a));
    String phaseName(int f) {
      switch (f) {
        case 4:
          return 'FINAL';
        case 3:
          return 'SEMIFINAL';
        case 2:
          return 'PEREMPAT FINAL';
        default:
          return '16 BESAR';
      }
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 24),
        children: [
          for (final f in fases) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.emoji_events, size: 15, color: accent),
                  const SizedBox(width: 6),
                  Text(phaseName(f),
                      style: TextStyle(
                          fontSize: 12,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w900,
                          color: accent)),
                ],
              ),
            ),
            ...byFase[f]!.map((m) {
              final h = teamCache[m['par_equid_local'] as int];
              final a = teamCache[m['par_equid_visita'] as int];
              final played = (m['par_status'] as int? ?? 0) == 1;
              final hg = m['par_goles_local'] as int? ?? 0;
              final ag = m['par_goles_visita'] as int? ?? 0;
              final ph = m['par_penal_goles_local'] as int?;
              final pa = m['par_penal_goles_visita'] as int?;
              final isUser = m['par_equid_local'] == userEquid ||
                  m['par_equid_visita'] == userEquid;
              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                      color: isUser
                          ? accent.withOpacity(0.6)
                          : AppColors.line),
                ),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(
                    children: [
                      if (h != null)
                        CrestWidget(
                            nombre: h.nombre, colorA: h.colorA, size: 22),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(h?.nombre ?? 'Klub',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: m['par_equid_local'] == userEquid
                                    ? FontWeight.w900
                                    : FontWeight.w600)),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Column(
                          children: [
                            Text(played ? '$hg - $ag' : 'J${m['par_jornada']}',
                                style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w900,
                                    color: played
                                        ? AppColors.text
                                        : AppColors.muted)),
                            if (played && ph != null && pa != null)
                              Text('($ph-$pa)',
                                  style: TextStyle(
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w700,
                                      color: accent)),
                          ],
                        ),
                      ),
                      Expanded(
                        child: Text(a?.nombre ?? 'Klub',
                            textAlign: TextAlign.end,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: m['par_equid_visita'] == userEquid
                                    ? FontWeight.w900
                                    : FontWeight.w600)),
                      ),
                      const SizedBox(width: 6),
                      if (a != null)
                        CrestWidget(
                            nombre: a.nombre, colorA: a.colorA, size: 22),
                    ],
                  ),
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  Widget _statsView() {
    if (scorers.isEmpty && assisters.isEmpty) {
      return const EmptyState(
          icon: Icons.sports_soccer, text: 'Belum ada gol atau assist musim ini.');
    }
    return ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const SectionTitle('Top Skor'),
        if (scorers.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Text('Belum ada gol.', style: TextStyle(color: AppColors.muted)),
          )
        else
          ...scorers.take(10).toList().asMap().entries.map((e) {
            final p = e.value['player'] as Player;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surface2,
                child: Text('${e.key + 1}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              title: Text(p.nombre, style: const TextStyle(fontSize: 13.5)),
              subtitle: Text('${Squads.positionName(p.posid)} · ${p.edad} th',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              trailing: Text('${e.value['goals']}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.primary)),
            );
          }),
        const SectionTitle('Top Assist'),
        if (assisters.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child:
                Text('Belum ada assist.', style: TextStyle(color: AppColors.muted)),
          )
        else
          ...assisters.take(10).toList().asMap().entries.map((e) {
            final p = e.value['player'] as Player;
            return ListTile(
              dense: true,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: AppColors.surface2,
                child: Text('${e.key + 1}',
                    style: const TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              title: Text(p.nombre, style: const TextStyle(fontSize: 13.5)),
              subtitle: Text('${Squads.positionName(p.posid)} · ${p.edad} th',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              trailing: Text('${e.value['assists']}',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent)),
            );
          }),
      ],
    );
  }

  Widget _fixturesView() {
    return FutureBuilder(
      future: widget.service.userFixtures(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final list = snap.data!;
        return ListView.builder(
          padding: const EdgeInsets.only(bottom: 20),
          itemCount: list.length,
          itemBuilder: (context, i) {
            final f = list[i];
            final isHome = f['par_equid_local'] == userEquid;
            final vuelta = f['par_vuelta'] as int? ?? 0;
            final isCup = vuelta == 1;
            final isConti = vuelta == 2;
            final played = (f['par_status'] as int? ?? 0) == 1;
            return FutureBuilder(
              future: widget.service.world.team(
                  (isHome ? f['par_equid_visita'] : f['par_equid_local']) as int),
              builder: (context, s) {
                final rival = s.data;
                return ListTile(
                  dense: true,
                  leading: SizedBox(
                      width: 42,
                      child: Text(
                          isConti
                              ? 'KONTI'
                              : isCup
                                  ? 'PIALA'
                                  : 'J${f['par_jornada']}',
                          style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: (isCup || isConti)
                                  ? FontWeight.w800
                                  : FontWeight.w500,
                              color: isConti
                                  ? const Color(0xFF4FC3F7)
                                  : isCup
                                      ? AppColors.gold
                                      : AppColors.muted))),
                  title: Text(
                      rival == null
                          ? '...'
                          : '${isHome ? "vs" : "@"} ${rival.nombre}',
                      style: const TextStyle(fontSize: 13)),
                  trailing: played
                      ? Text(
                          '${f['par_goles_local']} - ${f['par_goles_visita']}',
                          style: const TextStyle(
                              fontWeight: FontWeight.w800, fontSize: 13))
                      : const Text('-',
                          style: TextStyle(color: AppColors.muted)),
                );
              },
            );
          },
        );
      },
    );
  }

  Future<void> _showClubSheet(StandingsRow r) async {
    final t = await widget.service.world.team(r.equid);
    final squad = await widget.service.world.squad(r.equid);
    squad.sort((a, b) => b.poder - a.poder);
    final top = squad.take(6).toList();
    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CrestWidget(
                    nombre: r.nombre,
                    colorA: r.colorA,
                    colorB: r.colorB,
                    size: 44),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(r.nombre,
                          style: const TextStyle(
                              fontSize: 17, fontWeight: FontWeight.w900)),
                      Text(
                          'Poin ${r.pts} · ${r.pg}M ${r.pe}S ${r.pp}K · SG ${r.dg > 0 ? "+${r.dg}" : r.dg}',
                          style: const TextStyle(
                              fontSize: 11.5, color: AppColors.muted)),
                    ],
                  ),
                ),
                if (t != null) PowerBadge(t.poder),
              ],
            ),
            const SizedBox(height: 12),
            const Text('Pemain Kunci',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: AppColors.muted)),
            const SizedBox(height: 6),
            ...top.map((p) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 32,
                        child: Text(Squads.positionName(p.posid),
                            style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Squads.positionColor(p.posid))),
                      ),
                      Expanded(
                          child: Text(p.nombre,
                              style: const TextStyle(fontSize: 13))),
                      Text('${p.edad} th',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                      const SizedBox(width: 10),
                      PowerBadge(p.poder),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

const _hStyle =
    TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted);

class _Legend extends StatelessWidget {
  final Color color;
  final String text;
  const _Legend({required this.color, required this.text});
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 5),
        Text(text,
            style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
      ],
    );
  }
}
