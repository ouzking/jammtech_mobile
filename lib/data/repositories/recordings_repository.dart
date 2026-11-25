import '../backend.dart';
import '../demo_data.dart';
import '../models.dart';

/// Enregistrements vidéo : liste, lecture par URL signée, suppression.
class RecordingsRepository {
  RecordingsRepository._();
  static final instance = RecordingsRepository._();

  Future<List<VideoRecord>> list(
    String? homeId, {
    bool motionOnly = false,
  }) async {
    if (!Backend.enabled) {
      return [
        for (final v in DemoData.videos)
          if (!motionOnly || v.motion) v,
      ];
    }
    if (homeId == null) return const [];
    try {
      var q = Backend.client
          .from('recordings')
          .select('*, devices(name, room)')
          .eq('home_id', homeId)
          .eq('uploaded', true);
      if (motionOnly) q = q.eq('motion_detected', true);
      final rows = await q.order('started_at', ascending: false);
      return [for (final r in rows) VideoRecord.fromJson(r)];
    } catch (e) {
      throw toAppException(e);
    }
  }

  /// URL signée de 5 minutes ; `null` en mode démo ou sans fichier.
  Future<String?> signedUrl(String? path) async {
    if (!Backend.enabled || path == null) return null;
    try {
      return await Backend.client.storage
          .from('recordings')
          .createSignedUrl(path, 300);
    } catch (e) {
      throw toAppException(e);
    }
  }

  Future<void> delete(VideoRecord v) async {
    if (!Backend.enabled) return;
    try {
      await Backend.client.from('recordings').delete().eq('id', v.id);
    } catch (e) {
      throw toAppException(e);
    }
  }
}
