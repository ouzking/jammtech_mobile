import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/widgets/widgets.dart';
import '../data/demo_data.dart';
import 'alerts.dart';
import 'home.dart';
import 'map.dart';
import 'profile.dart';
import 'smart_home.dart';

enum AppTab { home, map, alerts, smartHome, profile }

/// Coquille principale : navigation par onglets, état de chaque onglet conservé.
class MainShell extends StatefulWidget {
  const MainShell({super.key, this.initialTab = AppTab.home});

  final AppTab initialTab;

  /// Permet à un écran enfant de changer d'onglet. `null` hors de la coquille.
  static MainShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<MainShellState>();

  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  late AppTab _tab = widget.initialTab;

  /// Onglets déjà visités : construits une seule fois, à la demande
  /// (la carte ne demande la localisation qu'à la première ouverture).
  late final Set<AppTab> _visited = {_tab};

  void goTo(AppTab tab) {
    if (tab == _tab) return;
    HapticFeedback.selectionClick();
    setState(() {
      _tab = tab;
      _visited.add(tab);
    });
  }

  Widget _build(AppTab tab) => switch (tab) {
    AppTab.home => const HomeScreen(),
    AppTab.map => const MapScreen(),
    AppTab.alerts => const AlertsScreen(),
    AppTab.smartHome => const SmartHomeScreen(),
    AppTab.profile => const ProfileScreen(),
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: DemoData.alertsRevision,
      builder: (context, _, _) => _buildScaffold(DemoData.unresolvedCount),
    );
  }

  Widget _buildScaffold(int unread) {
    return PopScope(
      canPop: _tab == AppTab.home,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) goTo(AppTab.home);
      },
      child: Scaffold(
        extendBody: true,
        body: IndexedStack(
          index: _tab.index,
          children: [
            for (final t in AppTab.values)
              _TabSlot(
                active: t == _tab,
                child: _visited.contains(t)
                    ? _build(t)
                    : const SizedBox.shrink(),
              ),
          ],
        ),
        bottomNavigationBar: DecoratedBox(
          decoration: const BoxDecoration(
            border: Border(top: BorderSide(color: AppColors.border)),
          ),
          child: NavigationBar(
            selectedIndex: _tab.index,
            onDestinationSelected: (i) => goTo(AppTab.values[i]),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded),
                label: 'Accueil',
              ),
              const NavigationDestination(
                icon: Icon(Icons.map_outlined),
                selectedIcon: Icon(Icons.map_rounded),
                label: 'Carte',
              ),
              NavigationDestination(
                icon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  backgroundColor: AppColors.danger,
                  child: const Icon(Icons.notifications_none_rounded),
                ),
                selectedIcon: Badge(
                  isLabelVisible: unread > 0,
                  label: Text('$unread'),
                  backgroundColor: AppColors.danger,
                  child: const Icon(Icons.notifications_rounded),
                ),
                label: 'Alertes',
              ),
              const NavigationDestination(
                icon: Icon(Icons.home_outlined),
                selectedIcon: Icon(Icons.home_rounded),
                label: 'Maison',
              ),
              const NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Profil',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fondu d'entrée à l'activation d'un onglet ; les animations des onglets
/// masqués sont mises en pause pour économiser la batterie.
class _TabSlot extends StatelessWidget {
  const _TabSlot({required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TickerMode(
      enabled: active,
      child: AnimatedOpacity(
        opacity: active ? 1 : 0,
        duration: Motion.medium,
        curve: Motion.standard,
        child: AnimatedSlide(
          offset: active ? Offset.zero : const Offset(0, 0.015),
          duration: Motion.medium,
          curve: Motion.emphasized,
          child: child,
        ),
      ),
    );
  }
}
