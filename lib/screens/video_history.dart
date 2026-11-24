import 'package:flutter/material.dart';

import '../core/utils/formatters.dart';
import '../core/widgets/widgets.dart';
import '../data/demo_data.dart';
import '../data/models.dart';
import 'app_page.dart';

class VideoHistoryScreen extends StatefulWidget {
  const VideoHistoryScreen({super.key});

  @override
  State<VideoHistoryScreen> createState() => _VideoHistoryScreenState();
}

class _VideoHistoryScreenState extends State<VideoHistoryScreen> {
  // TODO: remplacer par le stockage distant (Firebase / API).
  final _videos = List<VideoRecord>.of(DemoData.videos);
  bool _motionOnly = false;

  Future<void> _delete(VideoRecord v) async {
    final ok = await confirmAction(
      context,
      title: 'Supprimer la vidéo ?',
      message: '« ${v.title} » sera définitivement supprimée.',
      confirmLabel: 'Supprimer',
      destructive: true,
    );
    if (!ok || !mounted) return;
    final index = _videos.indexOf(v);
    setState(() => _videos.remove(v));
    showAppSnack(
      context,
      'Vidéo supprimée',
      icon: Icons.delete_outline_rounded,
      color: AppColors.textSecondary,
      action: SnackBarAction(
        label: 'Annuler',
        onPressed: () {
          if (mounted) setState(() => _videos.insert(index, v));
        },
      ),
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
      subtitle: '${_videos.length} vidéo${_videos.length > 1 ? 's' : ''}',
      glow: AppColors.violet,
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
        if (items.isEmpty)
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
                    onPlay: () => _showPlayer(context, v),
                    onDelete: () => _delete(v),
                  );
                },
              ),
            ),
          ],
      ],
    );
  }

  void _showPlayer(BuildContext context, VideoRecord v) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        final t = Theme.of(context).textTheme;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(Gap.page, 0, Gap.page, Gap.md),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Thumbnail(video: v, large: true),
                const SizedBox(height: Gap.lg),
                Text(v.title, style: t.titleLarge),
                const SizedBox(height: 4),
                Text(
                  '${v.camera} · ${dayLabel(v.time)} à ${clock(v.time)} · ${duration(v.duration)}',
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: Gap.lg),
                Text(
                  'La lecture sera disponible une fois le stockage vidéo connecté.',
                  style: t.bodySmall?.copyWith(color: AppColors.textTertiary),
                ),
              ],
            ),
          ),
        );
      },
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
