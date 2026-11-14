import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'stores/ai_store.dart';
import 'stores/auth_store.dart';
import 'stores/patch_notes_store.dart';
import 'stores/room_store.dart';
import 'stores/schedule_store.dart';

/// Declarative GoRouter configuration with deep-link support (`musicbot://auth-callback?token=`, `?view=schedule`).
GoRouter createAppRouter({
  required AuthStore authStore,
  required RoomStore roomStore,
  required AiStore aiStore,
  required ScheduleStore scheduleStore,
  required PatchNotesStore patchNotesStore,
}) {
  void handleIncomingUri(Uri uri) {
    final tokenParam = uri.queryParameters['token'];
    if (tokenParam != null && tokenParam.isNotEmpty) {
      authStore.loginWithToken(tokenParam).then((ok) {
        if (ok) {
          roomStore.showNotice('Signed in with Discord!');
          roomStore.startSessionPolling();
        }
      });
    }
    final viewParam = uri.queryParameters['view'];
    if (viewParam == 'schedule' || viewParam == 'room') {
      roomStore.roomView.value = viewParam!;
    }
  }

  return GoRouter(
    initialLocation: '/',
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.scheme == 'musicbot' ||
          uri.host == 'auth-callback' ||
          uri.path == '/auth-callback') {
        handleIncomingUri(uri);
        return '/';
      }
      if (uri.queryParameters.containsKey('token')) {
        handleIncomingUri(uri);
        return '/';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          handleIncomingUri(state.uri);
          return HomePage(
            authStore: authStore,
            roomStore: roomStore,
            aiStore: aiStore,
            scheduleStore: scheduleStore,
            patchNotesStore: patchNotesStore,
          );
        },
      ),
      GoRoute(
        path: '/auth-callback',
        redirect: (context, state) {
          handleIncomingUri(state.uri);
          return '/';
        },
      ),
    ],
  );
}
