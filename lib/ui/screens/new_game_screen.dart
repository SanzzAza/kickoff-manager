import 'package:flutter/material.dart';
import '../../data/football_data.dart';
import '../../db/db.dart';
import '../../engine/game_service.dart';
import '../theme.dart';
import '../widgets.dart';
import 'home_shell.dart';

class NewGameScreen extends StatefulWidget {
  final GameService service;
  const NewGameScreen({super.key, required this.service});
  @override
  State<NewGameScreen> createState() => _NewGameScreenState();
}

class _NewGameScreenState extends State<NewGameScreen> {
  final _nameCtrl = TextEditingController(text: 'Manager Baru');
  int step = 0;
  String conf = 'UEFA';
  LeagueDef? league;
  String? club;
  bool creating = false;
  String? error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Karier Baru'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(
            value: (step + 1) / 3,
            minHeight: 3,
            backgroundColor: AppColors.surface2,
            valueColor: const AlwaysStoppedAnimation(AppColors.primary),
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: step == 0
            ? _stepName()
            : step == 1
                ? _stepLeague()
                : _stepClub(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              if (step > 0)
                Expanded(
                  child: OutlinedButton(
                    onPressed: creating ? null : () => setState(() => step--),
                    child: const Text('Kembali'),
                  ),
                ),
              if (step > 0) const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: creating
                      ? null
                      : () async {
                          if (step == 0) {
                            if (_nameCtrl.text.trim().isEmpty) return;
                            setState(() => step = 1);
                          } else if (step == 1) {
                            if (league == null) return;
                            setState(() => step = 2);
                          } else {
                            await _create();
                          }
                        },
                  child: creating
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(step == 2 ? 'MULAI KARIER' : 'Lanjut'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepName() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Siapa nama manajermu?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Nama ini akan tercatat di sejarah klub.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 20),
        TextField(
          controller: _nameCtrl,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'Nama manajer',
            prefixIcon: Icon(Icons.person_outline),
          ),
        ),
        const SizedBox(height: 24),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                Text('Yang akan kamu kelola',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                SizedBox(height: 8),
                _Bullet('Skuad 24 pemain + pasar transfer & negosiasi'),
                _Bullet('Taktik: formasi, mentalitas, pressing, gaya main'),
                _Bullet('Simulasi pertandingan menit demi menit + rating pemain'),
                _Bullet('Finansial: tiket, gaji, sponsor, ekspansi stadion'),
                _Bullet('Latihan, cedera, skorsing, kontrak, dan promosi'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _stepLeague() {
    final leagueList = leagues;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Pilih liga',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Kamu bisa memilih klub mana pun di liga ini.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 16),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: confederations.keys.map((c) {
              final sel = c == conf;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c),
                  selected: sel,
                  onSelected: (_) => setState(() {
                    conf = c;
                    league = null;
                    club = null;
                  }),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 12),
        ...leagueList.where((l) => l.confederation == conf).map((l) {
          final sel = league?.name == l.name;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () => setState(() {
                league = l;
                club = null;
              }),
              borderRadius: BorderRadius.circular(14),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryDark.withOpacity(0.22) : AppColors.surface,
                  border: Border.all(
                      color: sel ? AppColors.primary : AppColors.line, width: sel ? 1.6 : 1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CrestWidget(
                        nombre: l.name, colorA: '#0B5D3B', size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          Text('${countryLabel(l.country)} · ${l.teams} klub · level ${l.base}',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (sel) const Icon(Icons.check_circle, color: AppColors.primary),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _stepClub() {
    final l = league!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Pilih klub di ${l.name}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 6),
        const Text('Klub kecil = tantangan lebih besar.',
            style: TextStyle(color: AppColors.muted, fontSize: 13)),
        const SizedBox(height: 14),
        ...l.clubs.asMap().entries.map((e) {
          final sel = club == e.value;
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: InkWell(
              onTap: () => setState(() => club = e.value),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: sel ? AppColors.primaryDark.withOpacity(0.22) : AppColors.surface,
                  border: Border.all(
                      color: sel ? AppColors.primary : AppColors.line,
                      width: sel ? 1.6 : 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CrestWidget(nombre: e.value, size: 30, colorA: '#166534'),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(e.value,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14))),
                    if (e.key < 4)
                      Container(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                            color: AppColors.gold.withOpacity(0.15),
                            borderRadius: BorderRadius.circular(5)),
                        child: const Text('FAVORIT',
                            style: TextStyle(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: AppColors.gold)),
                      ),
                    if (sel)
                      const Padding(
                        padding: EdgeInsets.only(left: 6),
                        child: Icon(Icons.check_circle, size: 18, color: AppColors.primary),
                      ),
                  ],
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Future<void> _create() async {
    if (club == null) return;
    setState(() {
      creating = true;
      error = null;
    });
    try {
      await Db.closeAndDelete();
      final db = await Db.instance;
      final svc = GameService(World(db));
      await svc.newGame(
        managerName: _nameCtrl.text.trim(),
        leagueName: league!.name,
        clubName: club!,
      );
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => HomeShell(service: svc)),
        (r) => false,
      );
    } catch (e) {
      setState(() {
        creating = false;
        error = e.toString();
      });
    }
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 5),
            child: Icon(Icons.circle, size: 5, color: AppColors.primary),
          ),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: const TextStyle(fontSize: 12.5, color: AppColors.muted))),
        ],
      ),
    );
  }
}
