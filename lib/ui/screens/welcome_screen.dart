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
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xFF0A3220), Color(0xFF091611), AppColors.bg],
              ),
            ),
          ),
          Positioned.fill(
            child: CustomPaint(painter: _WelcomePitchPainter()),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _badge('100% OFFLINE', AppColors.primary),
                      const SizedBox(width: 8),
                      _badge('BEBAS IKLAN', AppColors.accent),
                    ],
                  ),
                  const Spacer(),
                  Center(
                    child: Container(
                      height: 108,
                      width: 108,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(28),
                        border: Border.all(
                            color: AppColors.primary.withOpacity(0.55), width: 1.8),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.primary.withOpacity(0.28),
                              blurRadius: 34,
                              spreadRadius: 2),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(26),
                        child: Image.asset('assets/icon/logo.png', fit: BoxFit.cover),
                      ),
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('KICKOFF\nMANAGER',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 40,
                          height: 1.0,
                          fontWeight: FontWeight.w900,
                          letterSpacing: -1.2)),
                  const SizedBox(height: 10),
                  const Text(
                      'Bangun dinasti sepak bolamu: atur taktik, kembangkan akademi, '
                      'buru bintang transfer, dan menangkan trofi.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppColors.muted, fontSize: 13.5, height: 1.45)),
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
                    hasSave == true
                        ? OutlinedButton.icon(
                            onPressed: _startNewCareer,
                            icon: const Icon(Icons.add),
                            label: const Text('Karier Baru'),
                          )
                        : ElevatedButton.icon(
                            onPressed: _startNewCareer,
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('MULAI KARIER'),
                          ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.surface.withOpacity(0.72),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.line),
                      ),
                      child: const Text(
                        '14 liga dunia · 258 klub · Piala Kontinental · Simulasi 2D',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 11, color: AppColors.muted),
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text('v$appVersion ($appBuild)',
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 10, color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _badge(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withOpacity(0.14),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withOpacity(0.4)),
        ),
        child: Text(text,
            style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: color)),
      );

  Future<void> _startNewCareer() async {
    if (hasSave == true) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Mulai karier baru?'),
          content:
              const Text('Karier yang tersimpan akan dihapus permanen.'),
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
    if (!mounted) return;
    await Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => NewGameScreen(service: widget.service)),
    );
    if (!mounted) return;
    setState(() => hasSave = null);
    widget.service.hasSave().then((v) {
      if (mounted) setState(() => hasSave = v);
    });
  }
}

class _WelcomePitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final line = Paint()
      ..color = Colors.white.withOpacity(0.04)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    canvas.drawCircle(
        Offset(size.width * 0.5, size.height * 0.42), size.width * 0.34, line);
    canvas.drawLine(Offset(0, size.height * 0.42),
        Offset(size.width, size.height * 0.42), line);
    canvas.drawRect(
      Rect.fromCenter(
          center: Offset(size.width * 0.5, size.height * 0.06),
          width: size.width * 0.56,
          height: size.height * 0.16),
      line,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
