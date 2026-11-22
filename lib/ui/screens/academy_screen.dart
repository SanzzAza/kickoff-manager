import 'package:flutter/material.dart';
import '../../data/football_data.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

class AcademyScreen extends StatefulWidget {
  final GameService service;
  const AcademyScreen({super.key, required this.service});
  @override
  State<AcademyScreen> createState() => _AcademyScreenState();
}

class _AcademyScreenState extends State<AcademyScreen> {
  Map<String, dynamic>? info;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final data = await widget.service.academyInfo();
    if (!mounted) return;
    setState(() => info = data);
  }

  @override
  Widget build(BuildContext context) {
    if (info == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final level = info!['level'] as int;
    final cost = info!['upgradeCost'] as int;
    final canScout = info!['canScout'] as bool;
    final prospects = info!['prospects'] as List<Map<String, dynamic>>;

    return Scaffold(
      appBar: AppBar(title: const Text('Akademi Muda')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.school, size: 36, color: AppColors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Akademi Level $level / 5',
                                style: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w900)),
                            const Text(
                                'Level tinggi menghasilkan calon wonderkid berpotensi 90+.',
                                style: TextStyle(
                                    fontSize: 11.5, color: AppColors.muted)),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (busy || level >= 5)
                              ? null
                              : () async {
                                  setState(() => busy = true);
                                  final msg =
                                      await widget.service.upgradeAcademy();
                                  setState(() => busy = false);
                                  await _load();
                                  if (!mounted) return;
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text(msg)));
                                },
                          icon: const Icon(Icons.upgrade, size: 18),
                          label: Text(level >= 5
                              ? 'Level Maks'
                              : 'Upgrade (${formatMoney(cost)})'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: (busy || !canScout)
                      ? null
                      : () async {
                          setState(() => busy = true);
                          final msg = await widget.service.scoutAcademy();
                          setState(() => busy = false);
                          await _load();
                          if (!mounted) return;
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(msg)));
                        },
                  icon: const Icon(Icons.person_search),
                  label: Text(canScout
                      ? 'CARI WONDERKID'
                      : 'Istirahat (6 pekan)'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: busy ? null : _createCustomDialog,
                  icon: const Icon(Icons.person_add_alt_1, size: 18),
                  label: const Text('Buat Pemain'),
                ),
              ),
            ],
          ),
          SectionTitle('Calon Pemain Muda (${prospects.length})'),
          if (prospects.isEmpty)
            const EmptyState(
                icon: Icons.person_add_alt_1,
                text:
                    'Belum ada calon pemain.\nTekan "Cari Wonderkid Baru" untuk mencari talenta muda.')
          else
            ...prospects.asMap().entries.map((e) {
              final i = e.key;
              final p = e.value;
              final posid = p['posid'] as int;
              final poder = p['poder'] as int;
              final pot = p['potencial'] as int;
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          PlayerAvatar(seed: i + poder + pot, size: 42),
                          const SizedBox(width: 10),
                          CircleAvatar(
                            radius: 15,
                            backgroundColor:
                                Squads.positionColor(posid).withOpacity(0.18),
                            child: Text(Squads.positionName(posid),
                                style: TextStyle(
                                    fontSize: 9.5,
                                    fontWeight: FontWeight.w800,
                                    color: Squads.positionColor(posid))),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(p['nombre'] as String,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w800)),
                                Text('${p['edad']} tahun · Potensi $pot',
                                    style: const TextStyle(
                                        fontSize: 11.5,
                                        color: AppColors.accent)),
                              ],
                            ),
                          ),
                          PowerBadge(poder),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () async {
                                await widget.service.dismissProspect(i);
                                await _load();
                              },
                              child: const Text('Lepas'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            flex: 2,
                            child: FilledButton.icon(
                              onPressed: busy
                                  ? null
                                  : () async {
                                      setState(() => busy = true);
                                      final msg = await widget.service
                                          .promoteProspect(i);
                                      setState(() => busy = false);
                                      await _load();
                                      if (!mounted) return;
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                              SnackBar(content: Text(msg)));
                                    },
                              icon: const Icon(Icons.arrow_upward, size: 16),
                              label: const Text('Promosikan (Gratis)'),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Future<void> _createCustomDialog() async {
    final nameCtrl = TextEditingController(text: 'Garuda Muda');
    var edad = 17;
    var posid = 10;
    var perfil = 'D';
    var skillId = 9;
    var numero = 47;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Buat Pemain Akademi Kustom'),
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
                  value: posid,
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
                DropdownButtonFormField<int>(
                  value: skillId,
                  decoration: const InputDecoration(labelText: 'Skill Spesial'),
                  items: PlayerSkillCatalog.all.values
                      .map((sk) => DropdownMenuItem(
                            value: sk.id,
                            child: Text(sk.name),
                          ))
                      .toList(),
                  onChanged: (v) => setD(() => skillId = v ?? skillId),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('Kaki Kanan'),
                      selected: perfil == 'D',
                      onSelected: (_) => setD(() => perfil = 'D'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('Kaki Kiri'),
                      selected: perfil == 'I',
                      onSelected: (_) => setD(() => perfil = 'I'),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('Umur: $edad th', style: const TextStyle(fontSize: 12)),
                    Expanded(
                      child: Slider(
                        value: edad.toDouble(),
                        min: 16,
                        max: 21,
                        divisions: 5,
                        onChanged: (v) => setD(() => edad = v.round()),
                      ),
                    ),
                  ],
                ),
                Row(
                  children: [
                    Text('Nomor: #$numero', style: const TextStyle(fontSize: 12)),
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
              ],
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Batal')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Buat & Promosi')),
          ],
        ),
      ),
    );
    if (ok == true) {
      final msg = await widget.service.createCustomAcademyPlayer(
        nombre: nameCtrl.text,
        edad: edad,
        posid: posid,
        perfil: perfil,
        skillId: skillId,
        numero: numero,
      );
      await _load();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }
}
