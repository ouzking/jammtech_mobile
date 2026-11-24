import 'dart:async';

import 'package:flutter/material.dart';

import '../core/widgets/widgets.dart';
import '../routes.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2200),
  )..forward();

  late final _logoScale = Tween(begin: 0.6, end: 1.0).animate(
    CurvedAnimation(
      parent: _c,
      curve: const Interval(0, 0.5, curve: Curves.easeOutBack),
    ),
  );
  late final _logoFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0, 0.35, curve: Curves.easeOut),
  );
  late final _textFade = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.3, 0.65, curve: Curves.easeOut),
  );
  late final _progress = CurvedAnimation(
    parent: _c,
    curve: const Interval(0.35, 1, curve: Curves.easeInOutCubic),
  );

  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 2600), () {
      if (mounted) {
        Navigator.pushReplacementNamed(context, AppRoutes.onboarding);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: AppBackground(
        child: SafeArea(
          child: Column(
            children: [
              const Spacer(flex: 3),
              FadeTransition(
                opacity: _logoFade,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: const BrandMark(size: 104),
                ),
              ),
              const SizedBox(height: Gap.xl),
              FadeTransition(
                opacity: _textFade,
                child: SlideTransition(
                  position: Tween(
                    begin: const Offset(0, 0.3),
                    end: Offset.zero,
                  ).animate(_textFade),
                  child: Column(
                    children: [
                      Text('JammTech', style: t.displaySmall),
                      const SizedBox(height: Gap.xs),
                      Text(
                        'La paix dans votre poche',
                        style: t.bodyLarge?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(flex: 3),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: AnimatedBuilder(
                    animation: _progress,
                    builder: (_, _) => LinearProgressIndicator(
                      value: _progress.value,
                      minHeight: 3,
                      backgroundColor: AppColors.surfaceHigh,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: Gap.md),
              Text(
                'SÉCURITÉ PERSONNELLE · MAISON CONNECTÉE',
                style: t.labelSmall?.copyWith(color: AppColors.textTertiary),
              ),
              const SizedBox(height: Gap.xl),
            ],
          ),
        ),
      ),
    );
  }
}
