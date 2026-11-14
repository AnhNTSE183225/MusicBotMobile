/// Pure YouTube URL analysis utilities matching MusicBotUI/src/lib/youtube.ts.
abstract final class YouTubeUtils {
  static final RegExp _ytHostRegex =
      RegExp(r'(?:youtube\.com|youtu\.be)', caseSensitive: false);
  static final RegExp _listParamRegex =
      RegExp(r'[?&]list=([^&#]+)', caseSensitive: false);
  static final RegExp _videoParamRegex =
      RegExp(r'[?&]v=([^&#]+)', caseSensitive: false);
  static final RegExp _fullYtUrlRegex = RegExp(
    r'^(?:https?:\/\/)?(?:(?:www|m|music)\.)?(?:youtube\.com|youtu\.be)\/\S+$',
    caseSensitive: false,
  );

  static bool isYouTubePlaylistUrl(String? query) {
    if (query == null || query.trim().isEmpty) return false;
    final trimmed = query.trim();
    if (!_ytHostRegex.hasMatch(trimmed) || !_listParamRegex.hasMatch(trimmed)) {
      return false;
    }

    try {
      final normalized =
          (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
              ? trimmed
              : 'https://$trimmed';
      final uri = Uri.parse(normalized);
      final listId = uri.queryParameters['list'];
      if (listId == null || listId.isEmpty) return false;
      final upper = listId.toUpperCase();
      if (upper.startsWith('LL') || upper.startsWith('WL')) return false;
      return true;
    } catch (_) {
      final match = _listParamRegex.firstMatch(trimmed);
      final listId = match?.group(1)?.toUpperCase();
      if (listId == null || listId.isEmpty) return false;
      return !listId.startsWith('LL') && !listId.startsWith('WL');
    }
  }

  static String cleanPlaylistUrl(String? query) {
    if (query == null || query.trim().isEmpty) return '';
    final trimmed = query.trim();
    try {
      final normalized =
          (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
              ? trimmed
              : 'https://$trimmed';
      final uri = Uri.parse(normalized);
      final listId = uri.queryParameters['list'];
      final videoId = uri.queryParameters['v'];
      if (listId == null || listId.isEmpty) return trimmed;
      if (listId.toUpperCase().startsWith('RD') &&
          videoId != null &&
          videoId.isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$videoId&list=$listId';
      }
      return 'https://www.youtube.com/playlist?list=$listId';
    } catch (_) {
      return trimmed;
    }
  }

  static String stripPlaylistFromUrl(String? query) {
    if (query == null || query.trim().isEmpty) return '';
    final trimmed = query.trim();
    if (!_ytHostRegex.hasMatch(trimmed)) return trimmed;

    try {
      final normalized =
          (trimmed.startsWith('http://') || trimmed.startsWith('https://'))
              ? trimmed
              : 'https://$trimmed';
      final uri = Uri.parse(normalized);
      var videoId = uri.queryParameters['v'];

      if ((videoId == null || videoId.isEmpty) &&
          uri.host.toLowerCase().contains('youtu.be')) {
        final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();
        if (segments.isNotEmpty) videoId = segments.first;
      } else if ((videoId == null || videoId.isEmpty) &&
          uri.path.contains('/embed/')) {
        final after = uri.path.split('/embed/').last.split('/');
        if (after.isNotEmpty && after.first.isNotEmpty) videoId = after.first;
      } else if ((videoId == null || videoId.isEmpty) &&
          uri.path.contains('/shorts/')) {
        final after = uri.path.split('/shorts/').last.split('/');
        if (after.isNotEmpty && after.first.isNotEmpty) videoId = after.first;
      }

      if (videoId != null && videoId.isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$videoId';
      }
      return trimmed;
    } catch (_) {
      final match = _videoParamRegex.firstMatch(trimmed);
      final v = match?.group(1);
      if (v != null && v.isNotEmpty) {
        return 'https://www.youtube.com/watch?v=$v';
      }
      return trimmed;
    }
  }

  static bool isYouTubeUrl(String? query) {
    if (query == null || query.trim().isEmpty) return false;
    return _fullYtUrlRegex.hasMatch(query.trim());
  }

  /// Returns true when the URL is a playlist URL that does NOT point to a specific video (`v=`).
  static bool isPurePlaylistUrl(String? query) {
    if (!isYouTubePlaylistUrl(query)) return false;
    final trimmed = query!.trim();
    return !_videoParamRegex.hasMatch(trimmed);
  }
}
