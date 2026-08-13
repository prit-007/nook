import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:appflowy_editor/appflowy_editor.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/theme/app_theme.dart';
import 'core/providers/biometric_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/router.dart';
import 'features/security/frosted_shield.dart';

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
    final gate = ref.read(biometricGateProvider);
    switch (state) {
      case AppLifecycleState.resumed:
        gate.onAppResumed();
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
      routerConfig: router,
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        AppFlowyEditorLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en')],
      builder: (context, child) => Stack(
        children: [
          child ?? const SizedBox.shrink(),
          const FrostedShield(),
        ],
      ),
    );
  }
}
