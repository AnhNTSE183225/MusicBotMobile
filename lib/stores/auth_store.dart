import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:signals_flutter/signals_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/database/app_database.dart';
import '../core/repositories/music_repository.dart';
import '../models/music_models.dart';
import '../models/state_machine_dto.dart';
import 'entity_fsm_store.dart';

class AuthStore {
  final AuthGateway _authGateway;
  final AppDatabase _database;

  late final StatefulEntityController<UserProfile> authFsm;
  late final ReadonlySignal<EntityStatus> status;
  late final ReadonlySignal<UserProfile?> currentUser;
  late final ReadonlySignal<bool> isAuthenticated;
  final Signal<String> serverBaseUrl = signal('');
  final Signal<bool> isWaitingForOAuth = signal(false);

  Timer? _oauthPollTimer;
  String? _pendingMobileState;
  VoidCallback? _onOAuthSuccessCallback;

  AuthStore({
    required AuthGateway authGateway,
    required AppDatabase database,
  })  : _authGateway = authGateway,
        _database = database {
    serverBaseUrl.value = _authGateway.apiBaseUrl;
    authFsm = StatefulEntityController<UserProfile>(
      id: 'auth_session',
      onForegroundResync: () {
        if (_pendingMobileState != null) {
          _checkPendingMobileOAuth();
        } else {
          verifySession();
        }
      },
    );
    status = authFsm.status;
    currentUser = authFsm.activeData;
    isAuthenticated = computed(
      () =>
          authFsm.status.value == EntityStatus.active &&
          authFsm.activeData.value != null,
    );
  }

  String get loginUrl => _authGateway.loginUrl;

  Future<void> initialize({String? initialToken}) async {
    authFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Initializing authentication store',
    );
    try {
      final savedServerUrl = await _database.loadSetting('api_base_url');
      if (savedServerUrl != null && savedServerUrl.trim().isNotEmpty) {
        _authGateway.updateServerUrl(savedServerUrl.trim());
        serverBaseUrl.value = _authGateway.apiBaseUrl;
      }
      if (initialToken != null && initialToken.trim().isNotEmpty) {
        await _authGateway.saveToken(initialToken.trim());
      }
      await verifySession();
    } catch (e) {
      authFsm.transitionTo(
        EntityStatus.idle,
        reason: 'Auth initialization fallback',
      );
    }
  }

  Future<bool> verifySession() async {
    authFsm.transitionTo(
      EntityStatus.loading,
      reason: 'Verifying Discord session token',
    );
    try {
      final user = await _authGateway.checkAuth();
      if (user != null) {
        authFsm.transitionTo(
          EntityStatus.active,
          reason: 'Authenticated as ${user.username}',
          data: user,
        );
        return true;
      } else {
        authFsm.transitionTo(
          EntityStatus.idle,
          reason: 'No active session token',
        );
        return false;
      }
    } catch (e) {
      authFsm.transitionTo(
        EntityStatus.error,
        reason: 'Session verification failed',
        error: e.toString(),
      );
      return false;
    }
  }

  /// Launches the mobile-aware Discord OAuth2 flow (?platform=mobile&mobile_state=...)
  /// which opens the Discord mobile app or system browser and redirects back to
  /// `musicbot://auth-callback?token=...` (plus polls `/api/auth/mobile/poll` automatically).
  Future<void> startMobileDiscordLogin({VoidCallback? onAuthenticated}) async {
    _cancelOAuthPoll();
    final rand = Random.secure().nextInt(1 << 30).toRadixString(16);
    final stateId = 'mob_${DateTime.now().millisecondsSinceEpoch}_$rand';
    _pendingMobileState = stateId;
    _onOAuthSuccessCallback = onAuthenticated;
    isWaitingForOAuth.value = true;

    final mobileLoginUri =
        Uri.parse(_authGateway.buildMobileLoginUrl(stateId));
    await launchUrl(
      mobileLoginUri,
      mode: LaunchMode.externalApplication,
    );

    var ticks = 0;
    _oauthPollTimer = Timer.periodic(
      const Duration(milliseconds: 1500),
      (_) async {
        ticks++;
        if (ticks > 120) {
          cancelMobileDiscordLogin();
          return;
        }
        await _checkPendingMobileOAuth();
      },
    );
  }

  Future<void> _checkPendingMobileOAuth() async {
    final stateId = _pendingMobileState;
    if (stateId == null) return;
    final token = await _authGateway.pollMobileAuth(stateId);
    if (token != null && token.isNotEmpty) {
      final cb = _onOAuthSuccessCallback;
      _cancelOAuthPoll();
      final ok = await loginWithToken(token);
      if (ok && cb != null) {
        cb();
      }
    }
  }

  void cancelMobileDiscordLogin() {
    _cancelOAuthPoll();
  }

  void _cancelOAuthPoll() {
    _oauthPollTimer?.cancel();
    _oauthPollTimer = null;
    _pendingMobileState = null;
    _onOAuthSuccessCallback = null;
    isWaitingForOAuth.value = false;
  }

  Future<bool> loginWithToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return false;
    final cb = _onOAuthSuccessCallback;
    _cancelOAuthPoll();
    await _authGateway.saveToken(trimmed);
    final ok = await verifySession();
    if (ok && cb != null) {
      cb();
    }
    return ok;
  }

  Future<void> updateServerBaseUrl(String newBaseUrl) async {
    final trimmed = newBaseUrl.trim();
    if (trimmed.isEmpty) return;
    _authGateway.updateServerUrl(trimmed);
    serverBaseUrl.value = _authGateway.apiBaseUrl;
    await _database.saveSetting('api_base_url', _authGateway.apiBaseUrl);
  }

  Future<void> logout() async {
    _cancelOAuthPoll();
    await _authGateway.logout();
    authFsm.transitionTo(
      EntityStatus.idle,
      reason: 'User logged out',
    );
  }

  void dispose() {
    _cancelOAuthPoll();
    authFsm.dispose();
    serverBaseUrl.dispose();
    isWaitingForOAuth.dispose();
  }
}
