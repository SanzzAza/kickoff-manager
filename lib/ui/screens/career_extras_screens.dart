import 'package:flutter/material.dart';
import '../../data/football_data.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

// ---------------- LAGA UJI COBA (FRIENDLY) ----------------

class FriendlyMatchScreen extends StatefulWidget {
  final GameService service;
  const FriendlyMatchScreen({super.key, required this.service});
  @override
  State<FriendlyMatchScreen> createState() => _FriendlyMatchScreenState();
}

class _FriendlyMatchScreenState extends State<FriendlyMatchScreen> {
  Map<String, dynamic>? info;
  Map<String, dynamic>? lastResult;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final d = await widget.service.friendlyInfo();
    if (!mounted) return;
    setState(() => info = d);
  }

  @override
  Widget build(BuildContext context) {
    if (info == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final remaining = info!['remaining'] as int;
    final used = info!['used'] as int;
    final opps = info!['opponents'] as List<Team>;
    return Scaffold(
      appBar: AppBar(title: const Text('Laga Uji Coba')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  const Icon(Icons.handshake, color: AppColors.primary, size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Kuota Uji Coba: $used / 5 musim ini',
                            style: const TextStyle(
                                fontWeight: FontWeight.w800, fontSize: 14)),
                        const Text(
                            'Uji formasi tanpa memengaruhi poin klasemen, tambah moral, '
                            'dan dapatkan pemasukan tiket.',
                            style: TextStyle(
                                fontSize: 11.5, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (lastResult != null && lastResult!['error'] == null) ...[
            const SizedBox(height: 10),
            Card(
              color: AppColors.surface2,
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('HASIL UJI COBA TERAKHIR',
                        style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary)),
                    const SizedBox(height: 6),
                    Text(
                      '${lastResult!['home']} ${lastResult!['hg']} - ${lastResult!['ag']} ${lastResult!['away']}',
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900),
                    ),
                    Text(
                        'Pemasukan tiket: ${formatMoney(lastResult!['gate'] as int)}',
                        style: const TextStyle(
                            fontSize: 11.5, color: AppColors.muted)),
                  ],
                ),
              ),
            ),
          ],
          SectionTitle('Pilih Lawan ($remaining tersisa)'),
          ...opps.map((opp) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CrestWidget(
                      nombre: opp.nombre,
                      size: 34,
                      colorA: opp.colorA,
                      colorB: opp.colorB),
                  title: Text(opp.nombre,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  subtitle: Text('Kekuatan ${opp.poder}',
                      style: const TextStyle(
                          fontSize: 11.5, color: AppColors.muted)),
                  trailing: FilledButton(
                    onPressed: (busy || remaining <= 0)
                        ? null
                        : () async {
                            setState(() => busy = true);
                            final res =
                                await widget.service.playFriendly(opp.equid);
                            setState(() {
                              busy = false;
                              lastResult = res;
                            });
                            await _load();
                          },
                    child: const Text('Tanding'),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

// ---------------- BURSA MANAJER / PINDAH KLUB ----------------

class JobMarketScreen extends StatefulWidget {
  final GameService service;
  const JobMarketScreen({super.key, required this.service});
  @override
  State<JobMarketScreen> createState() => _JobMarketScreenState();
}

class _JobMarketScreenState extends State<JobMarketScreen> {
  List<Map<String, dynamic>>? jobs;
  String? selectedLeague;
  int rep = 55;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final st = await widget.service.state();
    final j =
        await widget.service.availableJobs(leagueFilter: selectedLeague);
    if (!mounted) return;
    setState(() {
      rep = st.i('reputation');
      jobs = j;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Bursa Manajer & Pindah Klub')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
            child: Row(
              children: [
                const Icon(Icons.workspace_premium,
                    color: AppColors.gold, size: 18),
                const SizedBox(width: 6),
                Text('Reputasi Manajer: $rep/99',
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          SizedBox(
            height: 42,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 14),
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ChoiceChip(
                    label: const Text('Semua Liga'),
                    selected: selectedLeague == null,
                    onSelected: (_) {
                      selectedLeague = null;
                      _load();
                    },
                  ),
                ),
                ...leagues.map((l) => Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChoiceChip(
                        label: Text(l.name),
                        selected: selectedLeague == l.name,
                        onSelected: (_) {
                          selectedLeague = l.name;
                          _load();
                        },
                      ),
                    )),
              ],
            ),
          ),
          Expanded(
            child: jobs == null
                ? const Center(child: CircularProgressIndicator())
                : ListView.builder(
                    padding: const EdgeInsets.all(14),
                    itemCount: jobs!.length,
                    itemBuilder: (_, i) {
                      final row = jobs![i];
                      final team = row['team'] as Team;
                      final unlocked = row['unlocked'] as bool;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: CrestWidget(
                              nombre: team.nombre,
                              size: 36,
                              colorA: team.colorA,
                              colorB: team.colorB),
                          title: Text(team.nombre,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700)),
                          subtitle: Text(
                              '${row['league']} · OVR ${team.poder} · Kas ${formatMoney(team.presupuesto)}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.muted)),
                          trailing: unlocked
                              ? FilledButton(
                                  onPressed: () async {
                                    final ok = await showDialog<bool>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: Text('Pindah ke ${team.nombre}?'),
                                        content: Text(
                                            'Kamu akan mengundurkan diri dari klub saat ini '
                                            'dan melatih ${team.nombre} (${row['league']}).'),
                                        actions: [
                                          TextButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, false),
                                              child: const Text('Batal')),
                                          FilledButton(
                                              onPressed: () =>
                                                  Navigator.pop(ctx, true),
                                              child: const Text('Pindah')),
                                        ],
                                      ),
                                    );
                                    if (ok != true) return;
                                    final msg = await widget.service
                                        .resignAndJoin(team.equid);
                                    if (!mounted) return;
                                    ScaffoldMessenger.of(context).showSnackBar(
                                        SnackBar(content: Text(msg)));
                                    Navigator.pop(context, true);
                                  },
                                  child: const Text('Lamar'),
                                )
                              : const Icon(Icons.lock_outline,
                                  color: AppColors.muted, size: 18),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------- EDITOR KLUB & PEMAIN (100% GRATIS) ----------------

class ClubEditorScreen extends StatefulWidget {
  final GameService service;
  const ClubEditorScreen({super.key, required this.service});
  @override
  State<ClubEditorScreen> createState() => _ClubEditorScreenState();
}

class _ClubEditorScreenState extends State<ClubEditorScreen> {
  Team? team;
  List<Player> squad = [];
  final _clubNameCtrl = TextEditingController();
  final _abrevCtrl = TextEditingController();
  String colorA = '#1B5E20';
  String colorB = '#FFFFFF';

  static const _palette = [
    '#C62828',
    '#1565C0',
    '#2E7D32',
    '#6A1B9A',
    '#EF6C00',
    '#00838F',
    '#212121',
    '#F9A825',
  ];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _clubNameCtrl.dispose();
    _abrevCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final t = await widget.service.userTeam();
    final sq = await widget.service.world.squad(t.equid);
    if (!mounted) return;
    setState(() {
      team = t;
      squad = sq;
      _clubNameCtrl.text = t.nombre;
      _abrevCtrl.text = t.abrev;
      colorA = t.colorA;
      colorB = t.colorB;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (team == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Editor Klub & Skuad')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CrestWidget(
                        nombre: _clubNameCtrl.text.isEmpty
                            ? team!.nombre
                            : _clubNameCtrl.text,
                        colorA: colorA,
                        colorB: colorB,
                        size: 52,
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                            'Ubah identitas klub dan atribut pemainmu sesuka hati, gratis tanpa batas.',
                            style: TextStyle(
                                fontSize: 12, color: AppColors.muted)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _clubNameCtrl,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(labelText: 'Nama Klub'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _abrevCtrl,
                    maxLength: 4,
                    decoration: const InputDecoration(
                        labelText: 'Singkatan (3-4 huruf)'),
                  ),
                  const SizedBox(height: 6),
                  const Text('Warna Utama Perisai',
                      style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    children: _palette.map((hex) {
                      final sel = colorA.toUpperCase() == hex;
                      final c = Color(int.parse('FF${hex.substring(1)}', radix: 16));
                      return GestureDetector(
                        onTap: () => setState(() => colorA = hex),
                        child: Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: sel ? Colors.white : Colors.white24,
                              width: sel ? 2.5 : 1,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () async {
                        await widget.service.updateClubInfo(
                          team!.equid,
                          nombre: _clubNameCtrl.text,
                          abrev: _abrevCtrl.text,
                          colorA: colorA,
                          colorB: colorB,
                        );
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                                content: Text('Identitas klub diperbarui!')));
                      },
                      icon: const Icon(Icons.save_outlined),
                      label: const Text('Simpan Identitas Klub'),
                    ),
                  ),
                ],
              ),
            ),
          ),
          SectionTitle('Edit Pemain Skuad (${squad.length})'),
          ...squad.map((p) => Card(
                margin: const EdgeInsets.only(bottom: 6),
                child: ListTile(
                  leading: PlayerAvatar(seed: p.jugid, size: 38),
                  title: Text(p.nombre,
                      style: const TextStyle(
                          fontWeight: FontWeight.w700, fontSize: 13.5)),
                  subtitle: Text(
                      '${Squads.positionName(p.posid)} · #${p.numero} · OVR ${p.poder}',
                      style: const TextStyle(
                          fontSize: 11, color: AppColors.muted)),
                  trailing: IconButton(
                    icon: const Icon(Icons.edit_outlined,
                        color: AppColors.primary),
                    onPressed: () => _editPlayerDialog(p),
                  ),
                ),
              )),
        ],
      ),
    );
  }

  Future<void> _editPlayerDialog(Player p) async {
    final nameCtrl = TextEditingController(text: p.nombre);
    var posid = p.posid;
    var numero = p.numero;
    var poder = p.poder;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Edit Pemain'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameCtrl,
                  decoration: const InputDecoration(labelText: 'Nama Pemain'),
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  value: positions.any((x) => x.id == posid) ? posid : 7,
                  decoration: const InputDecoration(labelText: 'Posisi'),
                  items: positions
                      .map((pos) => DropdownMenuItem(
                            value: pos.id,
                            child: Text('${pos.abrev} - ${pos.name}'),
                          ))
                      .toList(),
                  onChanged: (v) => setD(() => posid = v ?? posid),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text('Nomor: #$numero',
                        style: const TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: numero.toDouble(),
                        min: 1,
                        max: 99,
                        divisions: 98,
                        onChanged: (v) => setD(() => numero = v.round()),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('OVR: $poder', style: const TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: poder.toDouble(),
                        min: 45,
                        max: 99,
                        divisions: 54,
                        onChanged: (v) => setD(() => poder = v.round()),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Simpan')),
          ],
        ),
      ),
    );
    if (ok == true) {
      await widget.service.updatePlayerInfo(
        p.jugid,
        nombre: nameCtrl.text,
        posid: posid,
        numero: numero,
        poder: poder,
      );
      await _load();
    }
  }
}
