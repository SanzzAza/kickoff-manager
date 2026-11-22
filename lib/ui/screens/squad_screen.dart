import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

class SquadScreen extends StatefulWidget {
  final GameService service;
  final ValueListenable<int>? refreshSignal;
  const SquadScreen({super.key, required this.service, this.refreshSignal});
  @override
  State<SquadScreen> createState() => _SquadScreenState();
}

class _SquadScreenState extends State<SquadScreen> {
  List<Player>? squad;
  Team? team;
  int filterRole = 0; // 0 semua, 1 POR, 2 DEF, 3 MED, 4 DEL

  @override
  void initState() {
    super.initState();
    widget.refreshSignal?.addListener(_onSignal);
    _load();
  }

  @override
  void dispose() {
    widget.refreshSignal?.removeListener(_onSignal);
    super.dispose();
  }

  void _onSignal() {
    if (mounted) _load();
  }

  Future<void> _load() async {
    final t = await widget.service.userTeam();
    final s = await widget.service.world.squad(t.equid);
    if (!mounted) return;
    setState(() {
      team = t;
      squad = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (squad == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final list = squad!.where((p) {
      if (filterRole == 0) return true;
      if (filterRole == 1) return p.posid == 1;
      if (filterRole == 2) return p.posid >= 2 && p.posid <= 4;
      if (filterRole == 3) return p.posid >= 5 && p.posid <= 8;
      return p.posid >= 9;
    }).toList();
    final wages = squad!.fold<int>(0, (a, p) => a + p.salario);
    final avg = squad!.isEmpty
        ? 0
        : (squad!.fold<int>(0, (a, p) => a + p.poder) / squad!.length).round();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Skuad'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: Center(
              child: Text('AVG $avg',
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
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
                  child: Row(
                    children: [
                      Text('${squad!.length} pemain',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                      const Spacer(),
                      Text('Gaji: ${formatMoney(wages)}/musim',
                          style: const TextStyle(
                              fontSize: 12, color: AppColors.muted)),
                    ],
                  ),
                ),
                SizedBox(
                  height: 38,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final f in const [
                        [0, 'Semua'],
                        [1, 'Kiper'],
                        [2, 'Bertahan'],
                        [3, 'Tengah'],
                        [4, 'Depan']
                      ])
                        Padding(
                          padding: const EdgeInsets.only(right: 6),
                          child: ChoiceChip(
                            label: Text(f[1] as String),
                            selected: filterRole == f[0],
                            onSelected: (_) =>
                                setState(() => filterRole = f[0] as int),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
              ],
            ),
          ),
          Expanded(
            child: ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, __) =>
                  const Divider(height: 1, indent: 12, endIndent: 12),
              itemBuilder: (context, i) => PlayerRow(
                p: list[i],
                onTap: () async {
                  await showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: AppColors.surface,
                    shape: const RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.vertical(top: Radius.circular(20))),
                    builder: (_) => PlayerDetailSheet(
                        player: list[i],
                        service: widget.service,
                        isOwn: true),
                  );
                  _load();
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class PlayerDetailSheet extends StatefulWidget {
  final Player player;
  final GameService service;
  final bool isOwn;
  final int? userBudget;
  const PlayerDetailSheet(
      {super.key,
      required this.player,
      required this.service,
      this.isOwn = true,
      this.userBudget});
  @override
  State<PlayerDetailSheet> createState() => _PlayerDetailSheetState();
}

class _PlayerDetailSheetState extends State<PlayerDetailSheet> {
  bool busy = false;
  Map<String, dynamic>? clubInfo;

  @override
  void initState() {
    super.initState();
    if (!widget.isOwn) {
      widget.service.world.teamOfPlayer(widget.player.jugid).then((id) async {
        final t = await widget.service.world.team(id);
        if (mounted) setState(() => clubInfo = {'team': t});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.player;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.82,
      maxChildSize: 0.95,
      builder: (context, ctrl) => ListView(
        controller: ctrl,
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 24),
        children: [
          Center(
            child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: AppColors.line,
                    borderRadius: BorderRadius.circular(2))),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              CircleAvatar(
                radius: 30,
                backgroundColor:
                    Squads.positionColor(p.posid).withOpacity(0.18),
                child: Text(Squads.positionName(p.posid),
                    style: TextStyle(
                        fontWeight: FontWeight.w900,
                        color: Squads.positionColor(p.posid))),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Flexible(
                        child: Text(p.nombre,
                            style: const TextStyle(
                                fontSize: 19, fontWeight: FontWeight.w900)),
                      ),
                      if (p.star == 1) ...[
                        const SizedBox(width: 5),
                        const Icon(Icons.star, size: 16, color: AppColors.gold)
                      ],
                    ]),
                    Text(
                        '${p.edad} tahun · ${p.estatura} cm · #${p.numero} · '
                        '${p.perfil == 'I' ? 'Kaki kiri' : 'Kaki kanan'}',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                  ],
                ),
              ),
              Column(
                children: [
                  PowerBadge(p.poder),
                  const SizedBox(height: 4),
                  Text('POT ${p.potencial}',
                      style: const TextStyle(
                          fontSize: 10, color: AppColors.muted)),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  StatBar('Kecepatan', p.ritmo),
                  StatBar('Tembakan', p.tembakan),
                  StatBar('Passing', p.pases),
                  StatBar('Dribel', p.regate),
                  StatBar('Bertahan', p.defensa),
                  StatBar('Fisik', p.fisik),
                  if (p.posid == 1) StatBar('Kiper', p.kiper),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _kv('Nilai pasar', formatMoney(p.valor)),
              _kv('Gaji', formatMoney(p.salario)),
              _kv('Kondisi', '${p.condicion}%'),
            ],
          ),
          if (!widget.isOwn && clubInfo?['team'] != null) ...[
            const SizedBox(height: 8),
            Text('Klub: ${(clubInfo!['team'] as Team).nombre}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
          ],
          if (p.lesionado)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                const Icon(Icons.healing, color: AppColors.danger, size: 16),
                const SizedBox(width: 6),
                Text('Cedera, absen ${p.lesionSemanas} pekan',
                    style: const TextStyle(color: AppColors.danger, fontSize: 12)),
              ]),
            ),
          const SizedBox(height: 16),
          if (widget.isOwn) ...[
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _renew,
                    icon: const Icon(Icons.description_outlined, size: 18),
                    label: const Text('Perpanjang'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: busy ? null : _sell,
                    style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.danger,
                        side: const BorderSide(color: AppColors.danger)),
                    icon: const Icon(Icons.sell_outlined, size: 18),
                    label: const Text('Jual'),
                  ),
                ),
              ],
            ),
          ] else
            ElevatedButton.icon(
              onPressed: busy ? null : _offer,
              icon: const Icon(Icons.gavel),
              label: Text(busy ? 'Menegosiasi...' : 'Ajukan tawaran'),
            ),
        ],
      ),
    );
  }

  Widget _kv(String k, String v) => Expanded(
        child: Column(
          children: [
            Text(k, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 2),
            Text(v,
                style:
                    const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          ],
        ),
      );

  Future<void> _renew() async {
    final p = widget.player;
    final ctrl = TextEditingController(text: '${(p.salario * 1.25).round()}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Perpanjang kontrak ${p.nombre}'),
        content: TextField(
          controller: ctrl,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Gaji baru per musim'),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Tawarkan')),
        ],
      ),
    );
    if (ok != true) return;
    final val = int.tryParse(ctrl.text) ?? p.salario;
    setState(() => busy = true);
    final accept = val >= p.salario * 1.1;
    if (accept) {
      await widget.service.renewContract(p.jugid, val, 3);
    }
    setState(() => busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(accept
            ? 'Kontrak ${p.nombre} diperpanjang 3 musim.'
            : '${p.nombre} menolak tawaran gaji tersebut.')));
  }

  Future<void> _sell() async {
    setState(() => busy = true);
    final err = await widget.service.sellPlayer(widget.player.jugid);
    setState(() => busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(err ?? 'Pemain terjual.')));
    if (err == null && mounted) Navigator.pop(context);
  }

  Future<void> _offer() async {
    final p = widget.player;
    final ctrl =
        TextEditingController(text: '${(p.valor * 1.05).round()}');
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Tawar ${p.nombre}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Nilai pasar: ${formatMoney(p.valor)}',
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: ctrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Nominal tawaran'),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Kirim')),
        ],
      ),
    );
    if (ok != true) return;
    setState(() => busy = true);
    final err = await widget.service.makeOffer(
        p.jugid, int.tryParse(ctrl.text) ?? p.valor);
    setState(() => busy = false);
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(err ?? 'Transfer disetujui! ${p.nombre} bergabung.'),
        backgroundColor: err == null ? AppColors.primaryDark : AppColors.surface2));
    if (err == null && mounted) Navigator.pop(context);
  }
}
