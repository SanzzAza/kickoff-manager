import 'package:flutter/material.dart';
import '../../engine/game_service.dart';
import '../../version.dart';
import '../theme.dart';
import 'new_game_screen.dart';
import 'home_shell.dart';

class WelcomeScreen extends StatefulWidget {
  final GameService service;
  const WelcomeScreen({super.key, required this.service});
  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool? hasSave;

  @override
  void initState() {
    super.initState();
    widget.service.hasSave().then((v) => setState(() => hasSave = v));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF0B2E1C), AppColors.bg],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Spacer(),
                Center(
                  child: Container(
                    height: 104,
                    width: 104,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(26),
                      border: Border.all(
                          color: AppColors.primary.withOpacity(0.5), width: 1.5),
                      boxShadow: [
                        BoxShadow(
                            color: AppColors.primary.withOpacity(0.25),
                            blurRadius: 30,
                            spreadRadius: 2),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(25),
                      child: Image.asset('assets/icon/logo.png', fit: BoxFit.cover),
                    ),
                  ),
                ),
                const SizedBox(height: 22),
                const Text('KICKOFF\nMANAGER',
                    style: TextStyle(
                        fontSize: 40,
                        height: 1.02,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1)),
                const SizedBox(height: 10),
                const Text(
                    'Kelola klub, susun taktik, belanja pemain, dan bawa '
                    'timmu juara. 100% offline.',
                    style: TextStyle(color: AppColors.muted, fontSize: 14, height: 1.4)),
                const Spacer(),
                if (hasSave == null)
                  const Center(child: CircularProgressIndicator())
                else ...[
                  if (hasSave == true)
                    ElevatedButton.icon(
                      onPressed: () => Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                            builder: (_) => HomeShell(service: widget.service)),
                      ),
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: const Text('LANJUTKAN KARIER'),
                    ),
                  if (hasSave == true) const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () async {
                      if (hasSave == true) {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Mulai karier baru?'),
                            content: const Text(
                                'Karier yang tersimpan akan dihapus permanen.'),
                            actions: [
                              TextButton(
                                  onPressed: () => Navigator.pop(ctx, false),
                                  child: const Text('Batal')),
                              FilledButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: const Text('Hapus & mulai')),
                            ],
                          ),
                        );
                        if (ok != true) return;
                      }
                      if (!context.mounted) return;
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => NewGameScreen(service: widget.service)),
                      );
                      if (!context.mounted) return;
                      setState(() {
                        hasSave = null;
                      });
                      widget.service.hasSave().then((v) {
                        if (mounted) setState(() => hasSave = v);
                      });
                    },
                    icon: const Icon(Icons.add),
                    label: Text(hasSave == true ? 'Karier Baru' : 'MULAI KARIER'),
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    '15 liga · 5 konfederasi · 1.700+ pemain · simulasi menit-per-menit',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
                const SizedBox(height: 8),
                Text('v$appVersion ($appBuild)',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
