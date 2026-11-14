import 'package:signals_flutter/signals_flutter.dart';
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

  AuthStore({
    required AuthGateway authGateway,
    required AppDatabase database,
  })  : _authGateway = authGateway,
        _database = database {
    serverBaseUrl.value = _authGateway.apiBaseUrl;
    authFsm = StatefulEntityController<UserProfile>(
      id: 'auth_session',
      onForegroundResync: () => verifySession(),
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

  Future<bool> loginWithToken(String token) async {
    final trimmed = token.trim();
    if (trimmed.isEmpty) return false;
    await _authGateway.saveToken(trimmed);
    return verifySession();
  }

  Future<void> updateServerBaseUrl(String newBaseUrl) async {
    final trimmed = newBaseUrl.trim();
    if (trimmed.isEmpty) return;
    _authGateway.updateServerUrl(trimmed);
    serverBaseUrl.value = _authGateway.apiBaseUrl;
    await _database.saveSetting('api_base_url', _authGateway.apiBaseUrl);
  }

  Future<void> logout() async {
    await _authGateway.logout();
    authFsm.transitionTo(
      EntityStatus.idle,
      reason: 'User logged out',
    );
  }

  void dispose() {
    authFsm.dispose();
    serverBaseUrl.dispose();
  }
}
