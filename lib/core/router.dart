import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';

import '../app.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/search_screen.dart';
import '../../features/notebooks/notebooks_screen.dart';
import '../../features/tags/tags_screen.dart';
import '../../features/notebooks/notebook_detail_screen.dart';
import '../../features/tags/tag_detail_screen.dart';
import '../../features/editor/note_editor_screen.dart';
import '../../features/editor/version_history_screen.dart';
import '../../features/doodle/doodle_canvas_screen.dart';
import '../../features/trash/trash_screen.dart';
import '../../features/security/lock_screen.dart';
import '../../features/security/locked_notes_screen.dart';
import '../../features/sync_ui/sync_screen.dart';
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
import '../../features/settings/settings_privacy_screen.dart';
import '../../features/settings/privacy_explainer_screen.dart';
import '../../features/settings/settings_logs_screen.dart';
import '../../features/exports/exports_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import '../../features/reminders/reminders_screen.dart';
import 'widgets/app_shell.dart';
import 'widgets/editorial_page_transition.dart';
import 'providers/navigation_preference.dart';

export 'widgets/editorial_page_transition.dart';

/// Error page shown for undefined routes.
class _ErrorPage extends StatelessWidget {
  const _ErrorPage(this.error);
  final Object error;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedAlert02,
              size: 48,
              color: scheme.error,
            ),
            const SizedBox(height: 16),
            Text(
              'Page not found',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$error',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () => context.go('/home'),
              child: const Text('Go home'),
            ),
          ],
        ),
      ),
    );
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: NookApp.navigatorKey,
    initialLocation: ref.read(navigationPreferenceProvider.notifier).route,
    errorBuilder: (context, state) =>
        _ErrorPage(state.error ?? 'Unknown error'),
    redirect: (context, state) {
      final location = state.matchedLocation;

      // Allow onboarding and lock routes through without persistence.
      if (location == '/onboarding' || location == '/lock') return null;

      // Auto-persist the current route so the app can restore it on cold
      // start. Only shell root destinations are saved — sub-routes like
      // `/home/search` and `/notebooks/:id` are filtered out in
      // NavigationPreference so a restored page never renders without its
      // parent (and a dead back button).
      NavigationPreference.rememberPath(location);
      return null; // no redirect, just persist.
    },
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
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.fadeThrough,
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/notebooks',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.fadeThrough,
              child: const NotebooksScreen(),
            ),
          ),
          GoRoute(
            path: '/notebooks/:notebookId',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: NotebookDetailScreen(
                notebookId: state.pathParameters['notebookId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/tags',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.fadeThrough,
              child: const TagsScreen(),
            ),
          ),
          GoRoute(
            path: '/tags/:tagId',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: TagDetailScreen(
                tagId: state.pathParameters['tagId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/sync',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const SyncScreen(),
            ),
          ),
          GoRoute(
            path: '/trash',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.fadeThrough,
              child: const TrashScreen(),
            ),
          ),
          GoRoute(
            path: '/reminders',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const RemindersScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.slideUp,
              child: const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/appearance',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const SettingsAppearanceScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/security',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const SettingsSecurityScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/storage',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const SettingsStorageScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/exports',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const ExportsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/sync-devices',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const SettingsSyncDevicesScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/about',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const SettingsAboutScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/privacy',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const SettingsPrivacyScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/privacy/explainer',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const PrivacyExplainerScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/logs',
            pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
              state: state,
              type: EditorialTransitionType.sharedAxis,
              child: const SettingsLogsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/home/search',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.slideUp,
          child: const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/locked',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.slideUp,
          child: const LockedNotesScreen(),
        ),
      ),
      GoRoute(
        path: '/note/new',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.containerTransform,
          child: NoteEditorScreen(
            notebookId: state.uri.queryParameters['notebookId'],
            type: state.uri.queryParameters['type'],
          ),
        ),
      ),
      GoRoute(
        path: '/note/:noteId',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.containerTransform,
          child: NoteEditorScreen(
            noteId: state.pathParameters['noteId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/note/:noteId/doodle/:attachmentId',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.slideUp,
          child: DoodleCanvasScreen(
            noteId: state.pathParameters['noteId']!,
            attachmentId: state.pathParameters['attachmentId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/note/:noteId/history',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.slideUp,
          child: VersionHistoryScreen(
            noteId: state.pathParameters['noteId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/sync/send',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.slideUp,
          child: const SyncSendScreen(),
        ),
      ),
      GoRoute(
        path: '/sync/receive',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.slideUp,
          child: const SyncReceiveScreen(),
        ),
      ),
      GoRoute(
        path: '/sync/pairing',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return EditorialPageTransitions.buildPage(
            state: state,
            type: EditorialTransitionType.slideUp,
            child: SyncPairingScreen(
              pairingCode: extra['pairingCode'] ?? '000000',
              deviceName: extra['deviceName'] ?? 'Unknown Device',
            ),
          );
        },
      ),
      GoRoute(
        path: '/sync/transfer/:sessionId',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.slideUp,
          child: SyncTransferScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/sync/history',
        pageBuilder: (context, state) => EditorialPageTransitions.buildPage(
          state: state,
          type: EditorialTransitionType.slideUp,
          child: const SyncHistoryScreen(),
        ),
      ),
    ],
  );
});
