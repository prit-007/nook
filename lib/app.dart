import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dynamic_color/dynamic_color.dart';
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
    if (state == AppLifecycleState.resumed) {
      ref.read(biometricGateProvider).onAppResumed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themePref = ref.watch(themePreferenceProvider);
    final router = ref.watch(routerProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final useDynamic = themePref.useDynamicColor;
        final seed = themePref.seedColor;

        final lightScheme = useDynamic && lightDynamic != null
            ? lightDynamic
            : buildSchemeForSeed(seed, Brightness.light);
        final darkScheme = useDynamic && darkDynamic != null
            ? darkDynamic
            : buildSchemeForSeed(seed, Brightness.dark);

        return MaterialApp.router(
          title: 'Nook',
          theme: ThemeData(
            colorScheme: lightScheme,
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            colorScheme: darkScheme,
            useMaterial3: true,
          ),
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
      },
    );
  }
}
