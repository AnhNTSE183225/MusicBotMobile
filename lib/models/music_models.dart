import 'package:json_annotation/json_annotation.dart';
import 'state_machine_dto.dart';

part 'music_models.g.dart';

const List<String> kFallbackArtworks = [
  'assets/ocean-drive.jpg',
  'assets/sundown.jpg',
  'assets/coastline.jpg',
];

String getFallbackArtworkForTitle(String? title) {
  if (title == null || title.isEmpty) return kFallbackArtworks[0];
  int hash = 0;
  for (int i = 0; i < title.length; i++) {
    hash = title.codeUnitAt(i) + ((hash << 5) - hash);
  }
  return kFallbackArtworks[hash.abs() % kFallbackArtworks.length];
}

String optimizeThumbnailUrl(String? url) {
  if (url == null || url.trim().isEmpty) return '';
  final trimmed = url.trim();
  if (trimmed.contains('i.ytimg.com/vi/') ||
      trimmed.contains('img.youtube.com/vi/')) {
    if (trimmed.contains('/hqdefault.jpg')) {
      return trimmed.replaceAll('/hqdefault.jpg', '/maxresdefault.jpg');
    }
  }
  return trimmed;
}

String formatDurationSeconds(num? seconds) {
  if (seconds == null || seconds.isNaN || seconds <= 0) return '0:00';
  final total = seconds.floor();
  final mins = total ~/ 60;
  final secs = total % 60;
  return '$mins:${secs.toString().padLeft(2, '0')}';
}

@JsonSerializable()
class UserProfile {
  final String id;
  final String username;
  @JsonKey(name: 'global_name')
  final String? globalName;
  final String? avatar;

  const UserProfile({
    required this.id,
    required this.username,
    this.globalName,
    this.avatar,
  });

  String get displayName =>
      (globalName != null && globalName!.trim().isNotEmpty)
          ? globalName!
          : username;

  String? get avatarUrl {
    if (avatar == null || avatar!.isEmpty) return null;
    if (avatar!.startsWith('http')) return avatar;
    return 'https://cdn.discordapp.com/avatars/$id/$avatar.png?size=64';
  }

  factory UserProfile.fromJson(Map<String, dynamic> json) =>
      _$UserProfileFromJson(json);

  Map<String, dynamic> toJson() => _$UserProfileToJson(this);
}

@JsonSerializable()
class GuildSession {
  final String id;
  final String name;
  final String? icon;
  @JsonKey(name: 'channel_id')
  final String? channelId;
  @JsonKey(name: 'channel_name')
  final String? channelName;
  @JsonKey(name: 'bot_connected', defaultValue: false)
  final bool botConnected;
  @JsonKey(name: 'is_admin', defaultValue: false)
  final bool isAdmin;

  const GuildSession({
    required this.id,
    required this.name,
    this.icon,
    this.channelId,
    this.channelName,
    this.botConnected = false,
    this.isAdmin = false,
  });

  bool get isUserInVoice => channelId != null && channelId!.isNotEmpty;
  String get guildId => id;
  String get guildName => name;
  bool get inVoice => isUserInVoice || botConnected;

  factory GuildSession.fromFlexibleJson(Map<String, dynamic> json) {
    return GuildSession(
      id: (json['id'] ?? json['guild_id'] ?? '').toString(),
      name: (json['name'] ?? json['guild_name'] ?? 'Server').toString(),
      icon: (json['icon'] ?? json['guild_icon'])?.toString(),
      channelId: json['channel_id']?.toString(),
      channelName: json['channel_name']?.toString(),
      botConnected: json['bot_connected'] == true,
      isAdmin: json['is_admin'] == true,
    );
  }

  factory GuildSession.fromJson(Map<String, dynamic> json) =>
      _$GuildSessionFromJson(json);

  Map<String, dynamic> toJson() => _$GuildSessionToJson(this);
}

@JsonSerializable()
class TrackModel {
  final String id;
  final String title;
  final String artist;
  final String album;
  final String image;
  final double duration;
  final String requestedBy;
  final String? requestedAvatar;
  final int? originalIndex;
  final String? url;

  const TrackModel({
    this.id = '',
    required this.title,
    required this.artist,
    this.album = 'Discord',
    this.image = '',
    required this.duration,
    this.requestedBy = '',
    this.requestedAvatar,
    this.originalIndex,
    this.url,
  });

  String? get thumbnail => image.isEmpty ? null : image;
  String? get requester => requestedBy.isEmpty ? null : requestedBy;
  String? get requesterAvatar => requestedAvatar;

  static const TrackModel idle = TrackModel(
    id: 'idle',
    title: 'Nothing playing',
    artist: 'Waiting for a song',
    album: '',
    image: 'assets/ocean-drive.jpg',
    duration: 0,
    requestedBy: '',
  );

  bool get isAiAutoQueue =>
      requestedBy == 'AI Auto-Queue' || requestedAvatar == '/logo_icon.svg';

  factory TrackModel.fromBackendMap(
    Map<String, dynamic> map, {
    required String id,
    int? index,
  }) {
    final rawTitle = (map['title'] ?? 'Untitled Track').toString();
    final rawThumb = optimizeThumbnailUrl(map['thumbnail']?.toString());
    final reqBy =
        (map['requester_handle'] ?? map['requester_name'] ?? 'Unknown')
            .toString();
    final reqAvatar = map['requester_avatar']?.toString();
    return TrackModel(
      id: id,
      title: rawTitle,
      artist: (map['artist'] ?? 'Unknown Artist').toString(),
      album: 'Discord',
      image: rawThumb.isNotEmpty
          ? rawThumb
          : getFallbackArtworkForTitle(rawTitle),
      duration: (map['duration'] is num)
          ? (map['duration'] as num).toDouble()
          : 0.0,
      requestedBy: reqBy,
      requestedAvatar: reqAvatar,
      originalIndex: index,
      url: (map['webpage_url'] ?? map['url'])?.toString(),
    );
  }

  factory TrackModel.fromJson(Map<String, dynamic> json) =>
      _$TrackModelFromJson(json);

  Map<String, dynamic> toJson() => _$TrackModelToJson(this);
}

@JsonSerializable()
class QueueStateDto {
  final EntityStatus status;
  final List<TrackModel> queue;
  final TrackModel? current;
  @JsonKey(name: 'queue_index', defaultValue: -1)
  final int queueIndex;
  @JsonKey(defaultValue: 75)
  final int volume;
  @JsonKey(defaultValue: false)
  final bool loop;
  @JsonKey(name: 'bot_connected', defaultValue: false)
  final bool botConnected;
  @JsonKey(defaultValue: 0.0)
  final double position;
  @JsonKey(name: 'skip_votes', defaultValue: 0)
  final int skipVotes;
  @JsonKey(name: 'skip_votes_required', defaultValue: 0)
  final int skipVotesRequired;
  @JsonKey(name: 'pause_votes', defaultValue: 0)
  final int pauseVotes;
  @JsonKey(name: 'pause_votes_required', defaultValue: 0)
  final int pauseVotesRequired;
  @JsonKey(name: 'resume_votes', defaultValue: 0)
  final int resumeVotes;
  @JsonKey(name: 'resume_votes_required', defaultValue: 0)
  final int resumeVotesRequired;
  @JsonKey(name: 'stop_votes', defaultValue: 0)
  final int stopVotes;
  @JsonKey(name: 'stop_votes_required', defaultValue: 0)
  final int stopVotesRequired;
  @JsonKey(name: 'ai_auto_enabled', defaultValue: false)
  final bool aiAutoEnabled;
  @JsonKey(name: 'ai_prompt', defaultValue: '')
  final String aiPrompt;
  @JsonKey(name: 'ai_set_by_name')
  final String? aiSetByName;
  @JsonKey(name: 'ai_set_by_avatar')
  final String? aiSetByAvatar;

  const QueueStateDto({
    this.status = EntityStatus.idle,
    this.queue = const [],
    this.current,
    this.queueIndex = -1,
    this.volume = 75,
    this.loop = false,
    this.botConnected = false,
    this.position = 0.0,
    this.skipVotes = 0,
    this.skipVotesRequired = 0,
    this.pauseVotes = 0,
    this.pauseVotesRequired = 0,
    this.resumeVotes = 0,
    this.resumeVotesRequired = 0,
    this.stopVotes = 0,
    this.stopVotesRequired = 0,
    this.aiAutoEnabled = false,
    this.aiPrompt = '',
    this.aiSetByName,
    this.aiSetByAvatar,
  });

  List<TrackModel> get upcoming => queue;
  int get pauseVotesReq => pauseVotesRequired > 0 ? pauseVotesRequired : 1;
  int get skipVotesReq => skipVotesRequired > 0 ? skipVotesRequired : 1;

  EntityStatus resolveStatus() => status;

  QueueStateDto copyWith({
    EntityStatus? status,
    List<TrackModel>? queue,
    TrackModel? current,
    int? queueIndex,
    int? volume,
    bool? loop,
    bool? botConnected,
    double? position,
    int? skipVotes,
    int? skipVotesRequired,
    int? pauseVotes,
    int? pauseVotesRequired,
  }) {
    return QueueStateDto(
      status: status ?? this.status,
      queue: queue ?? this.queue,
      current: current ?? this.current,
      queueIndex: queueIndex ?? this.queueIndex,
      volume: volume ?? this.volume,
      loop: loop ?? this.loop,
      botConnected: botConnected ?? this.botConnected,
      position: position ?? this.position,
      skipVotes: skipVotes ?? this.skipVotes,
      skipVotesRequired: skipVotesRequired ?? this.skipVotesRequired,
      pauseVotes: pauseVotes ?? this.pauseVotes,
      pauseVotesRequired: pauseVotesRequired ?? this.pauseVotesRequired,
      resumeVotes: resumeVotes,
      resumeVotesRequired: resumeVotesRequired,
      stopVotes: stopVotes,
      stopVotesRequired: stopVotesRequired,
      aiAutoEnabled: aiAutoEnabled,
      aiPrompt: aiPrompt,
      aiSetByName: aiSetByName,
      aiSetByAvatar: aiSetByAvatar,
    );
  }

  factory QueueStateDto.fromBackendPayload(Map<String, dynamic> raw) {
    final resolvedStatus = StateMachineDTO.resolveEntityStatus(raw);
    final rawQueue = raw['queue'];
    final parsedQueue = <TrackModel>[];
    if (rawQueue is List) {
      for (var i = 0; i < rawQueue.length; i++) {
        final item = rawQueue[i];
        if (item is Map<String, dynamic>) {
          parsedQueue.add(
            TrackModel.fromBackendMap(item, id: 'q-$i', index: i),
          );
        }
      }
    }

    TrackModel? currentTrack;
    final rawCurrent = raw['current'];
    final isTrackActive = resolvedStatus == EntityStatus.active ||
        resolvedStatus == EntityStatus.paused ||
        resolvedStatus == EntityStatus.loading;
    if (rawCurrent is Map<String, dynamic> && isTrackActive) {
      currentTrack = TrackModel.fromBackendMap(rawCurrent, id: 'current');
    }

    int normalizedVolume = 75;
    final rawVol = raw['volume'];
    if (rawVol is num) {
      if ((rawVol <= 1.0 && rawVol > 0) || rawVol == 0 || rawVol == 1) {
        normalizedVolume = (rawVol * 100).round();
      } else {
        normalizedVolume = rawVol.round().clamp(0, 100);
      }
    }

    final rawPos =
        (raw['position'] is num) ? (raw['position'] as num).toDouble() : 0.0;
    final dur = currentTrack?.duration ?? 0.0;
    final clampedPos = dur > 0 ? rawPos.clamp(0.0, dur) : rawPos;

    return QueueStateDto(
      status: resolvedStatus,
      queue: parsedQueue,
      current: currentTrack,
      queueIndex: (raw['queue_index'] as num?)?.toInt() ?? -1,
      volume: normalizedVolume,
      loop: raw['loop'] == true,
      botConnected: raw['bot_connected'] == true,
      position: isTrackActive ? clampedPos : 0.0,
      skipVotes: (raw['skip_votes'] as num?)?.toInt() ?? 0,
      skipVotesRequired: (raw['skip_votes_required'] as num?)?.toInt() ?? 0,
      pauseVotes: (raw['pause_votes'] as num?)?.toInt() ?? 0,
      pauseVotesRequired: (raw['pause_votes_required'] as num?)?.toInt() ?? 0,
      resumeVotes: (raw['resume_votes'] as num?)?.toInt() ?? 0,
      resumeVotesRequired: (raw['resume_votes_required'] as num?)?.toInt() ?? 0,
      stopVotes: (raw['stop_votes'] as num?)?.toInt() ?? 0,
      stopVotesRequired: (raw['stop_votes_required'] as num?)?.toInt() ?? 0,
      aiAutoEnabled: raw['ai_auto_enabled'] == true,
      aiPrompt: (raw['ai_prompt'] ?? '').toString(),
      aiSetByName: raw['ai_set_by_name']?.toString(),
      aiSetByAvatar: raw['ai_set_by_avatar']?.toString(),
    );
  }

  factory QueueStateDto.fromJson(Map<String, dynamic> json) =>
      _$QueueStateDtoFromJson(json);

  Map<String, dynamic> toJson() => _$QueueStateDtoToJson(this);
}

@JsonSerializable()
class LyricWord {
  final double begin;
  final double end;
  final String text;
  @JsonKey(name: 'trailing_space')
  final bool? trailingSpace;

  const LyricWord({
    required this.begin,
    required this.end,
    required this.text,
    this.trailingSpace,
  });

  double get time => begin;

  factory LyricWord.fromJson(Map<String, dynamic> json) =>
      _$LyricWordFromJson(json);

  Map<String, dynamic> toJson() => _$LyricWordToJson(this);
}

@JsonSerializable()
class LyricLine {
  final double begin;
  final double end;
  final String text;
  final List<LyricWord>? words;

  const LyricLine({
    required this.begin,
    this.end = 0.0,
    required this.text,
    this.words,
  });

  double get time => begin;

  factory LyricLine.fromJson(Map<String, dynamic> json) =>
      _$LyricLineFromJson(json);

  Map<String, dynamic> toJson() => _$LyricLineToJson(this);
}

@JsonSerializable()
class LyricsData {
  final String type; // 'syllable' | 'line'
  final String provider;
  @JsonKey(name: 'intro_offset', defaultValue: 0.0)
  final double introOffset;
  final List<LyricLine> lines;

  const LyricsData({
    this.type = 'line',
    this.provider = 'LRCLIB',
    this.introOffset = 0.0,
    required this.lines,
  });

  String get source => provider.isEmpty ? 'LRCLIB' : provider;

  factory LyricsData.fromJson(Map<String, dynamic> json) =>
      _$LyricsDataFromJson(json);

  Map<String, dynamic> toJson() => _$LyricsDataToJson(this);
}

@JsonSerializable()
class AISong {
  final String title;
  final String artist;
  final double duration;
  final String url;
  @JsonKey(defaultValue: '')
  final String thumbnail;
  @JsonKey(defaultValue: '')
  final String reason;

  const AISong({
    required this.title,
    required this.artist,
    required this.duration,
    required this.url,
    this.thumbnail = '',
    this.reason = '',
  });

  factory AISong.fromJson(Map<String, dynamic> json) => _$AISongFromJson(json);

  Map<String, dynamic> toJson() => _$AISongToJson(this);
}

@JsonSerializable()
class AIAutoQueueConfig {
  final bool enabled;
  final String prompt;
  final int count;
  final int threshold;
  @JsonKey(name: 'set_by_name')
  final String? setByName;
  @JsonKey(name: 'set_by_avatar')
  final String? setByAvatar;

  const AIAutoQueueConfig({
    required this.enabled,
    required this.prompt,
    this.count = 5,
    this.threshold = 2,
    this.setByName,
    this.setByAvatar,
  });

  factory AIAutoQueueConfig.fromJson(Map<String, dynamic> json) =>
      _$AIAutoQueueConfigFromJson(json);

  Map<String, dynamic> toJson() => _$AIAutoQueueConfigToJson(this);
}

@JsonSerializable()
class GeminiKeyInfo {
  final int id;
  @JsonKey(name: 'masked_key')
  final String maskedKey;
  @JsonKey(name: 'added_by_user_id')
  final String addedByUserId;
  @JsonKey(name: 'added_by_username')
  final String addedByUsername;
  @JsonKey(name: 'added_by_avatar')
  final String? addedByAvatar;
  @JsonKey(name: 'added_at', defaultValue: 0)
  final num addedAt;
  @JsonKey(name: 'is_active', defaultValue: true)
  final bool isActive;
  final String status; // 'healthy' | 'quota_exceeded' | 'invalid'
  @JsonKey(name: 'status_message', defaultValue: '')
  final String statusMessage;
  @JsonKey(name: 'cooldown_remaining_seconds', defaultValue: 0)
  final num cooldownRemainingSeconds;
  @JsonKey(name: 'total_uses', defaultValue: 0)
  final int totalUses;
  @JsonKey(name: 'last_used_at', defaultValue: 0)
  final num lastUsedAt;
  @JsonKey(name: 'is_own', defaultValue: false)
  final bool isOwn;

  const GeminiKeyInfo({
    required this.id,
    required this.maskedKey,
    this.addedByUserId = '',
    this.addedByUsername = 'Member',
    this.addedByAvatar,
    this.addedAt = 0,
    this.isActive = true,
    this.status = 'healthy',
    this.statusMessage = '',
    this.cooldownRemainingSeconds = 0,
    this.totalUses = 0,
    this.lastUsedAt = 0,
    this.isOwn = false,
  });

  String get addedByName => addedByUsername;

  factory GeminiKeyInfo.fromJson(Map<String, dynamic> json) =>
      _$GeminiKeyInfoFromJson(json);

  Map<String, dynamic> toJson() => _$GeminiKeyInfoToJson(this);
}

@JsonSerializable()
class GeminiKeysResponse {
  final List<GeminiKeyInfo> keys;
  @JsonKey(name: 'total_active', defaultValue: 0)
  final int totalActive;
  @JsonKey(name: 'total_keys', defaultValue: 0)
  final int totalKeys;
  @JsonKey(name: 'is_admin', defaultValue: false)
  final bool isAdmin;

  const GeminiKeysResponse({
    required this.keys,
    this.totalActive = 0,
    this.totalKeys = 0,
    this.isAdmin = false,
  });

  int get totalPoolSize => totalKeys > 0 ? totalKeys : keys.length;

  factory GeminiKeysResponse.fromJson(Map<String, dynamic> json) =>
      _$GeminiKeysResponseFromJson(json);

  Map<String, dynamic> toJson() => _$GeminiKeysResponseToJson(this);
}

@JsonSerializable()
class PlaylistTrack {
  final int index;
  final String id;
  final String title;
  final String artist;
  final double duration;
  final String url;
  final String thumbnail;

  const PlaylistTrack({
    required this.index,
    this.id = '',
    required this.title,
    required this.artist,
    required this.duration,
    required this.url,
    this.thumbnail = '',
  });

  factory PlaylistTrack.fromJson(Map<String, dynamic> json) =>
      _$PlaylistTrackFromJson(json);

  Map<String, dynamic> toJson() => _$PlaylistTrackToJson(this);
}

@JsonSerializable()
class PlaylistPreviewResponse {
  final String title;
  final String uploader;
  final String thumbnail;
  @JsonKey(name: 'total_tracks', defaultValue: 0)
  final int totalTracks;
  final List<PlaylistTrack> tracks;

  const PlaylistPreviewResponse({
    required this.title,
    this.uploader = '',
    this.thumbnail = '',
    this.totalTracks = 0,
    required this.tracks,
  });

  int get totalCount => totalTracks > 0 ? totalTracks : tracks.length;

  factory PlaylistPreviewResponse.fromJson(Map<String, dynamic> json) =>
      _$PlaylistPreviewResponseFromJson(json);

  Map<String, dynamic> toJson() => _$PlaylistPreviewResponseToJson(this);
}

class PatchNote {
  final String version;
  final String date;
  final String headline;
  final String summary;
  final List<String> details;

  const PatchNote({
    required this.version,
    required this.date,
    required this.headline,
    required this.summary,
    required this.details,
  });

  String get title => headline;
  List<String> get highlights => details;
}

const List<PatchNote> kPatchNotes = [
  PatchNote(
    version: '1.5.4',
    date: '2026-11-14',
    headline: 'MusicBỏTúi Visual Identity & Vector Brand Cosmetics',
    summary:
        'Unified visual identity with MusicBotUI frontend: vector equalizer pocket logo, dark theme splash screen, and official MusicBỏTúi Android app launcher icons.',
    details: [
      'Official MusicBỏTúi branding: equalizer bars, floating notes, and stitched pocket with emerald rivets directly rendered on Impeller GPU',
      'Vector brand wordmark in header with white "Music" and vibrant emerald "#00E676" "BỏTúi"',
      'High-resolution Android launcher mipmap icons generated from frontend SVG assets',
      'Dark theme boot splash screen (#0B1014) replacing legacy white screen',
      'AI Auto-Queue tracks now showcase the pocket logo icon across both Queue and Player panels',
    ],
  ),
  PatchNote(
    version: '1.5.3',
    date: '2026-11-14',
    headline: 'Seamless Mobile Discord OAuth2 & Deep-Link Return',
    summary:
        'Sign in with one tap via the Discord mobile app or system browser using the ?platform=mobile flag—returning directly to MusicBotMobile without redirecting to the web frontend.',
    details: [
      'One-tap "Continue with Discord" mobile authentication flow (?platform=mobile&mobile_state=...)',
      'Backend OAuth callback detects mobile login state and triggers musicbot://auth-callback deep-link return instead of redirecting to the web frontend',
      'Automatic background & foreground session synchronization (/api/auth/mobile/poll) so login completes seamlessly without manual token copying',
    ],
  ),
  PatchNote(
    version: '1.5.2',
    date: '2026-11-05',
    headline:
        'Schedule Reliability, Exact Event Reminders & Faster Song Queueing',
    summary:
        'Delivers a smoother calendar experience, on-the-minute Discord event notifications, faster single-song additions from YouTube links, and accurate playback timer bounds.',
    details: [
      'Reliable Server Schedule loading: resolved intermittent connection errors when opening the calendar or switching between Discord servers',
      'On-the-minute Discord event reminders: 15-minute advance alerts and "Event Starting Now" notifications now arrive at the exact scheduled time instead of one minute early',
      'Faster single-song queueing: pasting a YouTube link into the search bar and clicking Add (+) now immediately adds just that song, ignoring any attached playlist to save loading time',
      'Dedicated Playlist Import button: click the Add Playlist icon in the search bar whenever you want to detect a playlist from a link and choose a custom range of songs to import',
      'Accurate playback progress display: fixed an edge case where the elapsed track timer could briefly count past the song\'s total duration',
    ],
  ),
  PatchNote(
    version: '1.5.1',
    date: '2026-10-24',
    headline: 'Event Deep-Link Polish & Dismissal Fix',
    summary:
        'Fixes an issue where landing on the schedule via Discord invitation links trapped users in an unbreakable modal loop.',
    details: [
      'Fixed an auto-open loop that prevented dismissing or closing the event details dialog when arriving from Discord invite links',
      'Seamlessly removes the ?event parameter from the URL upon closing',
      'Automatically positions the calendar cursor on the scheduled event date when opening deep links',
    ],
  ),
  PatchNote(
    version: '1.5.0',
    date: '2026-10-24',
    headline: 'Discord Event Invitations & Direct RSVP Links',
    summary:
        'Instantly notifies server members when new events are created—announcing in the dedicated #event channel or messaging invitees directly via DMs.',
    details: [
      'Automatic server invitation broadcasts to the dedicated #event text channel without @everyone pings',
      'Personal direct messages (DMs) from the bot when individual members are invited to private sessions',
      'One-click RSVP links embedded in invitation cards',
    ],
  ),
  PatchNote(
    version: '1.4.1',
    date: '2026-10-24',
    headline: 'Voice Channel Auto-Switch & Responsive Header Polish',
    summary:
        'Seamlessly auto-switches active server when joining voice channels and optimizes topbar layout for smaller screens.',
    details: [
      'Smart voice detection: automatically focuses the server where you joined voice chat upon opening or returning to the Listening Room',
      'Responsive header refinement: resolved element collisions on narrower screen widths with fluid server selector constraints',
      'Streamlined single-line "Live" session indicator to prevent badge text wrapping',
    ],
  ),
  PatchNote(
    version: '1.4.0',
    date: '2026-10-24',
    headline: 'Server Schedule & Event Calendar',
    summary:
        'Plan listening parties, study sessions, and server events directly in your Discord community with Month, Week, and Agenda views.',
    details: [
      'Dedicated Server Calendar tab with Month, Week, and Agenda views',
      'One-off and recurring event scheduling (daily, weekly with weekday selection, monthly)',
      'Multiple location types: Discord voice channels, Google Maps locations/links, and online event links',
      'Server-wide or individual member invitations with real-time RSVP responses (Accept, Maybe, Decline)',
    ],
  ),
  PatchNote(
    version: '1.3.0',
    date: '2026-10-24',
    headline: 'Release Notifications & Sleek Sync Badges',
    summary:
        'Release notes now feature unread notification counters with mark as read/unread controls, plus streamlined in-line lyrics sync indicators.',
    details: [
      'Outside notification counter badge on the release notes button showing live count of unread updates',
      'Persistent local storage tracking for read and unread release notes',
      'Display true net sync offset with clear manual and MV intro breakdown',
    ],
  ),
  PatchNote(
    version: '1.2.0',
    date: '2026-10-24',
    headline: 'Click-to-Sync Lyrics',
    summary:
        'Manually scroll and tap any line to instantly synchronize lyrics to that moment, with delay offset applied.',
    details: [
      'Tap any line in line-based or syllable-based lyrics to snap the sync offset to that line in real time',
      'Persistent per-track offset saved to local storage with one-tap Reset to original sync timings',
    ],
  ),
  PatchNote(
    version: '1.1.0',
    date: '2026-10-24',
    headline: 'Playlist Range Import',
    summary:
        'Preview YouTube playlists and customize which songs (from song # to song #) get added to the queue.',
    details: [
      'Playlist button in the queue search bar for instant imports',
      'Interactive preview modal displaying total track count, artwork, titles, and durations',
      'Precise range selection controls (From / To inputs) with one-tap presets (All, First 10, 25, 50)',
    ],
  ),
  PatchNote(
    version: '1.0.0',
    date: '2026-10-21',
    headline: 'Initial Release',
    summary:
        'Your Discord listening room with real-time synchronized lyrics, shared queue, and AI vibe queueing.',
    details: [
      'Artwork-first listening room with dynamic ambient lighting',
      'Real-time synchronized lyrics (line & syllable sync) with LRCLIB & Musixmatch fallback',
      'Collaborative shared queue with vote skipping, pausing, and reordering',
      'AI Auto-Queue powered by Gemini with custom vibe prompts and community key sharing',
    ],
  ),
];
