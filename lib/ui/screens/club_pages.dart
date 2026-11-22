import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

// ---------------- LATIHAN ----------------

class TrainingScreen extends StatefulWidget {
  final GameService service;
  const TrainingScreen({super.key, required this.service});
  @override
  State<TrainingScreen> createState() => _TrainingScreenState();
}

class _TrainingScreenState extends State<TrainingScreen> {
  int program = 0;
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    widget.service.state().then((st) {
      if (!mounted) return;
      setState(() {
        program = st.i('training');
        loaded = true;
      });
    });
  }

  static const _programs = [
    ['Seimbang', 'Semua atribut bergerak perlahan tapi merata'],
    ['Fisik', 'Prioritas fisik & kecepatan'],
    ['Teknis', 'Prioritas dribel & passing'],
    ['Taktik', 'Prioritas bertahan & penyelesaian'],
  ];

  @override
  Widget build(BuildContext context) {
    if (!loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Latihan')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          const Text('Program latihan mingguan',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          const Text(
              'Setiap pekan pemain muda berpeluang naik atribut. Pemain cedera '
              'tidak ikut latihan.',
              style: TextStyle(fontSize: 12, color: AppColors.muted)),
          const SizedBox(height: 14),
          ..._programs.asMap().entries.map((e) {
            final sel = program == e.key;
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () async {
                  setState(() => program = e.key);
                  await widget.service.setTraining(e.key);
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: sel
                        ? AppColors.primaryDark.withOpacity(0.22)
                        : AppColors.surface,
                    border: Border.all(
                        color: sel ? AppColors.primary : AppColors.line),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      Icon(
                          [Icons.tune, Icons.fitness_center, Icons.sports_soccer,
                                  Icons.psychology][e.key],
                          color: sel ? AppColors.primary : AppColors.muted,
                          size: 20),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(e.value[0],
                                style: const TextStyle(
                                    fontWeight: FontWeight.w800, fontSize: 13.5)),
                            Text(e.value[1],
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
      ),
    );
  }
}

// ---------------- STADION ----------------

class StadiumScreen extends StatefulWidget {
  final GameService service;
  const StadiumScreen({super.key, required this.service});
  @override
  State<StadiumScreen> createState() => _StadiumScreenState();
}

class _StadiumScreenState extends State<StadiumScreen> {
  Stadium? stadium;
  Team? team;
  bool busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await widget.service.userTeam();
    final s = await widget.service.world.stadium(t.estaid);
    if (!mounted) return;
    setState(() {
      team = t;
      stadium = s;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (stadium == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final s = stadium!;
    return Scaffold(
      appBar: AppBar(title: const Text('Stadion')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.stadium, size: 44, color: AppColors.primary),
                  const SizedBox(height: 8),
                  Text(s.nombre,
                      style: const TextStyle(
                          fontSize: 17, fontWeight: FontWeight.w900)),
                  const SizedBox(height: 4),
                  Text('Kapasitas ${s.capacity} / maks ${s.maxCapacity}',
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.muted)),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _statSq('Ekonomi', s.general, s.maxGeneral),
                      _statSq('Utama', s.plateas, s.maxPlateas),
                      _statSq('Samping', s.tribunas, s.maxTribunas),
                      _statSq('VIP Box', s.palcos, s.maxPalcos),
                    ],
                  ),
                ],
              ),
            ),
          ),
          SectionTitle('Harga tiket: ${s.precio} / kursi'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Slider(
                  value: s.precio.toDouble().clamp(10, 90),
                  min: 10,
                  max: 90,
                  divisions: 16,
                  label: '${s.precio}',
                  activeColor: AppColors.primary,
                  onChanged: (v) async {
                    await widget.service.setTicketPrice(v.round());
                    await _load();
                  },
                ),
                const Text(
                    'Tiket mahal = pemasukan per kursi naik, namun tingkat keterisian turun.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted)),
              ],
            ),
          ),
          SectionTitle('Ekspansi tribun'),
          ...['general', 'plateas', 'tribunas', 'palcos'].map((sector) {
            final labels = {
              'general': 'Tribun Ekonomi',
              'plateas': 'Tribun Utama',
              'tribunas': 'Tribun Samping',
              'palcos': 'VIP Box',
            };
            final cur = {
              'general': s.general,
              'plateas': s.plateas,
              'tribunas': s.tribunas,
              'palcos': s.palcos
            }[sector]!;
            final max = {
              'general': s.maxGeneral,
              'plateas': s.maxPlateas,
              'tribunas': s.maxTribunas,
              'palcos': s.maxPalcos
            }[sector]!;
            final full = cur >= max;
            return ListTile(
              dense: true,
              title: Text('${labels[sector]}  ($cur/$max)',
                  style: const TextStyle(fontSize: 13)),
              subtitle: Text(
                  full ? 'Sudah maksimum' : 'Tambah 1000 kursi',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
              trailing: FilledButton(
                onPressed: busy || full
                    ? null
                    : () async {
                        setState(() => busy = true);
                        final msg = await widget.service
                            .expandStadium(sector, 1000);
                        setState(() => busy = false);
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(msg)));
                      },
                child: const Text('Bangun'),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _statSq(String label, int cur, int max) => Expanded(
        child: Column(
          children: [
            Text('$cur',
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            Text(label,
                style: const TextStyle(fontSize: 9.5, color: AppColors.muted)),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : cur / max,
                minHeight: 4,
                backgroundColor: AppColors.surface2,
                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
              ),
            ),
          ],
        ),
      );
}

// ---------------- FINANSIAL ----------------

class FinanceScreen extends StatefulWidget {
  final GameService service;
  const FinanceScreen({super.key, required this.service});
  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  Map<String, dynamic>? data;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final team = await widget.service.userTeam();
    final st = await widget.service.state();
    final squad = await widget.service.world.squad(team.equid);
    final stadium = await widget.service.world.stadium(team.estaid);
    final fixtures = await widget.service.userFixtures();
    final sponsorsList = await widget.service.availableSponsors();
    final incomes = fixtures
        .where((f) => (f['par_status'] as int? ?? 0) == 1)
        .fold<int>(0, (a, f) => a + ((f['par_ent_ingresos'] as int?) ?? 0));
    final wages = squad.fold<int>(0, (a, p) => a + p.salario);
    if (!mounted) return;
    setState(() => data = {
          'team': team,
          'state': st,
          'wages': wages,
          'stadium': stadium,
          'income': incomes,
          'maintenance': (stadium.capacity * 2.1).round(),
          'sponsorsList': sponsorsList,
        });
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final team = data!['team'] as Team;
    final st = data!['state'] as dynamic;
    final sponsorName = (st['sponsor_name'] as String?) ?? '';
    final sponsorBonus = st.i('sponsor_bonus');
    final sponsorTarget = st.i('sponsor_target');
    final sponsorsList = data!['sponsorsList'] as List<Map<String, dynamic>>;
    final wages = data!['wages'] as int;
    final income = data!['income'] as int;
    final maint = data!['maintenance'] as int;
    final sponsors = (team.poder * 420000).round();
    return Scaffold(
      appBar: AppBar(title: const Text('Finansial')),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Text('SALDO KAS',
                      style: TextStyle(
                          fontSize: 10,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.w800,
                          color: AppColors.muted)),
                  const SizedBox(height: 6),
                  Text(formatMoney(team.presupuesto),
                      style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w900,
                          color: team.presupuesto < 0
                              ? AppColors.danger
                              : AppColors.primary)),
                ],
              ),
            ),
          ),
          SectionTitle('Sponsor Utama Musim Ini'),
          if (sponsorName.isNotEmpty)
            Card(
              child: ListTile(
                leading: const Icon(Icons.verified, color: AppColors.primary),
                title: Text(sponsorName,
                    style: const TextStyle(fontWeight: FontWeight.w800)),
                subtitle: Text(
                    'Bonus ${formatMoney(sponsorBonus)} jika finis $sponsorTarget besar',
                    style: const TextStyle(fontSize: 11.5, color: AppColors.muted)),
              ),
            )
          else
            ...sponsorsList.map((sp) => Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    title: Text(sp['name'] as String,
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    subtitle: Text(
                        '${sp['desc']}\nUang muka ${formatMoney(sp['upfront'] as int)} · Bonus ${formatMoney(sp['bonus'] as int)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                    isThreeLine: true,
                    trailing: FilledButton(
                      onPressed: () async {
                        final msg = await widget.service.selectSponsor(sp);
                        await _load();
                        if (!mounted) return;
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(msg)));
                      },
                      child: const Text('Pilih'),
                    ),
                  ),
                )),
          SectionTitle('Arus kas musim ini'),
          _line('Pendapatan tiket & TV', income, true),
          _line('Sponsor utama', sponsors, true),
          _line('Total gaji pemain', -wages, false),
          _line('Operasional stadion', -maint * (income > 0 ? 10 : 0), false),
          const Divider(),
          _line('Prakiraan bersih',
              income + sponsors - wages - maint * (income > 0 ? 10 : 0), true,
              bold: true),
          SectionTitle('Catatan'),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 14),
            child: Text(
                'Pendapatan tiket dihitung dari kehadiran penonton tiap laga kandang. '
                'Gaji dipotong setiap pekan. Sponsor mengikuti popularitas klub.',
                style: TextStyle(fontSize: 11.5, color: AppColors.muted, height: 1.4)),
          ),
        ],
      ),
    );
  }

  Widget _line(String label, int v, bool positive, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
      child: Row(
        children: [
          Expanded(
              child: Text(label,
                  style: TextStyle(
                      fontSize: bold ? 13.5 : 12.5,
                      fontWeight: bold ? FontWeight.w800 : FontWeight.w400))),
          Text(formatMoney(v),
              style: TextStyle(
                  fontSize: bold ? 14 : 12.5,
                  fontWeight: FontWeight.w800,
                  color: v < 0 ? AppColors.danger : AppColors.primary)),
        ],
      ),
    );
  }
}

// ---------------- SEJARAH ----------------

class HistoryScreen extends StatefulWidget {
  final GameService service;
  const HistoryScreen({super.key, required this.service});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  List<Map<String, dynamic>>? rows;
  List<Map<String, dynamic>> awards = [];
  Map<String, dynamic>? stats;
  ManagerProfile? profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widget.service.world.history();
    final st = await widget.service.managerStats();
    final sv = await widget.service.state();
    final aw = await widget.service.allSeasonAwards();
    if (!mounted) return;
    setState(() {
      rows = r;
      stats = st;
      awards = aw;
      profile = sv.managerProfile();
    });
  }

  String _awardLabel(String tipo) {
    switch (tipo) {
      case 'pichichi':
        return 'Sepatu Emas (Top Skor)';
      case 'assist_king':
        return 'Raja Assist';
      case 'ballon_dor':
        return 'Bola Emas (Pemain Terbaik)';
      case 'golden_glove':
        return 'Sarung Tangan Emas (Kiper)';
      case 'golden_boy':
        return 'Pemain Muda Terbaik U-21';
      default:
        return tipo;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Karier & Sejarah')),
      body: rows == null
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.only(bottom: 24),
              children: [
                if (stats != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 14, 14, 6),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(14),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                if (profile != null)
                                  ManagerAvatar(profile: profile!, size: 46)
                                else
                                  const Icon(Icons.person_pin,
                                      color: AppColors.primary, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text('Manajer: ${stats!['manager']}',
                                          style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w900)),
                                      if (profile != null)
                                        Text(
                                            '${profile!.nationality} · ${profile!.trait.label}',
                                            style: const TextStyle(
                                                fontSize: 11,
                                                color: AppColors.muted)),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.gold.withOpacity(0.16),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text('${stats!['trophies']} Trofi',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.gold)),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                _kpi('Laga', '${stats!['played']}'),
                                _kpi('M-S-K',
                                    '${stats!['wins']}-${stats!['draws']}-${stats!['losses']}'),
                                _kpi('Menang', '${stats!['winRate']}%'),
                                _kpi('Gol', '${stats!['gf']}:${stats!['ga']}'),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
                const SectionTitle('Riwayat Musim'),
                if (rows!.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: EmptyState(
                        icon: Icons.emoji_events,
                        text:
                            'Belum ada musim yang selesai.\nSelesaikan musim pertamamu!'),
                  )
                else
                  ...rows!.map((r) {
                    final juara = (r['hist_user_pos'] as int? ?? 0) == 1;
                    return Card(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 6),
                      child: ListTile(
                        leading: Icon(
                            juara ? Icons.emoji_events : Icons.calendar_today,
                            color: juara ? AppColors.gold : AppColors.muted),
                        title: Text(
                            'Musim ${r['hist_anio']}/${(r['hist_anio'] as int) + 1}',
                            style: const TextStyle(
                                fontSize: 13.5, fontWeight: FontWeight.w700)),
                        subtitle: Text(
                            'Juara: ${r['hist_campeon_nombre']} · '
                            'Kamu: posisi ${r['hist_user_pos']}',
                            style: const TextStyle(
                                fontSize: 11.5, color: AppColors.muted)),
                        trailing: Text('${r['hist_user_pts']} pts',
                            style: const TextStyle(
                                fontSize: 12, fontWeight: FontWeight.w800)),
                      ),
                    );
                  }),
                if (awards.isNotEmpty) ...[
                  const SectionTitle('Penghargaan Individu'),
                  ...awards.take(15).map((aw) => Card(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 4),
                        child: ListTile(
                          dense: true,
                          leading: const Icon(Icons.military_tech,
                              color: AppColors.gold, size: 22),
                          title: Text('${aw['jug_nombre'] ?? '-'}',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13)),
                          subtitle: Text(
                              '${_awardLabel(aw['tipo'] as String)} · ${aw['equi_nombre'] ?? ''}',
                              style: const TextStyle(
                                  fontSize: 11, color: AppColors.muted)),
                          trailing: Text('${aw['anio']}',
                              style: const TextStyle(
                                  fontSize: 11, fontWeight: FontWeight.w800)),
                        ),
                      )),
                ],
              ],
            ),
    );
  }

  Widget _kpi(String l, String v) => Expanded(
        child: Column(
          children: [
            Text(v,
                style:
                    const TextStyle(fontSize: 14, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(l, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
          ],
        ),
      );
}

// ---------------- AKHIR MUSIM ----------------

class SeasonEndScreen extends StatelessWidget {
  final GameService service;
  final Map<String, dynamic> info;
  const SeasonEndScreen(
      {super.key, required this.service, required this.info});
  @override
  Widget build(BuildContext context) {
    final championUser = info['championUser'] as bool;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const SizedBox(height: 16),
            Icon(championUser ? Icons.emoji_events : Icons.sports_soccer,
                size: 74,
                color: championUser ? AppColors.gold : AppColors.primary),
            const SizedBox(height: 18),
            Text(
                championUser
                    ? 'JUARA ${(info['year'] as int)}/${(info['year'] as int) + 1}'
                    : 'MUSIM SELESAI',
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w900,
                    color: championUser ? AppColors.gold : AppColors.text)),
            const SizedBox(height: 8),
            Text('Juara liga: ${info['champion']}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 13, color: AppColors.muted)),
            const SizedBox(height: 20),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _row('Posisi akhir', '${info['userPos']}'),
                    const Divider(),
                    _row('Sepatu Emas (Top Skor)',
                        '${info['scorer']} (${info['scorerGoals']})'),
                    if (info['assister'] != null && info['assister'] != '-') ...[
                      const Divider(),
                      _row('Raja Assist',
                          '${info['assister']} (${info['assisterCount']})'),
                    ],
                    if (info['bestPlayer'] != null) ...[
                      const Divider(),
                      _row('Bola Emas (MVP)', '${info['bestPlayer']}'),
                    ],
                    if (info['bestGk'] != null && info['bestGk'] != '-') ...[
                      const Divider(),
                      _row('Sarung Tangan Emas', '${info['bestGk']}'),
                    ],
                    if (info['youngPlayer'] != null &&
                        info['youngPlayer'] != '-') ...[
                      const Divider(),
                      _row('Pemain Muda Terbaik', '${info['youngPlayer']}'),
                    ],
                    const Divider(),
                    _row('Hadiah liga', formatMoney(info['prize'] as int)),
                  ],
                ),
              ),
            ),
            if (info['sacked'] == true) ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: AppColors.danger.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border:
                        Border.all(color: AppColors.danger.withOpacity(0.5))),
                child: const Text(
                    'Direksi kehilangan kepercayaan dan memutus kontrakmu. '
                    'Kamu harus mencari klub baru.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, color: AppColors.danger)),
              ),
            ],
            if ((info['offers'] as List).isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                  info['sacked'] == true
                      ? 'PILIH KLUB BARU'
                      : 'LAMARAN KLUB LAIN',
                  style: const TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w800,
                      color: AppColors.muted)),
              const SizedBox(height: 6),
              ...(info['offers'] as List).map((o) => Card(
                    child: ListTile(
                      dense: true,
                      title: Text(o['nombre'] as String,
                          style: const TextStyle(fontSize: 13)),
                      subtitle: Text('Kekuatan ${o['poder']}',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                      trailing: TextButton(
                        onPressed: () async {
                          await service.acceptJob(o['equid'] as int);
                          await service.nextSeason();
                          if (context.mounted) Navigator.pop(context);
                        },
                        child: const Text('Terima'),
                      ),
                    ),
                  )),
            ],
            const SizedBox(height: 20),
            ElevatedButton(
              key: const Key('next_season_btn'),
              onPressed: () async {
                await service.nextSeason();
                if (context.mounted) Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(52)),
              child: Text(info['sacked'] == true
                  ? 'LANJUTKAN KARIER'
                  : 'MULAI MUSIM BARU'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Widget _row(String k, String v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(k,
                style: const TextStyle(fontSize: 12, color: AppColors.muted)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(v,
                  textAlign: TextAlign.end,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      );
}
