import 'package:flutter/material.dart';

import '../core/widgets/widgets.dart';
import '../routes.dart';

class _Slide {
  const _Slide(this.icon, this.color, this.eyebrow, this.title, this.body);

  final IconData icon;
  final Color color;
  final String eyebrow;
  final String title;
  final String body;
}

const _slides = [
  _Slide(
    Icons.shield_rounded,
    AppColors.brand,
    'PROTECTION 24/7',
    'Votre sécurité,\nsans compromis',
    'Surveillez votre maison et protégez vos proches depuis une seule '
        'application, où que vous soyez.',
  ),
  _Slide(
    Icons.near_me_rounded,
    AppColors.success,
    'LOCALISATION EN DIRECT',
    'Toujours\nà portée de vue',
    'Partagez votre position en temps réel avec vos contacts de confiance '
        'en un geste.',
  ),
  _Slide(
    Icons.sos_rounded,
    AppColors.danger,
    'ALERTE SOS',
    'Une aide immédiate\nen 3 secondes',
    'Maintenez le bouton SOS : vos proches reçoivent votre position et les '
        'secours sont à un appel.',
  ),
];

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _controller = PageController();
  int _index = 0;

  bool get _isLast => _index == _slides.length - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _finish() => Navigator.pushReplacementNamed(context, AppRoutes.login);

  void _next() {
    if (_isLast) return _finish();
    _controller.nextPage(duration: Motion.slow, curve: Motion.emphasized);
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_index];
    return Scaffold(
      body: AppBackground(
        glow: slide.color,
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(Gap.page, Gap.xs, Gap.xs, 0),
                child: Row(
                  children: [
                    const BrandMark(size: 32),
                    const SizedBox(width: Gap.sm),
                    Text(
                      'JammTech',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Spacer(),
                    AnimatedOpacity(
                      opacity: _isLast ? 0 : 1,
                      duration: Motion.medium,
                      child: TextButton(
                        onPressed: _isLast ? null : _finish,
                        child: const Text(
                          'Passer',
                          style: TextStyle(color: AppColors.textSecondary),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: PageView.builder(
                  controller: _controller,
                  itemCount: _slides.length,
                  onPageChanged: (i) => setState(() => _index = i),
                  itemBuilder: (_, i) => _SlideView(slide: _slides[i]),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  Gap.page,
                  0,
                  Gap.page,
                  Gap.xl,
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: List.generate(_slides.length, (i) {
                        final active = i == _index;
                        return AnimatedContainer(
                          duration: Motion.medium,
                          curve: Motion.emphasized,
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          width: active ? 28 : 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? slide.color
                                : AppColors.surfaceHighest,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        );
                      }),
                    ),
                    const SizedBox(height: Gap.xl),
                    AppButton(
                      label: _isLast ? 'Commencer' : 'Continuer',
                      icon: _isLast ? null : Icons.arrow_forward_rounded,
                      onPressed: _next,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});

  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return LayoutBuilder(
      builder: (context, c) {
        // L'illustration s'adapte aux petits écrans et au mode paysage.
        final art = (c.maxHeight * 0.45).clamp(0.0, 240.0);
        return SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: Gap.page + 8),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: c.maxHeight),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (art >= 120)
                  Center(
                    child: _Illustration(
                      icon: slide.icon,
                      color: slide.color,
                      size: art,
                    ),
                  ),
                SizedBox(height: art >= 120 ? Gap.xxl : 0),
                ..._text(t),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _text(TextTheme t) {
    return [
      Text(slide.eyebrow, style: t.labelSmall?.copyWith(color: slide.color)),
      const SizedBox(height: Gap.sm),
      Text(slide.title, style: t.headlineMedium),
      const SizedBox(height: Gap.md),
      Text(
        slide.body,
        style: t.bodyLarge?.copyWith(color: AppColors.textSecondary),
      ),
    ];
  }
}

/// Anneaux concentriques autour d'une icône — illustration vectorielle légère.
class _Illustration extends StatelessWidget {
  const _Illustration({
    required this.icon,
    required this.color,
    this.size = 240,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.85, end: 1),
      duration: Motion.slow,
      curve: Curves.easeOutBack,
      builder: (_, v, child) => Transform.scale(scale: v, child: child),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            for (final (f, alpha) in [(1.0, 0.05), (0.75, 0.09), (0.52, 0.16)])
              Container(
                width: size * f,
                height: size * f,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: alpha),
                  border: Border.all(
                    color: color.withValues(alpha: alpha + 0.08),
                  ),
                ),
              ),
            Container(
              width: 84,
              height: 84,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(color, Colors.white, 0.25)!, color],
                ),
                boxShadow: [
                  BoxShadow(
                    color: color.withValues(alpha: 0.55),
                    blurRadius: 36,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Icon(icon, size: 40, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }
}
