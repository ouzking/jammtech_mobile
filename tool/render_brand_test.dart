// Génère les images de marque (icônes de l'application) à partir du logo
// vectoriel. Lancer : flutter test tool/render_brand_test.dart
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jammtech/core/theme/app_colors.dart';
import 'package:jammtech/core/widgets/brand_logo.dart';

Future<void> _render(
  WidgetTester tester,
  Widget child,
  Size size,
  String path,
) async {
  final key = GlobalKey();
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: RepaintBoundary(
        key: key,
        child: SizedBox.fromSize(size: size, child: child),
      ),
    ),
  );
  await tester.runAsync(() async {
    final boundary =
        key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path)
      ..createSync(recursive: true)
      ..writeAsBytesSync(bytes!.buffer.asUint8List());
  });
}

void main() {
  testWidgets('icônes de marque', (tester) async {
    addTearDown(tester.view.reset);

    // Icône carrée pleine (iOS, Android ancienne génération, stores).
    await _render(
      tester,
      const ColoredBox(
        color: AppColors.background,
        child: Center(child: JammLogoMark(size: 600, glow: false)),
      ),
      const Size(1024, 1024),
      'assets/brand/app_icon_1024.png',
    );

    // Premier plan de l'icône adaptative Android : zone sûre ≈ 61 %.
    await _render(
      tester,
      const Center(child: JammLogoMark(size: 520, glow: false)),
      const Size(1024, 1024),
      'assets/brand/app_icon_foreground_1024.png',
    );

    // Emblème seul sur fond transparent (écran de lancement).
    await _render(
      tester,
      const Center(child: JammLogoMark(size: 652, glow: false)),
      const Size(652, 790),
      'assets/brand/logo_mark.png',
    );
  });
}
