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
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [_parse(colorA), _parse(colorA).withOpacity(0.72)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: _parse(colorB).withOpacity(0.8), width: 1.4),
      ),
      alignment: Alignment.center,
      child: Text(initials,
          style: TextStyle(
              fontSize: size * 0.36,
              fontWeight: FontWeight.w900,
              color: Colors.white)),
    );
  }
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
                                fontWeight: FontWeight.w600, fontSize: 14)),
                      ),
                      if (p.capitan == 1) ...[
                        const SizedBox(width: 4),
                        const Icon(Icons.verified, size: 13, color: AppColors.accent),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                        decoration: BoxDecoration(
                            color: Squads.positionColor(p.posid).withOpacity(0.15),
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
    final pitch = Paint()..color = const Color(0xFF12402B);
    canvas.drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)), pitch);
    final line = Paint()
      ..color = Colors.white.withOpacity(0.14)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawRect(Rect.fromLTWH(6, 6, size.width - 12, size.height - 12), line);
    canvas.drawLine(Offset(6, size.height / 2),
        Offset(size.width - 6, size.height / 2), line);
    canvas.drawCircle(Offset(size.width / 2, size.height / 2), size.width * 0.11, line);
    // kotak penalti
    final boxW = size.width * 0.44, boxH = size.height * 0.14;
    canvas.drawRect(
        Rect.fromLTWH((size.width - boxW) / 2, 6, boxW, boxH), line);
    canvas.drawRect(
        Rect.fromLTWH((size.width - boxW) / 2, size.height - 6 - boxH, boxW, boxH),
        line);

    final dot = Paint()..color = color;
    for (final s in formation.slots) {
      final o = Offset(s[0] * size.width, s[1] * size.height);
      canvas.drawCircle(o, 9, Paint()..color = Colors.black.withOpacity(0.35));
      canvas.drawCircle(o, 7.5, dot);
      canvas.drawCircle(
          o,
          7.5,
          Paint()
            ..color = Colors.white.withOpacity(0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2);
    }
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
