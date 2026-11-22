import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'squad_screen.dart';

class MarketScreen extends StatefulWidget {
  final GameService service;
  final ValueListenable<int>? refreshSignal;
  const MarketScreen({super.key, required this.service, this.refreshSignal});
  @override
  State<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends State<MarketScreen> {
  List<Map<String, dynamic>> players = [];
  Map<String, dynamic>? history = {};
  bool loading = true;
  final search = TextEditingController();
  int? role;
  int minPoder = 55;
  int budget = 0;

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onSignal);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onSignal);
    search.dispose();
    super.dispose();
  }

  void _onSignal() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    setState(() => loading = true);
    final list = await widget.service.marketPlayers(
        search: search.text, minPoder: minPoder, posRole: role, limit: 80);
    final team = await widget.service.userTeam();
    final tr = await widget.service.world.transfers(limit: 25);
    if (!mounted) return;
    setState(() {
      players = list;
      budget = team.presupuesto;
      history = {'transfers': tr};
      loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pasar Transfer'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 14),
            child: Center(
              child: Text('Kas ${formatMoney(budget)}',
                  style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AppColors.primary)),
            ),
          )
        ],
      ),
      body: Column(
        children: [
          Container(
            color: AppColors.surface,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: search,
                        onSubmitted: (_) => _load(),
                        decoration: const InputDecoration(
                          hintText: 'Cari pemain...',
                          prefixIcon: Icon(Icons.search, size: 18),
                          isDense: true,
                          contentPadding:
                              EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                        onPressed: () => _showHistory(),
                        icon: const Icon(Icons.history, size: 20)),
                  ],
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final r in const [
                      [null, 'Semua'],
                      [1, 'Kiper'],
                      [2, 'Bertahan'],
                      [3, 'Tengah'],
                      [4, 'Depan'],
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(r[1] as String),
                          selected: role == r[0],
                          onSelected: (_) {
                            setState(() => role = r[0] as int?);
                            _load();
                          },
                        ),
                      ),
                  ],
                )),
                Row(
                  children: [
                    const Text('Min. rating',
                        style: TextStyle(fontSize: 11, color: AppColors.muted)),
                    Expanded(
                      child: Slider(
                        value: minPoder.toDouble(),
                        min: 40,
                        max: 90,
                        divisions: 10,
                        activeColor: AppColors.primary,
                        label: '$minPoder',
                        onChanged: (v) => setState(() => minPoder = v.round()),
                        onChangeEnd: (_) => _load(),
                      ),
                    ),
                    Text('$minPoder',
                        style: const TextStyle(
                            fontSize: 12, fontWeight: FontWeight.w800)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : players.isEmpty
                    ? const EmptyState(
                        icon: Icons.search_off, text: 'Tidak ada pemain cocok.')
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 20),
                        itemCount: players.length,
                        itemBuilder: (context, i) {
                          final row = players[i];
                          final p = widget.service.world.playerFromRow(row);
                          return InkWell(
                            onTap: () async {
                              await showModalBottomSheet(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: AppColors.surface,
                                shape: const RoundedRectangleBorder(
                                    borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20))),
                                builder: (_) => PlayerDetailSheet(
                                    player: p,
                                    service: widget.service,
                                    isOwn: false),
                              );
                              _load();
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 9),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 16,
                                    backgroundColor:
                                        Squads.positionColor(p.posid)
                                            .withOpacity(0.18),
                                    child: Text(Squads.positionName(p.posid),
                                        style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.w900,
                                            color:
                                                Squads.positionColor(p.posid))),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                            '${p.nombre}${p.star == 1 ? " ⭐" : ""}',
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                                fontSize: 13.5,
                                                fontWeight: FontWeight.w600)),
                                        Text(
                                            '${row['club_nombre']} · ${p.edad} th · ${formatMoney(p.valor)}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.muted)),
                                      ],
                                    ),
                                  ),
                                  PowerBadge(p.poder),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _showHistory() {
    final tr = (history?['transfers'] ?? []) as List<dynamic>;
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
            const Text('Riwayat transfer terakhir',
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 10),
            SizedBox(
              height: 320,
              child: tr.isEmpty
                  ? const EmptyState(
                      icon: Icons.swap_horiz, text: 'Belum ada transfer.')
                  : ListView(
                      children: tr
                          .map((t) => Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                        t['tra_tipo_transferencia'] == 'compra'
                                            ? Icons.south_west
                                            : Icons.north_east,
                                        size: 14,
                                        color: t['tra_tipo_transferencia'] ==
                                                'compra'
                                            ? AppColors.primary
                                            : AppColors.danger),
                                    const SizedBox(width: 8),
                                    Expanded(
                                        child: Text(t['tra_nombre'] ?? '-',
                                            style:
                                                const TextStyle(fontSize: 12))),
                                    Text(formatMoney((t['tra_valor'] ?? 0) as int),
                                        style: const TextStyle(
                                            fontSize: 11,
                                            color: AppColors.muted)),
                                  ],
                                ),
                              ))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
