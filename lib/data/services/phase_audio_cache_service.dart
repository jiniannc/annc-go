import 'dart:typed_data';

import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../models/master_data_bundle.dart';

class PhaseAudioLinks {
  const PhaseAudioLinks({this.jpUrl, this.cnUrl});

  final String? jpUrl;
  final String? cnUrl;

  bool get hasAny => (jpUrl?.isNotEmpty ?? false) || (cnUrl?.isNotEmpty ?? false);
}

class PhaseAudioCacheService {
  static const _boxName = 'phase_audio_cache_v1';

  Future<Box<dynamic>>? _boxFuture;

  Future<Box<dynamic>> _openBox() {
    _boxFuture ??= Hive.openBox(_boxName);
    return _boxFuture!;
  }

  Map<String, PhaseAudioLinks> buildPhaseAudioLinksByPhaseId(
    MasterDataBundle bundle,
  ) {
    final map = <String, PhaseAudioLinks>{};
    for (final item in bundle.announcements) {
      final phaseId = item.phaseId.trim();
      if (phaseId.isEmpty) {
        continue;
      }
      final current = map[phaseId] ?? const PhaseAudioLinks();
      final nextJp =
          (current.jpUrl?.isNotEmpty ?? false) ? current.jpUrl : item.audioJpUrl;
      final nextCn =
          (current.cnUrl?.isNotEmpty ?? false) ? current.cnUrl : item.audioCnUrl;
      map[phaseId] = PhaseAudioLinks(jpUrl: nextJp, cnUrl: nextCn);
    }
    return map;
  }

  Future<void> prefetchByBundle(MasterDataBundle bundle) async {
    final phaseAudio = buildPhaseAudioLinksByPhaseId(bundle);
    final uniqueUrls = <String>{};
    for (final links in phaseAudio.values) {
      if (links.jpUrl != null && links.jpUrl!.trim().isNotEmpty) {
        uniqueUrls.add(links.jpUrl!.trim());
      }
      if (links.cnUrl != null && links.cnUrl!.trim().isNotEmpty) {
        uniqueUrls.add(links.cnUrl!.trim());
      }
    }
    for (final url in uniqueUrls) {
      await getOrDownload(url);
    }
  }

  Future<Uint8List?> getCachedBytes(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final box = await _openBox();
    final raw = box.get(normalized);
    if (raw is Uint8List) {
      return raw;
    }
    if (raw is List<int>) {
      return Uint8List.fromList(raw);
    }
    return null;
  }

  Future<Uint8List?> getOrDownload(String url) async {
    final normalized = url.trim();
    if (normalized.isEmpty) {
      return null;
    }
    final cached = await getCachedBytes(normalized);
    if (cached != null && cached.isNotEmpty) {
      return cached;
    }

    final uri = Uri.tryParse(normalized);
    if (uri == null) {
      return null;
    }
    try {
      final response = await http.get(uri);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        return null;
      }
      final data = Uint8List.fromList(bytes);
      final box = await _openBox();
      await box.put(normalized, data);
      return data;
    } catch (_) {
      return null;
    }
  }
}
