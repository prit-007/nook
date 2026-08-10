import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/home/home_screen.dart';
import '../../features/home/search_screen.dart';
import '../../features/notebooks/notebooks_screen.dart';
import '../../features/notebooks/notebook_detail_screen.dart';
import '../../features/tags/tags_screen.dart';
import '../../features/tags/tag_detail_screen.dart';
import '../../features/editor/note_editor_screen.dart';
import '../../features/doodle/doodle_canvas_screen.dart';
import '../../features/trash/trash_screen.dart';
import '../../features/security/lock_screen.dart';
import '../../features/security/locked_notes_screen.dart';
import '../../features/sync_ui/sync_send_screen.dart';
import '../../features/sync_ui/sync_receive_screen.dart';
import '../../features/sync_ui/sync_pairing_screen.dart';
import '../../features/sync_ui/sync_transfer_screen.dart';
import '../../features/sync_ui/sync_history_screen.dart';
import '../../features/settings/settings_screen.dart';
import '../../features/settings/settings_appearance_screen.dart';
import '../../features/settings/settings_security_screen.dart';
import '../../features/settings/settings_storage_screen.dart';
import '../../features/settings/settings_sync_devices_screen.dart';
import '../../features/settings/settings_about_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import 'widgets/app_shell.dart';

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: '/home',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/lock',
        builder: (_, __) => const LockScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (_, __) => const OnboardingScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) => AppShell(child: child),
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/home/search',
            builder: (_, __) => const SearchScreen(),
          ),
          GoRoute(
            path: '/notebooks',
            builder: (_, __) => const NotebooksScreen(),
          ),
          GoRoute(
            path: '/notebooks/:notebookId',
            builder: (_, state) => NotebookDetailScreen(
              notebookId: state.pathParameters['notebookId']!,
            ),
          ),
          GoRoute(
            path: '/tags',
            builder: (_, __) => const TagsScreen(),
          ),
          GoRoute(
            path: '/tags/:tagId',
            builder: (_, state) => TagDetailScreen(
              tagId: state.pathParameters['tagId']!,
            ),
          ),
          GoRoute(
            path: '/trash',
            builder: (_, __) => const TrashScreen(),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, __) => const SettingsScreen(),
          ),
          GoRoute(
            path: '/settings/appearance',
            builder: (_, __) => const SettingsAppearanceScreen(),
          ),
          GoRoute(
            path: '/settings/security',
            builder: (_, __) => const SettingsSecurityScreen(),
          ),
          GoRoute(
            path: '/settings/storage',
            builder: (_, __) => const SettingsStorageScreen(),
          ),
          GoRoute(
            path: '/settings/sync-devices',
            builder: (_, __) => const SettingsSyncDevicesScreen(),
          ),
          GoRoute(
            path: '/settings/about',
            builder: (_, __) => const SettingsAboutScreen(),
          ),
          GoRoute(
            path: '/locked',
            builder: (_, __) => const LockedNotesScreen(),
          ),
        ],
      ),
      GoRoute(
        path: '/note/new',
        builder: (_, state) => NoteEditorScreen(
          notebookId: state.uri.queryParameters['notebookId'],
          type: state.uri.queryParameters['type'],
        ),
      ),
      GoRoute(
        path: '/note/:noteId',
        builder: (_, state) => NoteEditorScreen(
          noteId: state.pathParameters['noteId']!,
        ),
      ),
      GoRoute(
        path: '/note/:noteId/doodle/:attachmentId',
        builder: (_, state) => DoodleCanvasScreen(
          noteId: state.pathParameters['noteId']!,
          attachmentId: state.pathParameters['attachmentId']!,
        ),
      ),
      GoRoute(
        path: '/sync/send',
        builder: (_, __) => const SyncSendScreen(),
      ),
      GoRoute(
        path: '/sync/receive',
        builder: (_, __) => const SyncReceiveScreen(),
      ),
      GoRoute(
        path: '/sync/pairing',
        builder: (_, __) => const SyncPairingScreen(),
      ),
      GoRoute(
        path: '/sync/transfer/:sessionId',
        builder: (_, state) => SyncTransferScreen(
          sessionId: state.pathParameters['sessionId']!,
        ),
      ),
      GoRoute(
        path: '/sync/history',
        builder: (_, __) => const SyncHistoryScreen(),
      ),
    ],
  );
});
