import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../../models/models.dart';
import '../theme.dart';
import '../widgets.dart';

class TacticsScreen extends StatefulWidget {
  final GameService service;
  const TacticsScreen({super.key, required this.service});
  @override
  State<TacticsScreen> createState() => _TacticsScreenState();
}

class _TacticsScreenState extends State<TacticsScreen> {
  Tactics? tac;
  List<Player> xi = [];
  bool saved = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final t = await widget.service.tactics();
    final team = await widget.service.userTeam();
    final setup = await widget.service.buildSetup(team, t);
    if (!mounted) return;
    setState(() {
      tac = t;
      xi = setup.xi;
    });
  }

  Future<void> _save() async {
    await widget.service.saveTactics(tac!);
    setState(() => saved = true);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Taktik disimpan.')));
  }

  @override
  Widget build(BuildContext context) {
    if (tac == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final t = tac!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Taktik'),
        actions: [
          TextButton(
            onPressed: saved ? null : _save,
            child: Text(saved ? 'Tersimpan' : 'SIMPAN',
                style: TextStyle(
                    color: saved ? AppColors.muted : AppColors.primary,
                    fontWeight: FontWeight.w800)),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 30),
        children: [
          Padding(
            padding: const EdgeInsets.all(14),
            child: AspectRatio(
              aspectRatio: 0.72,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                          painter: FormationPainter(t.formacion, AppColors.primary)),
                    ),
                    Positioned(
                      top: 10,
                      left: 10,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.45),
                            borderRadius: BorderRadius.circular(8)),
                        child: Text(t.formacion.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w900, fontSize: 15)),
                      ),
                    ),
                    // nama pemain per slot
                    ...List.generate(t.formacion.slots.length, (i) {
                      final s = t.formacion.slots[i];
                      final p = i < xi.length ? xi[i] : null;
                      return Positioned(
                        left: s[0] * MediaQuery.of(context).size.width * 0.0 +
                            (s[0] * (MediaQuery.of(context).size.width - 28)) - 34,
                        top: (s[1] * (MediaQuery.of(context).size.width / 0.72 - 28)) - 2,
                        width: 68,
                        child: Text(
                          p == null
                              ? '-'
                              : p.nombre.split(' ').last.length > 9
                                  ? p.nombre.split(' ').last.substring(0, 9)
                                  : p.nombre.split(' ').last,
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 8.5,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              shadows: [Shadow(blurRadius: 3, color: Colors.black)]),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            ),
          ),
          SectionTitle('Formasi'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: Formation.values.map((f) {
                final sel = f == t.formacion;
                return ChoiceChip(
                  label: Text(f.label),
                  selected: sel,
                  onSelected: (_) {
                    setState(() {
                      t.formacion = f;
                      saved = false;
                    });
                    _load();
                  },
                );
              }).toList(),
            ),
          ),
          _selector('Mentalitas', Mentality.all, t.mentalidad, (v) {
            setState(() {
              t.mentalidad = v;
              saved = false;
            });
          }),
          _selector('Pressing', Pressure.all, t.presion, (v) {
            setState(() {
              t.presion = v;
              saved = false;
            });
          }),
          _selector('Gaya main', Style.all, t.estilo, (v) {
            setState(() {
              t.estilo = v;
              saved = false;
            });
          }),
          _slider('Amplitudo', t.amplitud, (v) {
            setState(() {
              t.amplitud = v;
              saved = false;
            });
          }),
          _slider('Garis pertahanan', t.linea, (v) {
            setState(() {
              t.linea = v;
              saved = false;
            });
          }),
          SectionTitle('Starting XI (otomatis)'),
          Card(
            margin: const EdgeInsets.symmetric(horizontal: 14),
            child: Column(
              children: xi
                  .map((p) => Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        child: Row(
                          children: [
                            SizedBox(
                                width: 34,
                                child: Text('${p.numero}',
                                    style: const TextStyle(
                                        fontSize: 11, color: AppColors.muted))),
                            Container(
                              width: 34,
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                  color: Squads.positionColor(p.posid)
                                      .withOpacity(0.16),
                                  borderRadius: BorderRadius.circular(4)),
                              child: Text(Squads.positionName(p.posid),
                                  style: TextStyle(
                                      fontSize: 9,
                                      fontWeight: FontWeight.w800,
                                      color: Squads.positionColor(p.posid))),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(p.nombre,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontSize: 13))),
                            PowerBadge(p.poder),
                          ],
                        ),
                      ))
                  .toList(),
            ),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: ElevatedButton(
              onPressed: _save,
              child: const Text('SIMPAN TAKTIK'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _selector(String title, List<String> options, String current,
      ValueChanged<String> onPick) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: options.map((o) {
              final sel = o == current;
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () => onPick(o),
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: sel
                            ? AppColors.primaryDark.withOpacity(0.35)
                            : AppColors.surface,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: sel ? AppColors.primary : AppColors.line),
                      ),
                      child: Text(o,
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight:
                                  sel ? FontWeight.w800 : FontWeight.w500,
                              color: sel ? AppColors.primary : AppColors.text)),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _slider(String title, int value, ValueChanged<int> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(title),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Expanded(
                child: Slider(
                  value: value.toDouble(),
                  min: 1,
                  max: 5,
                  divisions: 4,
                  label: '$value',
                  activeColor: AppColors.primary,
                  onChanged: (v) => onChanged(v.round()),
                ),
              ),
              SizedBox(
                  width: 22,
                  child: Text('$value',
                      style: const TextStyle(fontWeight: FontWeight.w800))),
            ],
          ),
        ),
      ],
    );
  }
}
