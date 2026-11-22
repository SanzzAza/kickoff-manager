import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../db/db.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';
import 'menu_screen.dart';
import 'inbox_screen.dart';
import 'tactics_screen.dart';
import 'club_pages.dart';
import 'academy_screen.dart';
import 'career_extras_screens.dart';

class ClubScreen extends StatefulWidget {
  final GameService service;
  final ValueChanged<int> onNavigate;
  final ValueListenable<int>? refreshSignal;
  final VoidCallback? onDataChanged;
  const ClubScreen({
    super.key,
    required this.service,
    required this.onNavigate,
    this.refreshSignal,
    this.onDataChanged,
  });
  @override
  State<ClubScreen> createState() => _ClubScreenState();
}

class _ClubScreenState extends State<ClubScreen> {
  Map<String, dynamic>? data;
  bool busy = false;

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
    final st = await widget.service.state();
    final team = await widget.service.userTeam();
    final stadium = await widget.service.world.stadium(team.estaid);
    final standings = await widget.service.standings();
    final pos = standings.indexWhere((r) => r.equid == team.equid) + 1;
    final next = await widget.service.nextUserFixture();
    final unread = await widget.service.unread();
    final squad = await widget.service.world.squad(team.equid);
    final wages = squad.fold<int>(0, (a, p) => a + p.salario);
    final offer = await widget.service.pendingOffer();
    final superCup = await widget.service.superCupInfo();
    final friendly = await widget.service.friendlyInfo();
    if (!mounted) return;
    setState(() {
      data = {
        'state': st,
        'team': team,
        'stadium': stadium,
        'pos': pos,
        'teams': standings.length,
        'next': next,
        'unread': unread,
        'wages': wages,
        'squad': squad.length,
        'offer': offer,
        'superCup': superCup,
        'friendlyRemaining': friendly['remaining'],
      };
    });
  }

  Future<void> _simulateWeek() async {
    setState(() => busy = true);
    final summary = await widget.service.playWeek();
    await widget.service.trainWeek();
    setState(() => busy = false);
    await _load();
    widget.onDataChanged?.call();
    if (!mounted) return;
    if (summary.userMatch != null) {
      final go = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Pertandingan belum dimainkan'),
          content: const Text(
              'Laga klubmu di pekan ini masih menunggu. Masuk ke ruang ganti sekarang?'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Nanti')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Mainkan')),
          ],
        ),
      );
      if (go == true && mounted) widget.onNavigate(2);
    }
  }

  Future<void> _endSeason() async {
    final info = await widget.service.endSeason();
    if (!mounted) return;
    await Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => SeasonEndScreen(service: widget.service, info: info)));
    await _load();
    widget.onDataChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    if (data == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final st = data!['state'] as SaveState;
    final profile = st.managerProfile();
    final team = data!['team'] as Team;
    final stadium = data!['stadium'] as Stadium;
    final next = data!['next'] as Map<String, dynamic>?;
    final superCup = data!['superCup'] as Map<String, dynamic>?;
    final friendlyRemaining = (data!['friendlyRemaining'] as int?) ?? 5;
    final season = st.i('season_year');
    final week = st.i('week');
    final totalWeeks = st.i('total_weeks');
    final finished = week >= totalWeeks && next == null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Kickoff Manager'),
        actions: [
          IconButton(
            onPressed: () async {
              await Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => InboxScreen(service: widget.service)));
              _load();
            },
            icon: Stack(
              clipBehavior: Clip.none,
              children: [
                const Icon(Icons.mail_outline),
                if ((data!['unread'] as int) > 0)
                  Positioned(
                    right: -4,
                    top: -4,
                    child: Container(
                      padding: const EdgeInsets.all(3),
                      decoration: const BoxDecoration(
                          color: AppColors.danger, shape: BoxShape.circle),
                      child: Text('${data!['unread']}',
                          style: const TextStyle(fontSize: 8, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
              onPressed: () async {
                await Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => MenuScreen(service: widget.service)));
                _load();
              },
              icon: const Icon(Icons.menu)),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.only(bottom: 30),
          children: [
            Container(
              margin: const EdgeInsets.fromLTRB(14, 4, 14, 0),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF0E3B27), Color(0xFF12271E)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.line),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      CrestWidget(
                          nombre: team.nombre,
                          size: 56,
                          colorA: team.colorA,
                          colorB: team.colorB),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(team.nombre,
                                style: const TextStyle(
                                    fontSize: 19, fontWeight: FontWeight.w900)),
                            const SizedBox(height: 2),
                            Text('${st['league']} · Musim $season/${season + 1}',
                                style: const TextStyle(
                                    color: AppColors.muted, fontSize: 12)),
                            const SizedBox(height: 6),
                            Row(
                              children: [
                                PowerBadge(team.poder),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 7, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.accent.withOpacity(0.14),
                                    borderRadius: BorderRadius.circular(7),
                                  ),
                                  child: Text('P${data!['pos']}/${data!['teams']}',
                                      style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.accent)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Column(
                        children: [
                          ManagerAvatar(profile: profile, size: 46),
                          const SizedBox(height: 3),
                          Text(profile.trait.badge,
                              style: const TextStyle(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: AppColors.primary)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      _money('Kas klub', team.presupuesto),
                      _divider(),
                      _money('Gaji/musim', -(data!['wages'] as int)),
                      _divider(),
                      _stat('Pekan', '$week/$totalWeeks'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _barMini(
                          'Moral Tim',
                          st['morale'] != null ? st.i('morale') : 70,
                          AppColors.primary),
                      const SizedBox(width: 12),
                      _barMini('Direksi', st.i('confidence'), AppColors.accent),
                    ],
                  ),
                ],
              ),
            ),
            if (superCup != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                child: Card(
                  color: AppColors.surface2,
                  child: ListTile(
                    leading: const Icon(Icons.emoji_events,
                        color: AppColors.gold, size: 30),
                    title: Text(
                        'Piala Super vs ${(superCup['opponent'] as Team).nombre}',
                        style: const TextStyle(
                            fontWeight: FontWeight.w800, fontSize: 13.5)),
                    subtitle: Text(
                        'Hadiah trofi + ${formatMoney(superCup['prize'] as int)}',
                        style: const TextStyle(
                            fontSize: 11, color: AppColors.muted)),
                    trailing: FilledButton(
                      onPressed: () async {
                        final res = await widget.service.playSuperCup();
                        await _load();
                        if (!mounted) return;
                        final txt = res['won'] == true
                            ? 'JUARA PIALA SUPER! (${res['hg']}-${res['ag']})'
                            : 'Piala Super selesai (${res['hg']}-${res['ag']})';
                        ScaffoldMessenger.of(context)
                            .showSnackBar(SnackBar(content: Text(txt)));
                      },
                      child: const Text('Mainkan'),
                    ),
                  ),
                ),
              ),
            if (next != null) _nextMatchCard(next, team),
            if (data!['offer'] != null)
              _incomingOfferCard(data!['offer'] as Map<String, dynamic>),

            if (finished)
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 14, 14, 0),
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.accent.withOpacity(0.4)),
                  ),
                  child: Column(
                    children: [
                      const Text('MUSIM SELESAI',
                          style: TextStyle(
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                              color: AppColors.accent)),
                      const SizedBox(height: 6),
                      const Text(
                          'Semua pertandingan sudah dimainkan. Tutup musim untuk '
                          'mendapat hadiah, promosi, dan pemain menua.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: AppColors.muted)),
                      const SizedBox(height: 10),
                      ElevatedButton(
                          onPressed: _endSeason,
                          child: const Text('TUTUP MUSIM')),
                    ],
                  ),
                ),
              ),

            SectionTitle('Pusat manajemen'),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1.0,
                children: [
                  _tile(Icons.groups, 'Skuad', '${data!['squad']} pemain',
                      () => widget.onNavigate(1)),
                  _tile(Icons.swap_horiz, 'Transfer', 'Pasar aktif',
                      () => widget.onNavigate(4)),
                  _tile(Icons.leaderboard, 'Klasemen', 'Pekan $week',
                      () => widget.onNavigate(3)),
                  _tile(Icons.psychology, 'Taktik', 'Formasi & gaya',
                      () => _push(TacticsScreen(service: widget.service))),
                  _tile(Icons.fitness_center, 'Latihan', 'Program mingguan',
                      () => _push(TrainingScreen(service: widget.service))),
                  _tile(Icons.stadium, 'Stadion', '${_cap(stadium)} kursi',
                      () => _push(StadiumScreen(service: widget.service))),
                  _tile(Icons.savings, 'Finansial', 'Tiket & sponsor',
                      () => _push(FinanceScreen(service: widget.service))),
                  _tile(Icons.school, 'Akademi',
                      'Lv ${st.i('academy_level') > 0 ? st.i('academy_level') : 1} Wonderkid',
                      () => _push(AcademyScreen(service: widget.service))),
                  _tile(Icons.handshake, 'Uji Coba', '$friendlyRemaining/5 tersisa',
                      () => _push(FriendlyMatchScreen(service: widget.service))),
                  _tile(Icons.work_outline, 'Pindah Klub', 'Bursa manajer',
                      () => _push(JobMarketScreen(service: widget.service))),
                  _tile(Icons.tune, 'Editor', 'Ubah klub & skuad',
                      () => _push(ClubEditorScreen(service: widget.service))),
                  _tile(Icons.emoji_events, 'Karier',
                      '${st.i('trophies')} trofi',
                      () => _push(HistoryScreen(service: widget.service))),
                  _tile(Icons.mail_outline, 'Pesan', '${data!['unread']} baru',
                      () => _push(InboxScreen(service: widget.service))),
                ],
              ),
            ),

            SectionTitle(
              'Lanjutkan',
              trailing: Text(
                  finished
                      ? 'Semua pekan selesai'
                      : 'Pekan ${week + 1} dari $totalWeeks',
                  style: const TextStyle(fontSize: 11, color: AppColors.muted)),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ElevatedButton.icon(
                onPressed: (busy || finished) ? null : _simulateWeek,
                icon: busy
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.fast_forward),
                label: Text(busy
                    ? 'Memproses pekan...'
                    : finished
                        ? 'MUSIM SELESAI (TUTUP MUSIM DI ATAS)'
                        : 'SELESAIKAN PEKAN INI'),
              ),
            ),
            const SizedBox(height: 8),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 14),
              child: Text(
                'Laga klub lain disimulasikan otomatis, pemain pulih dari cedera, '
                'gaji & biaya operasional dipotong.',
                style: TextStyle(fontSize: 11, color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _push(Widget w) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => w));
    _load();
  }

  String _cap(Stadium s) => s.capacity.toString().replaceAllMapped(
      RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]}.');

  Widget _money(String label, int v) => Expanded(
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 3),
            Text(formatMoney(v),
                style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: v < 0 ? AppColors.danger : AppColors.text)),
          ],
        ),
      );

  Widget _stat(String label, String v) => Expanded(
        child: Column(
          children: [
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.muted)),
            const SizedBox(height: 3),
            Text(v,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          ],
        ),
      );

  Widget _divider() => Container(width: 1, height: 26, color: AppColors.line);

  Widget _barMini(String label, int val, Color color) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(label,
                    style:
                        const TextStyle(fontSize: 10, color: AppColors.muted)),
                const Spacer(),
                Text('$val%',
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
            const SizedBox(height: 3),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: (val / 100).clamp(0.0, 1.0),
                minHeight: 4,
                backgroundColor: AppColors.surface2,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ),
      );

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: AppColors.primary, size: 22),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                        fontSize: 12.5, fontWeight: FontWeight.w700)),
                Text(sub,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _incomingOfferCard(Map<String, dynamic> offer) {
    return Container(
      margin: const EdgeInsets.fromLTRB(14, 12, 14, 0),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.accent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.accent.withOpacity(0.55)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.local_offer, size: 15, color: AppColors.accent),
              const SizedBox(width: 6),
              const Text('TAWARAN MASUK',
                  style: TextStyle(
                      fontSize: 10,
                      letterSpacing: 1,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accent)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${offer['buyer_name']} menawar ${offer['player_name']} '
            '(OVR ${offer['player_poder']}) seharga ${formatMoney(offer['amount'] as int)}',
            style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () async {
                    final msg = await widget.service.respondIncomingOffer(false);
                    await _load();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg)));
                  },
                  child: const Text('Tolak'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton(
                  onPressed: () async {
                    final msg = await widget.service.respondIncomingOffer(true);
                    await _load();
                    widget.onDataChanged?.call();
                    if (!mounted) return;
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(msg)));
                  },
                  child: const Text('Terima'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _nextMatchCard(Map<String, dynamic> next, Team team) {
    final isHome = next['par_equid_local'] == team.equid;
    final vuelta = next['par_vuelta'] as int? ?? 0;
    final isCup = vuelta == 1;
    final isConti = vuelta == 2;
    final rivalId = isHome ? next['par_equid_visita'] : next['par_equid_local'];
    return FutureBuilder(
      future: widget.service.world.team(rivalId as int),
      builder: (context, snap) {
        final rival = snap.data;
        final borderColor = isConti
            ? const Color(0xFF4FC3F7).withOpacity(0.55)
            : isCup
                ? AppColors.gold.withOpacity(0.5)
                : AppColors.line;
        final label = isConti
            ? 'PIALA KONTINENTAL'
            : isCup
                ? 'PIALA DOMESTIK'
                : 'LAGA BERIKUTNYA';
        final labelColor = isConti
            ? const Color(0xFF4FC3F7)
            : isCup
                ? AppColors.gold
                : AppColors.muted;
        return Container(
          margin: const EdgeInsets.fromLTRB(14, 14, 14, 0),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label,
                      style: TextStyle(
                          fontSize: 9,
                          letterSpacing: 1,
                          fontWeight: FontWeight.w800,
                          color: labelColor)),
                  const SizedBox(height: 6),
                  Text(
                      rival == null
                          ? '-'
                          : '${isHome ? "vs" : "@"} ${rival.nombre}',
                      style: const TextStyle(
                          fontSize: 15, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(
                      'Pekan ${next['par_jornada']} · ${isHome ? "Kandang" : "Tandang"}',
                      style:
                          const TextStyle(fontSize: 11, color: AppColors.muted)),
                ],
              ),
              ),
              if (rival != null)
                CrestWidget(nombre: rival.nombre, colorA: rival.colorA, size: 38),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: () => widget.onNavigate(2),
                child: const Text('Main'),
              ),
            ],
          ),
        );
      },
    );
  }
}
