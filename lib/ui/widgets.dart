import 'package:flutter/material.dart';
import '../models/models.dart';
import 'theme.dart';

class CrestWidget extends StatelessWidget {
  final String nombre;
  final String colorA;
  final String colorB;
  final double size;

  const CrestWidget(
      {super.key,
      required this.nombre,
      this.colorA = '#1B5E20',
      this.colorB = '#FFFFFF',
      this.size = 34});

  Color _parse(String hex) {
    try {
      final h = hex.replaceAll('#', '');
      return Color(int.parse('FF$h', radix: 16));
    } catch (_) {
      return AppColors.primary;
    }
  }

  String _slug(String name) {
    const rep = {
      'á': 'a', 'à': 'a', 'ä': 'a', 'â': 'a', 'ã': 'a',
      'é': 'e', 'è': 'e', 'ë': 'e', 'ê': 'e',
      'í': 'i', 'ì': 'i', 'ï': 'i', 'î': 'i',
      'ó': 'o', 'ò': 'o', 'ö': 'o', 'ô': 'o', 'õ': 'o',
      'ú': 'u', 'ù': 'u', 'ü': 'u', 'û': 'u',
      'ñ': 'n', 'ç': 'c',
    };
    var s = name.toLowerCase();
    rep.forEach((k, v) => s = s.replaceAll(k, v));
    return s
        .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
  }

  @override
  Widget build(BuildContext context) {
    final slug = _slug(nombre);
    final initials = nombre
        .split(RegExp(r'[\s-]+'))
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0])
        .join()
        .toUpperCase();
    return ClipRRect(
      borderRadius: BorderRadius.circular(size * 0.25),
      child: Image.asset(
        'assets/clubs/$slug.png',
        width: size,
        height: size,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackCrest(initials),
      ),
    );
  }

  Widget _fallbackCrest(String initials) {
    final c1 = _parse(colorA);
    var c2 = _parse(colorB);
    if ((c1.value & 0xFFFFFF) == (c2.value & 0xFFFFFF)) {
      c2 = Colors.white;
    }
    final pattern = nombre.codeUnits.fold<int>(0, (a, b) => a + b) % 6;
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ShieldCrestPainter(c1, c2, pattern),
        child: Center(
          child: Padding(
            padding: EdgeInsets.only(bottom: size * 0.06),
            child: Text(
              initials,
              style: TextStyle(
                fontSize: size * 0.31,
                fontWeight: FontWeight.w900,
                color: Colors.white,
                letterSpacing: -0.5,
                shadows: const [
                  Shadow(color: Colors.black87, blurRadius: 4, offset: Offset(0, 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShieldCrestPainter extends CustomPainter {
  final Color primary;
  final Color secondary;
  final int pattern;
  _ShieldCrestPainter(this.primary, this.secondary, this.pattern);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final shield = Path()
      ..moveTo(w * 0.12, h * 0.08)
      ..quadraticBezierTo(w * 0.5, h * 0.02, w * 0.88, h * 0.08)
      ..lineTo(w * 0.88, h * 0.48)
      ..quadraticBezierTo(w * 0.85, h * 0.78, w * 0.5, h * 0.94)
      ..quadraticBezierTo(w * 0.15, h * 0.78, w * 0.12, h * 0.48)
      ..close();

    canvas.save();
    canvas.clipPath(shield);
    canvas.drawRect(Offset.zero & size, Paint()..color = primary);

    final sec = Paint()..color = secondary.withOpacity(0.28);
    final secStrong = Paint()..color = secondary.withOpacity(0.45);
    switch (pattern) {
      case 0: // Garis vertikal
        for (var i = 0; i < 3; i++) {
          canvas.drawRect(
              Rect.fromLTWH(w * (0.16 + i * 0.27), 0, w * 0.12, h), sec);
        }
        break;
      case 1: // Setengah-setengah
        canvas.drawRect(Rect.fromLTWH(w * 0.5, 0, w * 0.5, h), sec);
        break;
      case 2: // Diagonal sash
        final sash = Path()
          ..moveTo(0, h * 0.75)
          ..lineTo(w * 0.75, 0)
          ..lineTo(w, 0)
          ..lineTo(w, h * 0.25)
          ..lineTo(w * 0.25, h)
          ..lineTo(0, h)
          ..close();
        canvas.drawPath(sash, secStrong);
        break;
      case 3: // Pita horizontal
        canvas.drawRect(Rect.fromLTWH(0, h * 0.36, w, h * 0.24), secStrong);
        break;
      case 4: // Chevron V
        final chev = Path()
          ..moveTo(0, h * 0.24)
          ..lineTo(w * 0.5, h * 0.62)
          ..lineTo(w, h * 0.24)
          ..lineTo(w, h * 0.46)
          ..lineTo(w * 0.5, h * 0.84)
          ..lineTo(0, h * 0.46)
          ..close();
        canvas.drawPath(chev, secStrong);
        break;
      default: // Perisai dalam + garis atas
        canvas.drawRect(Rect.fromLTWH(0, 0, w, h * 0.24), secStrong);
        break;
    }

    // Kilau kaca atas
    canvas.drawRect(
      Rect.fromLTWH(0, 0, w, h * 0.36),
      Paint()..color = Colors.white.withOpacity(0.08),
    );
    canvas.restore();

    // Bingkai luar metalik
    canvas.drawPath(
      shield,
      Paint()
        ..color = secondary.withOpacity(0.85)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.055,
    );
  }

  @override
  bool shouldRepaint(covariant _ShieldCrestPainter old) =>
      old.primary != primary || old.secondary != secondary || old.pattern != pattern;
}

class ManagerAvatar extends StatelessWidget {
  final ManagerProfile profile;
  final double size;
  const ManagerAvatar({super.key, required this.profile, this.size = 56});

  static const skinTones = [
    Color(0xFFF6D5B8),
    Color(0xFFE4B48C),
    Color(0xFFC68A5B),
    Color(0xFF9B643D),
    Color(0xFF6B4228),
  ];

  static const suitColors = [
    Color(0xFF1E293B),
    Color(0xFF0B5D3B),
    Color(0xFF1D4ED8),
    Color(0xFF881337),
    Color(0xFF4C1D95),
    Color(0xFF374151),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CustomPaint(
          painter: _ManagerAvatarPainter(profile),
        ),
      ),
    );
  }
}

class _ManagerAvatarPainter extends CustomPainter {
  final ManagerProfile p;
  _ManagerAvatarPainter(this.p);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final skin = ManagerAvatar.skinTones[p.skinTone % ManagerAvatar.skinTones.length];
    final suit = ManagerAvatar.suitColors[p.suitColor % ManagerAvatar.suitColors.length];

    // Latar gradien stadion malam
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = const LinearGradient(
          colors: [Color(0xFF134E3A), Color(0xFF0C1A15)],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(Offset.zero & size),
    );

    // Bahu & busana
    final body = Path()
      ..moveTo(w * 0.10, h)
      ..quadraticBezierTo(w * 0.14, h * 0.66, w * 0.50, h * 0.66)
      ..quadraticBezierTo(w * 0.86, h * 0.66, w * 0.90, h)
      ..close();
    canvas.drawPath(body, Paint()..color = suit);

    if (p.outfitStyle == 0) {
      // Kemeja + dasi
      final shirt = Path()
        ..moveTo(w * 0.39, h * 0.66)
        ..lineTo(w * 0.50, h * 0.88)
        ..lineTo(w * 0.61, h * 0.66)
        ..close();
      canvas.drawPath(shirt, Paint()..color = Colors.white.withOpacity(0.92));
      final tie = Path()
        ..moveTo(w * 0.47, h * 0.68)
        ..lineTo(w * 0.53, h * 0.68)
        ..lineTo(w * 0.52, h * 0.96)
        ..lineTo(w * 0.48, h * 0.96)
        ..close();
      canvas.drawPath(tie, Paint()..color = AppColors.accent);
    } else if (p.outfitStyle == 1) {
      // Resleting jaket tracksuit
      canvas.drawLine(
        Offset(w * 0.50, h * 0.67),
        Offset(w * 0.50, h),
        Paint()
          ..color = Colors.white.withOpacity(0.75)
          ..strokeWidth = w * 0.035,
      );
      canvas.drawRect(
        Rect.fromLTWH(w * 0.22, h * 0.78, w * 0.14, h * 0.04),
        Paint()..color = Colors.white.withOpacity(0.4),
      );
    } else {
      // Kerah polo / sweater
      canvas.drawArc(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.67), width: w * 0.24, height: h * 0.12),
        0,
        3.14,
        false,
        Paint()
          ..color = Colors.white.withOpacity(0.65)
          ..style = PaintingStyle.stroke
          ..strokeWidth = w * 0.035,
      );
    }

    // Leher
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(w * 0.50, h * 0.62), width: w * 0.16, height: h * 0.16),
        Radius.circular(w * 0.06),
      ),
      Paint()..color = skin.withOpacity(0.9),
    );

    // Telinga
    canvas.drawCircle(Offset(w * 0.30, h * 0.44), w * 0.048, Paint()..color = skin);
    canvas.drawCircle(Offset(w * 0.70, h * 0.44), w * 0.048, Paint()..color = skin);

    // Wajah
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.43), width: w * 0.38, height: h * 0.42),
      Paint()..color = skin,
    );

    // Jenggot opsional
    if (p.beard) {
      final beardPath = Path()
        ..moveTo(w * 0.32, h * 0.45)
        ..quadraticBezierTo(w * 0.50, h * 0.69, w * 0.68, h * 0.45)
        ..lineTo(w * 0.65, h * 0.58)
        ..quadraticBezierTo(w * 0.50, h * 0.68, w * 0.35, h * 0.58)
        ..close();
      canvas.drawPath(beardPath, Paint()..color = const Color(0xFF1F2937).withOpacity(0.82));
    }

    // Mata & alis
    final eyePaint = Paint()..color = const Color(0xFF111827);
    canvas.drawCircle(Offset(w * 0.42, h * 0.42), w * 0.025, eyePaint);
    canvas.drawCircle(Offset(w * 0.58, h * 0.42), w * 0.025, eyePaint);

    // Mulut ramah
    canvas.drawArc(
      Rect.fromCenter(center: Offset(w * 0.50, h * 0.52), width: w * 0.13, height: h * 0.06),
      0.15,
      2.8,
      false,
      Paint()
        ..color = const Color(0xFF5D3A29)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.024
        ..strokeCap = StrokeCap.round,
    );

    // Kacamata opsional
    if (p.glasses) {
      final gp = Paint()
        ..color = const Color(0xFF0F172A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.022;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(w * 0.42, h * 0.42), width: w * 0.13, height: h * 0.09),
            Radius.circular(w * 0.02)),
        gp,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(
            Rect.fromCenter(center: Offset(w * 0.58, h * 0.42), width: w * 0.13, height: h * 0.09),
            Radius.circular(w * 0.02)),
        gp,
      );
      canvas.drawLine(Offset(w * 0.485, h * 0.42), Offset(w * 0.515, h * 0.42), gp);
    }

    // Rambut (0=rapih belah, 1=modern spike, 2=ikal, 3=topi pelatih, 4=abu veteran, 5=plontos)
    final hairColor = p.hairStyle == 4 ? const Color(0xFFCBD5E1) : const Color(0xFF1B1E23);
    final hp = Paint()..color = hairColor;
    switch (p.hairStyle % 6) {
      case 0:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.50, h * 0.31), width: w * 0.40, height: h * 0.26),
          3.14,
          3.14,
          true,
          hp,
        );
        break;
      case 1:
        final spike = Path()
          ..moveTo(w * 0.31, h * 0.34)
          ..lineTo(w * 0.36, h * 0.17)
          ..lineTo(w * 0.46, h * 0.22)
          ..lineTo(w * 0.52, h * 0.14)
          ..lineTo(w * 0.62, h * 0.21)
          ..lineTo(w * 0.69, h * 0.34)
          ..quadraticBezierTo(w * 0.50, h * 0.28, w * 0.31, h * 0.34)
          ..close();
        canvas.drawPath(spike, hp);
        break;
      case 2:
        for (final dx in [0.35, 0.43, 0.50, 0.57, 0.65]) {
          canvas.drawCircle(Offset(w * dx, h * 0.24), w * 0.07, hp);
        }
        break;
      case 3:
        // Topi pelatih
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.50, h * 0.31), width: w * 0.42, height: h * 0.25),
          3.14,
          3.14,
          true,
          Paint()..color = suit,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(w * 0.28, h * 0.29, w * 0.52, h * 0.05),
            Radius.circular(w * 0.025),
          ),
          Paint()..color = AppColors.primary,
        );
        break;
      case 4:
        canvas.drawArc(
          Rect.fromCenter(center: Offset(w * 0.50, h * 0.31), width: w * 0.40, height: h * 0.24),
          3.14,
          3.14,
          true,
          hp,
        );
        break;
      default:
        // Plontos rapi + kilau kecil
        canvas.drawCircle(
          Offset(w * 0.44, h * 0.27),
          w * 0.03,
          Paint()..color = Colors.white.withOpacity(0.22),
        );
        break;
    }

    // Ring bingkai lingkaran
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.49,
      Paint()
        ..color = AppColors.primary.withOpacity(0.65)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.035,
    );
  }

  @override
  bool shouldRepaint(covariant _ManagerAvatarPainter old) => true;
}

class PlayerAvatar extends StatelessWidget {
  final int seed;
  final Color jerseyColor;
  final double size;
  const PlayerAvatar({
    super.key,
    required this.seed,
    this.jerseyColor = AppColors.primary,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final p = ManagerProfile(
      name: '',
      hairStyle: seed % 3 == 0 ? 1 : (seed % 3 == 1 ? 2 : 0),
      skinTone: seed % ManagerAvatar.skinTones.length,
      outfitStyle: 2,
      suitColor: 0,
      beard: seed % 5 == 0,
      glasses: false,
    );
    return SizedBox(
      width: size,
      height: size,
      child: ClipOval(
        child: CustomPaint(
          painter: _PlayerAvatarPainter(p, jerseyColor),
        ),
      ),
    );
  }
}

class _PlayerAvatarPainter extends CustomPainter {
  final ManagerProfile p;
  final Color jersey;
  _PlayerAvatarPainter(this.p, this.jersey);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final skin = ManagerAvatar.skinTones[p.skinTone % ManagerAvatar.skinTones.length];
    canvas.drawRect(Offset.zero & size, Paint()..color = AppColors.surface2);

    // Jersey
    final body = Path()
      ..moveTo(w * 0.12, h)
      ..quadraticBezierTo(w * 0.16, h * 0.67, w * 0.5, h * 0.67)
      ..quadraticBezierTo(w * 0.84, h * 0.67, w * 0.88, h)
      ..close();
    canvas.drawPath(body, Paint()..color = jersey);
    canvas.drawCircle(Offset(w * 0.5, h * 0.44), w * 0.21, Paint()..color = skin);

    // Rambut
    final hp = Paint()..color = const Color(0xFF1F2937);
    if (p.hairStyle == 1) {
      final spike = Path()
        ..moveTo(w * 0.30, h * 0.36)
        ..lineTo(w * 0.40, h * 0.18)
        ..lineTo(w * 0.52, h * 0.15)
        ..lineTo(w * 0.65, h * 0.22)
        ..lineTo(w * 0.70, h * 0.36)
        ..close();
      canvas.drawPath(spike, hp);
    } else {
      canvas.drawArc(
        Rect.fromCenter(center: Offset(w * 0.5, h * 0.32), width: w * 0.42, height: h * 0.26),
        3.14,
        3.14,
        true,
        hp,
      );
    }
    final eye = Paint()..color = const Color(0xFF111827);
    canvas.drawCircle(Offset(w * 0.43, h * 0.43), w * 0.025, eye);
    canvas.drawCircle(Offset(w * 0.57, h * 0.43), w * 0.025, eye);
    canvas.drawCircle(
      Offset(w * 0.5, h * 0.5),
      w * 0.48,
      Paint()
        ..color = jersey.withOpacity(0.7)
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.04,
    );
  }

  @override
  bool shouldRepaint(covariant _PlayerAvatarPainter old) => old.jersey != jersey;
}

class PowerBadge extends StatelessWidget {
  final int poder;
  const PowerBadge(this.poder, {super.key});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Squads.powerColor(poder).withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Squads.powerColor(poder).withOpacity(0.6)),
      ),
      child: Text('$poder',
          style: TextStyle(
              color: Squads.powerColor(poder),
              fontWeight: FontWeight.w800,
              fontSize: 12)),
    );
  }
}

class PlayerRow extends StatelessWidget {
  final Player p;
  final VoidCallback? onTap;
  final Widget? trailing;
  const PlayerRow({super.key, required this.p, this.onTap, this.trailing});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor: Squads.positionColor(p.posid).withOpacity(0.2),
                  child: Text('${p.numero}',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                          color: Squads.positionColor(p.posid))),
                ),
                if (p.star == 1)
                  const Positioned(
                      right: 0,
                      top: 0,
                      child: Icon(Icons.star, size: 11, color: AppColors.gold)),
              ],
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(p.nombre,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                fontWeight: FontWeight.w700, fontSize: 13.8)),
                      ),
                      if (p.capitan == 1) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 13, color: AppColors.accent),
                      ],
                      if (p.titular == 1) ...[
                        const SizedBox(width: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 4, vertical: 1),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.16),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text('XI',
                              style: TextStyle(
                                  fontSize: 8.5,
                                  fontWeight: FontWeight.w900,
                                  color: AppColors.primary)),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                        decoration: BoxDecoration(
                            color: Squads.positionColor(p.posid).withOpacity(0.16),
                            borderRadius: BorderRadius.circular(4)),
                        child: Text(Squads.positionName(p.posid),
                            style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: Squads.positionColor(p.posid))),
                      ),
                      const SizedBox(width: 6),
                      Text('${p.edad} th',
                          style: const TextStyle(
                              fontSize: 11, color: AppColors.muted)),
                      const SizedBox(width: 6),
                      Container(
                        width: 22,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.surface2,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: FractionallySizedBox(
                          alignment: Alignment.centerLeft,
                          widthFactor: (p.condicion / 100).clamp(0.05, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: p.condicion >= 75
                                  ? AppColors.primary
                                  : p.condicion >= 50
                                      ? AppColors.accent
                                      : AppColors.danger,
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ),
                        ),
                      ),
                      if (p.lesionado) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.healing, size: 12, color: AppColors.danger),
                        Text(' ${p.lesionSemanas}m',
                            style: const TextStyle(
                                fontSize: 10, color: AppColors.danger)),
                      ],
                      if (p.suspendido) ...[
                        const SizedBox(width: 6),
                        const Icon(Icons.block, size: 12, color: Colors.orange),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                PowerBadge(p.poder),
                const SizedBox(height: 3),
                Text(formatMoney(p.valor),
                    style: const TextStyle(fontSize: 10, color: AppColors.muted)),
              ],
            ),
            if (trailing != null) ...[const SizedBox(width: 6), trailing!],
          ],
        ),
      ),
    );
  }
}

class StatBar extends StatelessWidget {
  final String label;
  final int value;
  const StatBar(this.label, this.value, {super.key});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
              width: 74,
              child: Text(label,
                  style: const TextStyle(fontSize: 11, color: AppColors.muted))),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: value / 100,
                minHeight: 7,
                backgroundColor: AppColors.surface2,
                valueColor: AlwaysStoppedAnimation(Squads.powerColor(value)),
              ),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
              width: 26,
              child: Text('$value',
                  textAlign: TextAlign.right,
                  style: const TextStyle(
                      fontSize: 11, fontWeight: FontWeight.w700))),
        ],
      ),
    );
  }
}

class FormationPainter extends CustomPainter {
  final Formation formation;
  final Color color;
  FormationPainter(this.formation, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final rect = RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(14));
    canvas.save();
    canvas.clipRRect(rect);

    // Rumput stadion bergaris (2 tone hijau)
    const bandCount = 10;
    final bandH = size.height / bandCount;
    for (var i = 0; i < bandCount; i++) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * bandH, size.width, bandH + 0.5),
        Paint()
          ..color = i.isEven
              ? const Color(0xFF0E3D26)
              : const Color(0xFF13482E),
      );
    }

    final line = Paint()
      ..color = Colors.white.withOpacity(0.22)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.4;
    canvas.drawRect(Rect.fromLTWH(10, 10, size.width - 20, size.height - 20), line);
    canvas.drawLine(Offset(10, size.height / 2),
        Offset(size.width - 10, size.height / 2), line);
    canvas.drawCircle(
        Offset(size.width / 2, size.height / 2), size.width * 0.12, line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), 2.5,
        Paint()..color = Colors.white.withOpacity(0.35));

    // Kotak penalti atas & bawah
    final boxW = size.width * 0.46, boxH = size.height * 0.14;
    canvas.drawRect(
        Rect.fromLTWH((size.width - boxW) / 2, 10, boxW, boxH), line);
    canvas.drawRect(
        Rect.fromLTWH((size.width - boxW) / 2, size.height - 10 - boxH, boxW, boxH),
        line);
    // Kotak kiper kecil
    final smallW = size.width * 0.24, smallH = size.height * 0.055;
    canvas.drawRect(
        Rect.fromLTWH((size.width - smallW) / 2, 10, smallW, smallH), line);
    canvas.drawRect(
        Rect.fromLTWH(
            (size.width - smallW) / 2, size.height - 10 - smallH, smallW, smallH),
        line);

    final dot = Paint()..color = color;
    for (final s in formation.slots) {
      final o = Offset(s[0] * size.width, s[1] * size.height);
      canvas.drawCircle(
          o + const Offset(0, 2), 11, Paint()..color = Colors.black.withOpacity(0.42));
      canvas.drawCircle(o, 10, dot);
      canvas.drawCircle(
          o,
          10,
          Paint()
            ..color = Colors.white.withOpacity(0.85)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.6);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant FormationPainter old) =>
      old.formation != formation || old.color != color;
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;
  const EmptyState({super.key, required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 42, color: AppColors.muted),
          const SizedBox(height: 10),
          Text(text,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 16, 14, 8),
      child: Row(
        children: [
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.4,
                    color: AppColors.muted)),
          ),
          const Spacer(),
          if (trailing != null)
            Flexible(
              child: Align(
                alignment: Alignment.centerRight,
                child: DefaultTextStyle.merge(
                  style: const TextStyle(fontSize: 11, color: AppColors.muted),
                  child: trailing!,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
