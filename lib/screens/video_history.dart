import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/backend.dart';
import '../data/models.dart';
import '../data/repositories/account_repository.dart';
import '../data/repositories/recordings_repository.dart';
import 'app_page.dart';

class VideoHistoryScreen extends StatefulWidget {
  const VideoHistoryScreen({super.key});

  @override
  State<VideoHistoryScreen> createState() => _VideoHistoryScreenState();
}

class _VideoHistoryScreenState extends State<VideoHistoryScreen> {
  final _repo = RecordingsRepository.instance;
  List<VideoRecord> _videos = const [];
  bool _loading = true;
  bool _motionOnly = false;

  String? get _homeId => AccountRepository.instance.dashboard.value?.homeId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final v = await _repo.list(_homeId);
      if (mounted) setState(() => _videos = v);
    } on AppException catch (e) {
      if (mounted) _error(e.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _error(String m) => showAppSnack(
    context,
    m,
    icon: Icons.error_outline_rounded,
    color: AppColors.danger,
  );

  Future<void> _delete(VideoRecord v) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer la vidéo ?',
      message: '« ${v.title} » sera définitivement supprimée.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final before = _videos;
    setState(() => _videos = [..._videos]..remove(v));
    try {
      await _repo.delete(v);
      if (mounted) {
        showAppSnack(
          context,
          'Vidéo supprimée',
          icon: Icons.delete_outline_rounded,
          color: AppColors.textSecondary,
        );
      }
    } on AppException catch (e) {
      if (!mounted) return;
      setState(() => _videos = before);
      _error(e.message);
    }
  }

  /// Respecte le réglage « vidéos en Wi-Fi uniquement ».
  Future<bool> _allowedToStream() async {
    try {
      final settings = await AccountRepository.instance.settings();
      if (settings['videos_wifi_only'] != true) return true;
      final c = await Connectivity().checkConnectivity();
      if (c.contains(ConnectivityResult.wifi) ||
          c.contains(ConnectivityResult.ethernet)) {
        return true;
      }
      if (!mounted) return false;
      return confirmAction(
        context,
        title: 'Lecture sur données mobiles ?',
        message:
            'Vous avez choisi « vidéos en Wi-Fi uniquement ». '
            'Lire quand même cette vidéo avec votre forfait ?',
        confirmLabel: 'Lire',
      );
    } catch (_) {
      return true;
    }
  }

  Future<void> _play(VideoRecord v) async {
    if (!await _allowedToStream() || !mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _PlayerSheet(video: v),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = _motionOnly
        ? _videos.where((v) => v.motion).toList()
        : _videos;

    // Regroupement par jour, dans l'ordre chronologique inverse.
    final groups = <String, List<VideoRecord>>{};
    for (final v in items) {
      groups.putIfAbsent(dayLabel(v.time), () => []).add(v);
    }

    return AppPage(
      title: 'Enregistrements',
      subtitle: _loading
          ? 'Chargement…'
          : '${_videos.length} vidéo${_videos.length > 1 ? 's' : ''} · conservées 30 jours',
      glow: AppColors.violet,
      onRefresh: _load,
      slivers: [
        PageSection(
          bottom: Gap.md,
          child: Row(
            children: [
              ChoiceChip(
                label: const Text('Toutes'),
                selected: !_motionOnly,
                onSelected: (_) => setState(() => _motionOnly = false),
              ),
              const SizedBox(width: Gap.xs),
              ChoiceChip(
                avatar: const Icon(Icons.directions_run_rounded, size: 16),
                label: const Text('Mouvements'),
                selected: _motionOnly,
                onSelected: (_) => setState(() => _motionOnly = true),
              ),
            ],
          ),
        ),
        if (_loading)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: Center(child: CircularProgressIndicator()),
          )
        else if (items.isEmpty)
          const SliverFillRemaining(
            hasScrollBody: false,
            child: EmptyState(
              icon: Icons.videocam_off_outlined,
              title: 'Aucun enregistrement',
              message: 'Les vidéos capturées par vos caméras apparaîtront ici.',
            ),
          )
        else
          for (final entry in groups.entries) ...[
            PageSection(bottom: 0, child: GroupLabel(entry.key)),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.sm),
              sliver: SliverList.separated(
                itemCount: entry.value.length,
                separatorBuilder: (_, _) => const SizedBox(height: Gap.md),
                itemBuilder: (_, i) {
                  final v = entry.value[i];
                  return _VideoCard(
                    video: v,
                    onPlay: () => _play(v),
                    onDelete: () => _delete(v),
                  );
                },
              ),
            ),
          ],
      ],
    );
  }
}

/// Lecteur : URL signée valable 5 minutes, demandée à l'ouverture.
class _PlayerSheet extends StatefulWidget {
  const _PlayerSheet({required this.video});

  final VideoRecord video;

  @override
  State<_PlayerSheet> createState() => _PlayerSheetState();
}

class _PlayerSheetState extends State<_PlayerSheet> {
  VideoPlayerController? _player;
  String? _message;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    try {
      final url = await RecordingsRepository.instance.signedUrl(
        widget.video.storagePath,
      );
      if (url == null) {
        setState(() => _message = 'Vidéo de démonstration : aucun fichier.');
        return;
      }
      final p = VideoPlayerController.networkUrl(Uri.parse(url));
      await p.initialize();
      if (!mounted) return p.dispose();
      setState(() => _player = p);
      p.play();
    } catch (e) {
      if (mounted) {
        setState(() => _message = toAppException(e).message);
      }
    }
  }

  @override
  void dispose() {
    _player?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final v = widget.video;
    final p = _player;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ClipRRect(
              borderRadius: Radii.lgAll,
              child: p != null
                  ? AspectRatio(
                      aspectRatio: p.value.aspectRatio,
                      child: GestureDetector(
                        onTap: () => setState(
                          () => p.value.isPlaying ? p.pause() : p.play(),
                        ),
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(p),
                            VideoProgressIndicator(
                              p,
                              allowScrubbing: true,
                              colors: const VideoProgressColors(
                                playedColor: AppColors.brand,
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  : Stack(
                      alignment: Alignment.center,
                      children: [
                        _Thumbnail(video: v, large: true),
                        if (_message == null) const CircularProgressIndicator(),
                      ],
                    ),
            ),
            const SizedBox(height: Gap.lg),
            Text(v.title, style: t.titleLarge),
            const SizedBox(height: 4),
            Text(
              '${v.camera} · ${dayLabel(v.time)} à ${clock(v.time)} · ${duration(v.duration)}',
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            if (_message != null) ...[
              const SizedBox(height: Gap.md),
              Text(
                _message!,
                style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _VideoCard extends StatelessWidget {
  const _VideoCard({
    required this.video,
    required this.onPlay,
    required this.onDelete,
  });

  final VideoRecord video;
  final VoidCallback onPlay;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return AppCard(
      padding: EdgeInsets.zero,
      radius: Radii.xlAll,
      child: Column(
        children: [
          Pressable(
            onTap: onPlay,
            child: _Thumbnail(video: video),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(Gap.md, Gap.sm, Gap.xs, Gap.sm),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(video.title, style: t.titleSmall),
                      const SizedBox(height: 2),
                      Text(
                        '${video.camera} · ${clock(video.time)}',
                        style: t.bodySmall?.copyWith(
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Supprimer',
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline_rounded,
                    color: AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({required this.video, this.large = false});

  final VideoRecord video;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final radius = large
        ? Radii.lgAll
        : const BorderRadius.vertical(top: Radius.circular(Radii.xl));
    return ClipRRect(
      borderRadius: radius,
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color.lerp(
                      AppColors.surfaceHighest,
                      AppColors.violet,
                      0.12,
                    )!,
                    const Color(0xFF05080F),
                  ],
                ),
              ),
            ),
            Center(
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white.withValues(alpha: 0.14),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
            ),
            if (video.motion)
              const Positioned(
                top: Gap.sm,
                left: Gap.sm,
                child: StatusPill(label: 'Mouvement', color: AppColors.warning),
              ),
            Positioned(
              bottom: Gap.sm,
              right: Gap.sm,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  duration(video.duration),
                  style: t.labelMedium?.copyWith(color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
