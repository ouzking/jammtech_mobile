import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/utils/formatters.dart';
import '../../core/widgets/widgets.dart';
import '../../data/backend.dart';
import '../../data/models.dart';
import '../../data/repositories/contacts_repository.dart';
import '../../data/repositories/transport_repository.dart';
import '../../services/location_service.dart';
import '../app_page.dart';
import '../emergency_sheets.dart' show ContactAvatar;
import '../map.dart' show darkMapStyle;

class StartTripScreen extends StatefulWidget {
  const StartTripScreen({super.key});

  @override
  State<StartTripScreen> createState() => _StartTripScreenState();
}

class _StartTripScreenState extends State<StartTripScreen> {
  static const _durations = [10, 20, 30, 45, 60, 90];

  final _label = TextEditingController();
  final _plate = TextEditingController();
  final _note = TextEditingController();

  TripMode _mode = TripMode.taxi;
  int _minutes = 30;
  LatLng? _dest;
  LatLng _center = const LatLng(14.7167, -17.4677); // Dakar
  double? _accuracy;
  GoogleMapController? _map;
  Uint8List? _photo;
  late Set<String> _watchers = {
    for (final c in ContactsRepository.instance.contacts.value) c.id,
  };
  bool _starting = false;

  bool get _night {
    final h = DateTime.now().hour;
    return h >= 21 || h < 6;
  }

  DateTime get _eta => DateTime.now().add(Duration(minutes: _minutes));

  @override
  void initState() {
    super.initState();
    _locate();
    if (ContactsRepository.instance.contacts.value.isEmpty) {
      ContactsRepository.instance.refresh().then((c) {
        if (mounted) setState(() => _watchers = {for (final x in c) x.id});
      }).ignore();
    }
  }

  @override
  void dispose() {
    for (final c in [_label, _plate, _note]) {
      c.dispose();
    }
    _map?.dispose();
    super.dispose();
  }

  Future<void> _locate() async {
    try {
      final p = await LocationService.instance.currentPosition().timeout(
        const Duration(seconds: 4),
      );
      if (p == null || !mounted) return;
      setState(() {
        _center = LatLng(p.latitude, p.longitude);
        _accuracy = p.accuracy;
      });
      _map?.animateCamera(CameraUpdate.newLatLngZoom(_center, 14));
    } catch (_) {}
  }

  Future<void> _takePhoto() async {
    try {
      final x = await ImagePicker().pickImage(
        source: ImageSource.camera,
        maxWidth: 1000,
        imageQuality: 70,
      );
      if (x == null) return;
      final bytes = await x.readAsBytes();
      if (mounted) setState(() => _photo = bytes);
    } catch (_) {
      if (mounted) _error('Appareil photo indisponible.');
    }
  }

  void _error(String m) => showAppSnack(
    context,
    m,
    icon: Icons.error_outline_rounded,
    color: AppColors.danger,
  );

  /// « dk 1234 ab » → « DK1234AB ».
  String _normalizedPlate() =>
      _plate.text.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');

  Future<void> _start() async {
    FocusScope.of(context).unfocus();
    if (_dest == null) {
      HapticFeedback.heavyImpact();
      _error('Touchez la carte pour placer votre destination.');
      return;
    }
    if (_label.text.trim().isEmpty) {
      HapticFeedback.heavyImpact();
      _error('Donnez un nom à votre destination.');
      return;
    }
    setState(() => _starting = true);
    try {
      final trip = await TransportRepository.instance.start(
        mode: _mode,
        destinationLabel: _label.text.trim(),
        destLat: _dest!.latitude,
        destLng: _dest!.longitude,
        expectedArrival: _eta,
        watcherIds: _watchers.isEmpty ? null : _watchers.toList(),
        plate: _mode.hasDriver ? _normalizedPlate() : null,
        note: _note.text.trim(),
        lat: _center.latitude,
        lng: _center.longitude,
        accuracy: _accuracy,
        night: _night,
      );
      if (_photo != null) {
        TransportRepository.instance
            .attachVehiclePhoto(trip.id, _photo!)
            .ignore();
      }
      HapticFeedback.heavyImpact();
      if (!mounted) return;
      showAppSnack(
        context,
        'Trajet démarré : vos proches vous suivent.',
        icon: Icons.route_rounded,
      );
      Navigator.pop(context);
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _starting = false);
      _error(e.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final contacts = ContactsRepository.instance.contacts.value;

    return AppPage(
      title: 'Nouveau trajet',
      subtitle: 'Vos proches suivront votre trajet en direct',
      slivers: [
        // Mode
        PageSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GroupLabel('Je voyage en'),
              GridView.count(
                crossAxisCount: 3,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: Gap.xs,
                crossAxisSpacing: Gap.xs,
                childAspectRatio: 1.25,
                children: [
                  for (final m in TripMode.values)
                    _ModeTile(
                      mode: m,
                      selected: m == _mode,
                      onTap: () => setState(() => _mode = m),
                    ),
                ],
              ),
            ],
          ),
        ),

        // Destination
        PageSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GroupLabel('Destination'),
              AppTextField(
                controller: _label,
                label: 'Où allez-vous ? (ex. Maison, Mermoz)',
                icon: Icons.place_outlined,
                textCapitalization: TextCapitalization.sentences,
              ),
              const SizedBox(height: Gap.sm),
              ClipRRect(
                borderRadius: Radii.lgAll,
                child: SizedBox(
                  height: 220,
                  child: Stack(
                    children: [
                      GoogleMap(
                        initialCameraPosition: CameraPosition(
                          target: _center,
                          zoom: 13,
                        ),
                        style: darkMapStyle,
                        myLocationEnabled: true,
                        myLocationButtonEnabled: false,
                        zoomControlsEnabled: false,
                        mapToolbarEnabled: false,
                        onMapCreated: (c) => _map = c,
                        onTap: (p) {
                          HapticFeedback.selectionClick();
                          setState(() => _dest = p);
                        },
                        markers: {
                          if (_dest != null)
                            Marker(
                              markerId: const MarkerId('dest'),
                              position: _dest!,
                            ),
                        },
                      ),
                      if (_dest == null)
                        Positioned(
                          left: Gap.sm,
                          right: Gap.sm,
                          bottom: Gap.sm,
                          child: IgnorePointer(
                            child: Container(
                              padding: const EdgeInsets.all(Gap.sm),
                              decoration: BoxDecoration(
                                color: AppColors.background.withValues(
                                  alpha: 0.85,
                                ),
                                borderRadius: Radii.smAll,
                              ),
                              child: Text(
                                'Touchez la carte pour placer votre destination',
                                textAlign: TextAlign.center,
                                style: t.bodySmall,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        // Durée
        PageSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GroupLabel('Durée estimée'),
              Wrap(
                spacing: Gap.xs,
                runSpacing: Gap.xs,
                children: [
                  for (final d in _durations)
                    ChoiceChip(
                      label: Text(
                        d < 60
                            ? '$d min'
                            : '${d ~/ 60} h${d % 60 == 0 ? '' : ' ${d % 60}'}',
                      ),
                      selected: d == _minutes,
                      onSelected: (_) => setState(() => _minutes = d),
                    ),
                ],
              ),
              const SizedBox(height: Gap.sm),
              Text(
                'Arrivée prévue vers ${clock(_eta)}. Sans nouvelles 15 min plus '
                'tard, nous vous demanderons si tout va bien.',
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),

        // Véhicule
        if (_mode.hasDriver)
          PageSection(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const GroupLabel('Véhicule (recommandé)'),
                AppTextField(
                  controller: _plate,
                  label: 'Plaque (ex. DK-1234-AB)',
                  icon: Icons.pin_outlined,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: [LengthLimitingTextInputFormatter(14)],
                ),
                const SizedBox(height: Gap.sm),
                AppTextField(
                  controller: _note,
                  label: 'Détail (ex. taxi jaune, moto rouge)',
                  icon: Icons.notes_rounded,
                  textCapitalization: TextCapitalization.sentences,
                ),
                const SizedBox(height: Gap.sm),
                AppCard(
                  onTap: _takePhoto,
                  color: AppColors.surfaceHigh,
                  child: Row(
                    children: [
                      _photo == null
                          ? const IconBadge(
                              icon: Icons.photo_camera_outlined,
                              color: AppColors.info,
                            )
                          : ClipRRect(
                              borderRadius: Radii.smAll,
                              child: Image.memory(
                                _photo!,
                                width: 44,
                                height: 44,
                                fit: BoxFit.cover,
                              ),
                            ),
                      const SizedBox(width: Gap.md),
                      Expanded(
                        child: Text(
                          _photo == null
                              ? 'Photographier le véhicule'
                              : 'Photo ajoutée · toucher pour reprendre',
                          style: t.titleSmall,
                        ),
                      ),
                      const Icon(
                        Icons.chevron_right_rounded,
                        color: AppColors.textTertiary,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

        // Proches
        PageSection(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const GroupLabel('Proches qui me suivent'),
              if (contacts.isEmpty)
                Text(
                  'Aucun contact de confiance : ajoutez-en depuis votre profil.',
                  style: t.bodyMedium?.copyWith(color: AppColors.warning),
                )
              else
                SettingsGroup(
                  children: [
                    for (final c in contacts)
                      CheckboxListTile(
                        value: _watchers.contains(c.id),
                        onChanged: (v) => setState(
                          () => v == true
                              ? _watchers.add(c.id)
                              : _watchers.remove(c.id),
                        ),
                        secondary: ContactAvatar(contact: c, size: 38),
                        title: Text(c.name, style: t.titleSmall),
                        subtitle: Text(
                          c.hasApp ? 'Suivi dans l’app' : 'Suivi par SMS',
                          style: t.bodySmall?.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                  ],
                ),
              if (_night) ...[
                const SizedBox(height: Gap.md),
                AppCard(
                  color: AppColors.violet.withValues(alpha: 0.1),
                  borderColor: AppColors.violet.withValues(alpha: 0.3),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.nights_stay_rounded,
                        color: AppColors.violet,
                      ),
                      const SizedBox(width: Gap.sm),
                      Expanded(
                        child: Text(
                          'Trajet de nuit : vérifications plus rapprochées.',
                          style: t.bodySmall,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),

        PageSection(
          child: AppButton(
            label: 'Démarrer le trajet',
            icon: Icons.play_arrow_rounded,
            loading: _starting,
            onPressed: _start,
          ),
        ),
      ],
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final TripMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      semanticLabel: mode.label,
      child: AnimatedContainer(
        duration: Motion.fast,
        decoration: BoxDecoration(
          color: selected
              ? AppColors.brand.withValues(alpha: 0.18)
              : AppColors.surface,
          borderRadius: Radii.mdAll,
          border: Border.all(
            color: selected ? AppColors.brand : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              mode.icon,
              color: selected ? AppColors.brandBright : AppColors.textSecondary,
            ),
            const SizedBox(height: 4),
            Text(
              mode.label,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected
                    ? AppColors.textPrimary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
