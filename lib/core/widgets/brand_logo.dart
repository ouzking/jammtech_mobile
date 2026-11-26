import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

/// Emblème JammTech (bouclier, toit, « J » et barres de vitesse), dessiné en
/// vectoriel d'après assets/brand/logo_banner.png : net à toutes les tailles.
///
/// [size] est la largeur ; la hauteur suit le ratio du bouclier.
class JammLogoMark extends StatelessWidget {
  const JammLogoMark({super.key, this.size = 72, this.glow = true});

  final double size;

  /// Halo bleu sous l'emblème (désactivé pour les icônes plates).
  final bool glow;

  static const aspect = 790 / 652;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'JammTech',
      image: true,
      child: SizedBox(
        width: size,
        height: size * aspect,
        child: CustomPaint(painter: _MarkPainter(glow: glow)),
      ),
    );
  }
}

class _MarkPainter extends CustomPainter {
  _MarkPainter({required this.glow});

  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset p(double x, double y) => Offset(x * w, y * h);

    // Bouclier
    final shield = Path()
      ..moveTo(0.5 * w, 0)
      ..lineTo(w, 0.2456 * h)
      ..lineTo(w, 0.60 * h)
      ..cubicTo(w, 0.82 * h, 0.72 * w, 0.92 * h, 0.5 * w, h)
      ..cubicTo(0.28 * w, 0.92 * h, 0, 0.82 * h, 0, 0.60 * h)
      ..lineTo(0, 0.2456 * h)
      ..close();

    if (glow) {
      canvas.drawPath(
        shield.shift(Offset(0, h * 0.04)),
        Paint()
          ..color = AppColors.brand.withValues(alpha: 0.45)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.12),
      );
    }
    canvas.drawPath(shield, Paint()..color = AppColors.brand);

    final white = Paint()..color = Colors.white;

    // Toit (chevron)
    canvas.drawPath(
      Path()
        ..moveTo(p(0.221, 0.296).dx, p(0.221, 0.296).dy)
        ..lineTo(p(0.5, 0.162).dx, p(0.5, 0.162).dy)
        ..lineTo(p(0.779, 0.296).dx, p(0.779, 0.296).dy),
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.066 * w
        ..strokeJoin = StrokeJoin.miter
        ..strokeCap = StrokeCap.butt,
    );

    // Barres de vitesse (transport)
    canvas.drawRect(Rect.fromPoints(p(0.141, 0.405), p(0.482, 0.463)), white);
    canvas.drawRect(
      Rect.fromPoints(p(0.242, 0.522), p(0.482, 0.580)),
      Paint()..color = AppColors.brandMist,
    );

    // « J » : jambage + crochet en demi-anneau
    final c = Offset(0.4617 * w, 0.6456 * h);
    final outer = 0.2239 * w;
    final inner = 0.0905 * w;
    // Le jambage est aligné exactement sur le demi-anneau (pas de cran).
    final j = Path()
      ..moveTo(c.dx + inner, 0.397 * h)
      ..lineTo(c.dx + outer, 0.397 * h)
      ..lineTo(c.dx + outer, c.dy)
      ..arcTo(Rect.fromCircle(center: c, radius: outer), 0, 3.14159265, false)
      ..lineTo(c.dx - inner, c.dy)
      ..arcTo(
        Rect.fromCircle(center: c, radius: inner),
        3.14159265,
        -3.14159265,
        false,
      )
      ..close();
    canvas.drawPath(j, white);
  }

  @override
  bool shouldRepaint(_MarkPainter old) => old.glow != glow;
}

/// Logotype « JAMMTECH » (JAMM en gras blanc, TECH fin en bleu clair),
/// avec la signature « TRANSPORT · MAISON · SÉCURITÉ ».
class JammWordmark extends StatelessWidget {
  const JammWordmark({super.key, this.fontSize = 34, this.tagline = true});

  final double fontSize;
  final bool tagline;

  @override
  Widget build(BuildContext context) {
    final base = Theme.of(context).textTheme.displaySmall;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'JAMM',
                style: base?.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w800,
                  letterSpacing: fontSize * 0.02,
                  color: Colors.white,
                ),
              ),
              TextSpan(
                text: 'TECH',
                style: base?.copyWith(
                  fontSize: fontSize,
                  fontWeight: FontWeight.w300,
                  letterSpacing: fontSize * 0.02,
                  color: AppColors.brandBright,
                ),
              ),
            ],
          ),
        ),
        if (tagline) ...[
          SizedBox(height: fontSize * 0.28),
          Text(
            'TRANSPORT · MAISON · SÉCURITÉ',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              fontSize: (fontSize * 0.3).clamp(9, 14),
              letterSpacing: fontSize * 0.11,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ],
    );
  }
}

/// Logo horizontal complet (emblème + logotype), comme sur la bannière.
class JammLogo extends StatelessWidget {
  const JammLogo({super.key, this.height = 48, this.tagline = false});

  final double height;
  final bool tagline;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        JammLogoMark(size: height / JammLogoMark.aspect, glow: false),
        SizedBox(width: height * 0.32),
        JammWordmark(fontSize: height * 0.52, tagline: tagline),
      ],
    );
  }
}
