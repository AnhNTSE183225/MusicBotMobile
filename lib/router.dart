import 'package:go_router/go_router.dart';
import 'pages/home_page.dart';
import 'stores/ai_store.dart';
import 'stores/auth_store.dart';
import 'stores/patch_notes_store.dart';
import 'stores/room_store.dart';
import 'stores/schedule_store.dart';

/// Declarative GoRouter configuration with deep-link support (`?token=`, `?view=schedule`).
GoRouter createAppRouter({
  required AuthStore authStore,
  required RoomStore roomStore,
  required AiStore aiStore,
  required ScheduleStore scheduleStore,
  required PatchNotesStore patchNotesStore,
}) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) {
          final tokenParam = state.uri.queryParameters['token'];
          if (tokenParam != null && tokenParam.isNotEmpty) {
            authStore.loginWithToken(tokenParam).then((_) {
              roomStore.startSessionPolling();
            });
          }
          final viewParam = state.uri.queryParameters['view'];
          if (viewParam == 'schedule' || viewParam == 'room') {
            roomStore.roomView.value = viewParam!;
          }
          return HomePage(
            authStore: authStore,
            roomStore: roomStore,
            aiStore: aiStore,
            scheduleStore: scheduleStore,
            patchNotesStore: patchNotesStore,
          );
        },
      ),
    ],
  );
}
