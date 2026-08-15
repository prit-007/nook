import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/biometric_provider.dart';
import 'core/providers/talker_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router.dart';
import 'core/widgets/keyboard_shortcuts.dart';
import 'features/security/frosted_shield.dart';
import 'features/updates/update_provider.dart';

class NookApp extends ConsumerStatefulWidget {
  const NookApp({super.key});

  @override
  ConsumerState<NookApp> createState() => _NookAppState();
}

class _NookAppState extends ConsumerState<NookApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    talker.debug('App lifecycle → $state');
    final gate = ref.read(biometricGateProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        gate.onAppResumed();
        unawaited(
          ref.read(updateStatusProvider.notifier).checkIfStale(),
        );
      case AppLifecycleState.paused:
        gate.onAppPaused();
      case AppLifecycleState.inactive:
      case AppLifecycleState.hidden:
        gate.onAppPaused();
      default:
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePref = ref.watch(themePreferenceProvider);
    final router = ref.watch(routerProvider);
    final seed = themePref.seedColor;

    return MaterialApp.router(
      title: 'Nook',
      theme: buildLightTheme(seed),
      darkTheme: buildDarkTheme(seed, amoled: themePref.amoledDark),
      themeMode: themePref.themeMode,
      // Flutter can interpolate text shadows through a negative radius while
      // a ColorScheme is replaced. There are no useful animated theme values
      // in Nook, so rebuild the theme atomically instead.
      themeAnimationDuration: Duration.zero,
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      builder: (context, child) => NookKeyboardShortcuts(
        child: Stack(
          children: [
            child ?? const SizedBox.shrink(),
            const FrostedShield(),
          ],
        ),
      ),
    );
  }
}
