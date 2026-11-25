import 'package:flutter/material.dart';

import '../../core/widgets/widgets.dart';
import '../../data/backend.dart';

/// Réglages stockés côté serveur : chargement initial, mise à jour optimiste
/// de chaque interrupteur, retour arrière et message en cas d'échec.
mixin ServerPrefs<T extends StatefulWidget> on State<T> {
  Map<String, dynamic> prefs = {};
  bool prefsLoading = true;

  Future<Map<String, dynamic>> loadPrefs();
  Future<void> savePrefs(Map<String, dynamic> values);

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final p = await loadPrefs();
      if (mounted) setState(() => prefs = p);
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    } finally {
      if (mounted) setState(() => prefsLoading = false);
    }
  }

  bool flag(String key) => prefs[key] == true;

  Future<void> setPref(String key, Object? value) async {
    final previous = prefs[key];
    setState(() => prefs[key] = value);
    try {
      await savePrefs({key: value});
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => prefs[key] = previous);
      _error(e.message);
    }
  }

  void _error(String m) => showAppSnack(
    context,
    m,
    icon: Icons.error_outline_rounded,
    color: AppColors.danger,
  );
}
