import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app.dart';
import '../../features/home/home_screen.dart';
import '../../features/home/search_screen.dart';
import '../../features/notebooks/notebook_detail_screen.dart';
import '../../features/tags/tag_detail_screen.dart';
import '../../features/collections/collections_screen.dart';
import '../../features/editor/note_editor_screen.dart';
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
import '../../features/settings/settings_logs_screen.dart';
import '../../features/onboarding/onboarding_screen.dart';
import 'widgets/app_shell.dart';
import 'providers/navigation_preference.dart';

/// Bespoke page transition for a luxury editorial feel.
///
/// Combines a subtle fade with an upward glide, using a snappy
/// duration and cubic easing for fluid, responsive transitions.
CustomTransitionPage<T> buildEditorialTransition<T>({
  required BuildContext context,
  required GoRouterState state,
  required Widget child,
}) {
  return CustomTransitionPage<T>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 350),
    reverseTransitionDuration: const Duration(milliseconds: 250),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curve = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );

      return FadeTransition(
        opacity: curve,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0.0, 0.03), // Subtle 3% drop
            end: Offset.zero,
          ).animate(curve),
          // Rasterize the incoming page once so the fade/slide only composites
          // layers — no per-frame repaint of the page subtree during the push.
          child: RepaintBoundary(child: child),
        ),
      );
    },
  );
}

/// Lightweight editorial page route for imperative [Navigator.push] calls.
///
/// Uses the same fade+slide as [buildEditorialTransition] but without the
/// go_router dependency so it can be used anywhere in the app.
class EditorialPageRoute<T> extends PageRouteBuilder<T> {
  EditorialPageRoute({required WidgetBuilder builder})
      : super(
          pageBuilder: (context, animation, secondaryAnimation) =>
              builder(context),
          transitionDuration: const Duration(milliseconds: 350),
          reverseTransitionDuration: const Duration(milliseconds: 250),
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            final curve = CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
              reverseCurve: Curves.easeInCubic,
            );
            return FadeTransition(
              opacity: curve,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0.0, 0.03),
                  end: Offset.zero,
                ).animate(curve),
                child: RepaintBoundary(child: child),
              ),
            );
          },
        );
}

/// Custom page transition: slow fade + slight slide up for forward pushes.
CustomTransitionPage<void> _slideUpTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return buildEditorialTransition<void>(
    context: context,
    state: state,
    child: child,
  );
}

/// Custom page transition: fade-through for shell tab switches.
CustomTransitionPage<void> _fadeTransition(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      return FadeTransition(
        opacity: CurvedAnimation(
          parent: animation,
          curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
        ),
        child: RepaintBoundary(child: child),
      );
    },
  );
}

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
            Icon(Icons.error_outline, size: 48, color: scheme.error),
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
            pageBuilder: (context, state) => _fadeTransition(
              context,
              state,
              const HomeScreen(),
            ),
          ),
          GoRoute(
            path: '/notebooks',
            pageBuilder: (context, state) => _fadeTransition(
              context,
              state,
              const CollectionsScreen(initialTab: 0),
            ),
          ),
          GoRoute(
            path: '/notebooks/:notebookId',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              NotebookDetailScreen(
                notebookId: state.pathParameters['notebookId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/tags',
            pageBuilder: (context, state) => _fadeTransition(
              context,
              state,
              const CollectionsScreen(initialTab: 1),
            ),
          ),
          GoRoute(
            path: '/tags/:tagId',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              TagDetailScreen(
                tagId: state.pathParameters['tagId']!,
              ),
            ),
          ),
          GoRoute(
            path: '/trash',
            pageBuilder: (context, state) => _fadeTransition(
              context,
              state,
              const TrashScreen(),
            ),
          ),
          GoRoute(
            path: '/settings',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              const SettingsScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/appearance',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              const SettingsAppearanceScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/security',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              const SettingsSecurityScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/storage',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              const SettingsStorageScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/sync-devices',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              const SettingsSyncDevicesScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/about',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              const SettingsAboutScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/privacy',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              const SettingsPrivacyScreen(),
            ),
          ),
          GoRoute(
            path: '/settings/logs',
            pageBuilder: (context, state) => _slideUpTransition(
              context,
              state,
              const SettingsLogsScreen(),
            ),
          ),
        ],
      ),
      GoRoute(
        path: '/home/search',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          const SearchScreen(),
        ),
      ),
      GoRoute(
        path: '/locked',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          const LockedNotesScreen(),
        ),
      ),
      GoRoute(
        path: '/note/new',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          NoteEditorScreen(
            notebookId: state.uri.queryParameters['notebookId'],
            type: state.uri.queryParameters['type'],
          ),
        ),
      ),
      GoRoute(
        path: '/note/:noteId',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          NoteEditorScreen(
            noteId: state.pathParameters['noteId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/note/:noteId/doodle/:attachmentId',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          DoodleCanvasScreen(
            noteId: state.pathParameters['noteId']!,
            attachmentId: state.pathParameters['attachmentId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/sync',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          const SyncScreen(),
        ),
      ),
      GoRoute(
        path: '/sync/send',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          const SyncSendScreen(),
        ),
      ),
      GoRoute(
        path: '/sync/receive',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          const SyncReceiveScreen(),
        ),
      ),
      GoRoute(
        path: '/sync/pairing',
        pageBuilder: (context, state) {
          final extra = state.extra as Map<String, String>? ?? {};
          return _slideUpTransition(
            context,
            state,
            SyncPairingScreen(
              pairingCode: extra['pairingCode'] ?? '000000',
              deviceName: extra['deviceName'] ?? 'Unknown Device',
            ),
          );
        },
      ),
      GoRoute(
        path: '/sync/transfer/:sessionId',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          SyncTransferScreen(
            sessionId: state.pathParameters['sessionId']!,
          ),
        ),
      ),
      GoRoute(
        path: '/sync/history',
        pageBuilder: (context, state) => _slideUpTransition(
          context,
          state,
          const SyncHistoryScreen(),
        ),
      ),
    ],
  );
});
