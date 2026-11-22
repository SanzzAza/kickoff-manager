import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

class TableScreen extends StatefulWidget {
  final GameService service;
  const TableScreen({super.key, required this.service});
  @override
  State<TableScreen> createState() => _TableScreenState();
}

class _TableScreenState extends State<TableScreen> with SingleTickerProviderStateMixin {
  late TabController tab;
  List<StandingsRow>? table;
  List<Map<String, dynamic>> scorers = [];
  Team? userTeam;
  int userEquid = 0;

  @override
  void initState() {
    super.initState();
    tab = TabController(length: 3, vsync: this);
    _load();
  }

  Future<void> _load() async {
    final st = await widget.service.state();
    final t = await widget.service.standings();
    final top = await widget.service.world.topScorers(st.i('tempid'), limit: 15);
    final goals = await widget.service.world.scorerGoals(st.i('tempid'));
    final ut = await widget.service.userTeam();
    if (!mounted) return;
    setState(() {
      table = t;
      userEquid = ut.equid;
      userTeam = ut;
      scorers = top
          .map((p) => {
                'player': p,
                'goals': goals[p.jugid] ?? 0,
              })
          .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Klasemen'),
        bottom: TabBar(
          controller: tab,
          indicatorColor: AppColors.primary,
          labelColor: AppColors.text,
          unselectedLabelColor: AppColors.muted,
          tabs: const [
            Tab(text: 'Tabel'),
            Tab(text: 'Pencetak Gol'),
            Tab(text: 'Jadwal'),
          ],
        ),
      ),
      body: table == null
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: tab,
              children: [_tableView(), _scorersView(), _fixturesView()],
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
                    width: 26, child: Text('PJ', style: _hStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 26, child: Text('SG', style: _hStyle, textAlign: TextAlign.center)),
                SizedBox(
                    width: 30, child: Text('PTS', style: _hStyle, textAlign: TextAlign.center)),
              ],
            ),
          ),
          ...t.asMap().entries.map((e) {
            final r = e.value;
            final isUser = r.equid == userEquid;
            return Container(
              color: isUser ? AppColors.primaryDark.withOpacity(0.22) : null,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
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
                          child: CrestWidget(nombre: r.nombre, size: 22))),
                  Expanded(
                    child: Text(r.nombre,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: isUser ? FontWeight.w800 : FontWeight.w500)),
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
            );
          }),
          Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: const [
                _Legend(color: AppColors.primary, text: 'Zona juara'),
                SizedBox(width: 14),
                _Legend(color: AppColors.danger, text: 'Degradasi'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scorersView() {
    if (scorers.isEmpty) {
      return const EmptyState(
          icon: Icons.sports_soccer, text: 'Belum ada gol musim ini.');
    }
    return ListView.separated(
      itemCount: scorers.length,
      separatorBuilder: (_, __) => const Divider(height: 1, indent: 16, endIndent: 16),
      itemBuilder: (context, i) {
        final p = scorers[i]['player'] as Player;
        return ListTile(
          leading: CircleAvatar(
            radius: 16,
            backgroundColor: AppColors.surface2,
            child: Text('${i + 1}',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800)),
          ),
          title: Text(p.nombre, style: const TextStyle(fontSize: 13.5)),
          subtitle: Text('${Squads.positionName(p.posid)} · ${p.edad} th',
              style: const TextStyle(fontSize: 11, color: AppColors.muted)),
          trailing: Text('${scorers[i]['goals']}',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
        );
      },
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
            final played = (f['par_status'] as int? ?? 0) == 1;
            return FutureBuilder(
              future: widget.service.world
                  .team((isHome ? f['par_equid_visita'] : f['par_equid_local']) as int),
              builder: (context, s) {
                final rival = s.data;
                return ListTile(
                  dense: true,
                  leading: SizedBox(
                      width: 34,
                      child: Text('J${f['par_jornada']}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted))),
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
}

const _hStyle = TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: AppColors.muted);

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
        Text(text, style: const TextStyle(fontSize: 10.5, color: AppColors.muted)),
      ],
    );
  }
}
