import 'dart:math';
import 'package:flutter/material.dart';
import '../../data/football_data.dart';
import '../../db/db.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
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
  final _nameCtrl = TextEditingController(text: 'Coach Nusantara');
  int step = 0;
  String conf = 'UEFA';
  LeagueDef? league;
  String? club;
  bool creating = false;
  String? error;

  ManagerProfile _profile = const ManagerProfile(
    name: 'Coach Nusantara',
    nationality: 'ID',
    hairStyle: 1,
    skinTone: 2,
    outfitStyle: 0,
    suitColor: 1,
    glasses: false,
    beard: false,
    trait: ManagerTrait.tactician,
  );

  static const _nationalities = [
    ('ID', 'Indonesia'),
    ('ES', 'Spanyol'),
    ('GB', 'Inggris'),
    ('IT', 'Italia'),
    ('DE', 'Jerman'),
    ('FR', 'Prancis'),
    ('BR', 'Brasil'),
    ('AR', 'Argentina'),
    ('JP', 'Jepang'),
  ];

  static const _hairNames = [
    'Klasik',
    'Modern',
    'Ikal',
    'Topi',
    'Veteran',
    'Plontos',
  ];

  static const _outfitNames = ['Jas Resmi', 'Tracksuit', 'Polo'];

  static const _randomCoachNames = [
    'Bima Pratama',
    'Rizky Saputra',
    'Bagus Santoso',
    'Adi Wijaya',
    'Marco Rossi',
    'Carlos Mendoza',
    'Liam Gallagher',
    'Kenji Takahashi',
  ];

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(step == 0
            ? 'Buat Karakter Manajer'
            : step == 1
                ? 'Pilih Kompetisi'
                : 'Pilih Klub'),
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
            ? _stepCharacter()
            : step == 1
                ? _stepLeague()
                : _stepClub(),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(error!,
                      style: const TextStyle(color: AppColors.danger, fontSize: 12)),
                ),
              Row(
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
                                setState(() {
                                  _profile = _profile.copyWith(
                                      name: _nameCtrl.text.trim());
                                  step = 1;
                                });
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
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepCharacter() {
    final natLabel = _nationalities
        .firstWhere((e) => e.$1 == _profile.nationality,
            orElse: () => ('ID', 'Indonesia'))
        .$2;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Siapa nama manajermu?',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        const Text('Atur identitas, penampilan, dan keahlian awal pelatihmu.',
            style: TextStyle(color: AppColors.muted, fontSize: 12.5)),
        const SizedBox(height: 14),

        // Kartu preview karakter manajer
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0E3D28), Color(0xFF13241C)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.primary.withOpacity(0.45)),
          ),
          child: Row(
            children: [
              ManagerAvatar(profile: _profile, size: 74),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _nameCtrl.text.trim().isEmpty
                          ? 'Manajer Baru'
                          : _nameCtrl.text.trim(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text('Kebangsaan: $natLabel (${_profile.nationality})',
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.muted)),
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withOpacity(0.16),
                        borderRadius: BorderRadius.circular(7),
                        border: Border.all(
                            color: AppColors.accent.withOpacity(0.45)),
                      ),
                      child: Text(_profile.trait.badge,
                          style: const TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w800,
                              color: AppColors.accent)),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Nama + Acak
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                textCapitalization: TextCapitalization.words,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Nama manajer',
                  prefixIcon: Icon(Icons.person_outline),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              tooltip: 'Acak nama',
              onPressed: () {
                final r = Random();
                _nameCtrl.text =
                    _randomCoachNames[r.nextInt(_randomCoachNames.length)];
                setState(() {});
              },
              icon: const Icon(Icons.casino_outlined),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // Kewarganegaraan
        const Text('Kewarganegaraan',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.muted)),
        const SizedBox(height: 6),
        SizedBox(
          height: 36,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: _nationalities.map((n) {
              final sel = _profile.nationality == n.$1;
              return Padding(
                padding: const EdgeInsets.only(right: 6),
                child: ChoiceChip(
                  label: Text('${n.$2} (${n.$1})'),
                  selected: sel,
                  onSelected: (_) => setState(() =>
                      _profile = _profile.copyWith(nationality: n.$1)),
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 14),

        // Penampilan Avatar
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Kustomisasi Penampilan',
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 13.5)),
                const SizedBox(height: 10),
                const Text('Gaya Rambut',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: List.generate(_hairNames.length, (i) {
                    return ChoiceChip(
                      label: Text(_hairNames[i]),
                      selected: _profile.hairStyle == i,
                      onSelected: (_) => setState(
                          () => _profile = _profile.copyWith(hairStyle: i)),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text('Warna Kulit',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: List.generate(ManagerAvatar.skinTones.length, (i) {
                    final sel = _profile.skinTone == i;
                    return GestureDetector(
                      onTap: () => setState(
                          () => _profile = _profile.copyWith(skinTone: i)),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: ManagerAvatar.skinTones[i],
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: sel ? AppColors.primary : Colors.white24,
                            width: sel ? 2.5 : 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                const Text('Warna Busana / Jas',
                    style: TextStyle(fontSize: 11.5, color: AppColors.muted)),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  runSpacing: 8,
                  children: List.generate(ManagerAvatar.suitColors.length, (i) {
                    final sel = _profile.suitColor == i;
                    return GestureDetector(
                      onTap: () => setState(
                          () => _profile = _profile.copyWith(suitColor: i)),
                      child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                          color: ManagerAvatar.suitColors[i],
                          borderRadius: BorderRadius.circular(7),
                          border: Border.all(
                            color: sel ? AppColors.accent : Colors.white24,
                            width: sel ? 2.2 : 1,
                          ),
                        ),
                      ),
                    );
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        children: List.generate(_outfitNames.length, (i) {
                          return ChoiceChip(
                            label: Text(_outfitNames[i]),
                            selected: _profile.outfitStyle == i,
                            onSelected: (_) => setState(() =>
                                _profile = _profile.copyWith(outfitStyle: i)),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    FilterChip(
                      label: const Text('Kacamata'),
                      selected: _profile.glasses,
                      onSelected: (v) => setState(
                          () => _profile = _profile.copyWith(glasses: v)),
                    ),
                    const SizedBox(width: 8),
                    FilterChip(
                      label: const Text('Jenggot'),
                      selected: _profile.beard,
                      onSelected: (v) => setState(
                          () => _profile = _profile.copyWith(beard: v)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),

        // Keahlian Awal (Trait)
        const Text('Pilih Gaya & Keahlian Awal',
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: AppColors.muted)),
        const SizedBox(height: 8),
        ...ManagerTrait.values.map((t) {
          final sel = _profile.trait == t;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              onTap: () =>
                  setState(() => _profile = _profile.copyWith(trait: t)),
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryDark.withOpacity(0.24)
                      : AppColors.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: sel ? AppColors.primary : AppColors.line,
                      width: sel ? 1.5 : 1),
                ),
                child: Row(
                  children: [
                    Icon(
                      t == ManagerTrait.tactician
                          ? Icons.psychology
                          : t == ManagerTrait.scout
                              ? Icons.school
                              : t == ManagerTrait.negotiator
                                  ? Icons.handshake
                                  : Icons.campaign,
                      color: sel ? AppColors.primary : AppColors.muted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(t.label,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 13.5)),
                          Text(t.desc,
                              style: const TextStyle(
                                  fontSize: 11.5, color: AppColors.muted)),
                        ],
                      ),
                    ),
                    if (sel)
                      const Icon(Icons.check_circle,
                          color: AppColors.primary, size: 18),
                  ],
                ),
              ),
            ),
          );
        }),
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
                  color: sel
                      ? AppColors.primaryDark.withOpacity(0.22)
                      : AppColors.surface,
                  border: Border.all(
                      color: sel ? AppColors.primary : AppColors.line,
                      width: sel ? 1.6 : 1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    CrestWidget(nombre: l.name, colorA: '#0B5D3B', size: 38),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(l.name,
                              style: const TextStyle(
                                  fontWeight: FontWeight.w800, fontSize: 15)),
                          Text(
                              '${countryLabel(l.country)} · ${l.teams} klub · level ${l.base}',
                              style: const TextStyle(
                                  color: AppColors.muted, fontSize: 12)),
                        ],
                      ),
                    ),
                    if (sel)
                      const Icon(Icons.check_circle, color: AppColors.primary),
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
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: sel
                      ? AppColors.primaryDark.withOpacity(0.22)
                      : AppColors.surface,
                  border: Border.all(
                      color: sel ? AppColors.primary : AppColors.line,
                      width: sel ? 1.6 : 1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    CrestWidget(nombre: e.value, size: 32, colorA: '#166534'),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(e.value,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 14))),
                    if (e.key < 4)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
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
                        child: Icon(Icons.check_circle,
                            size: 18, color: AppColors.primary),
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
      final name = _nameCtrl.text.trim();
      await svc.newGame(
        managerName: name,
        leagueName: league!.name,
        clubName: club!,
        profile: _profile.copyWith(name: name),
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
