// Nook — a private, local-first notes app.
// Copyright (C) 2026 Nook Authors
//
// This program is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This program is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <https://www.gnu.org/licenses/>.

import 'dart:async';
import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'app.dart';
import 'core/platform/global_hotkeys.dart';
import 'core/platform/system_tray.dart';
import 'core/providers/biometric_provider.dart';
import 'core/providers/database_provider.dart';
import 'core/providers/navigation_preference.dart';
import 'core/providers/pin_provider.dart';
import 'core/providers/screenshot_blocker_provider.dart';
import 'core/providers/talker_provider.dart';
import 'core/providers/theme_provider.dart';
import 'core/providers/trash_retention_provider.dart';
import 'core/providers/vault_password_provider.dart';
import 'core/providers/voice_preference_provider.dart';
import 'core/security/dek_manager.dart';
import 'data/database.dart';
import 'data/repositories/trash_auto_purger.dart';
import 'features/quick_note/quick_note_overlay.dart';
import 'features/security/vault_db_gate_screen.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Route framework and uncaught async errors into the talker log history so
  // they are visible in Settings → Developer → App Logs.
  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    talker.handle(details.exception, details.stack, details.library);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    talker.handle(error, stack);
    return true;
  };

  talker.info('App started');

  final results = await Future.wait([
    ThemePreference.load(),
    BiometricGate.load(),
    ScreenshotBlocker.load(),
    PinProvider.load(),
    VaultPasswordProvider.load(),
    NavigationPreference.load(),
    NavigationPreference.isOnboardingCompleted(),
    TrashRetentionPreference.load(),
    VoicePreference.load(),
  ]);

  final themePref = results[0] as ThemePreference;
  final biometricGate = results[1] as BiometricGate;
  final screenshotBlocker = results[2] as ScreenshotBlocker;
  final pinProv = results[3] as PinProvider;
  final vaultProv = results[4] as VaultPasswordProvider;
  final navigationPreference = results[5] as NavigationPreference;
  final onboardingCompleted = results[6] as bool;
  final trashRetentionPref = results[7] as TrashRetentionPreference;
  final voicePref = results[8] as VoicePreference;

  // If onboarding hasn't been completed, force the initial route to onboarding.
  if (!onboardingCompleted) {
    navigationPreference.overrideRoute('/onboarding');
  }

  talker.info('Preferences loaded');

  // Apply screenshot blocker flag on startup if persisted.
  await screenshotBlocker.applyPersisted();

  // Open the encrypted on-disk database. When C2 DEK wrapping is enabled,
  // gate opening behind VaultDbGateScreen until the user unwraps the DEK.
  final dekManager = DekManager();
  await dekManager.recoverInterruptedWrap();
  final isDekWrapped = await dekManager.isWrapped();
  if (isDekWrapped) {
    final hasRecovery = await dekManager.hasRecoveryWrappedDek();
    runApp(
      _VaultGateBootApp(
        dekManager: dekManager,
        hasRecoveryKey: hasRecovery,
        themePref: themePref,
        biometricGate: biometricGate,
        screenshotBlocker: screenshotBlocker,
        pinProv: pinProv,
        vaultProv: vaultProv,
        navigationPreference: navigationPreference,
        trashRetentionPref: trashRetentionPref,
        voicePref: voicePref,
      ),
    );
    return;
  }

  late final AppDatabase db;
  try {
    db = await openEncryptedDatabase();
    talker.info('DB opened');
  } catch (e) {
    db = AppDatabase(NativeDatabase.memory());
    talker.warning('DB fallback to memory: $e');
  }

  _launchMainApp(
    db: db,
    themePref: themePref,
    biometricGate: biometricGate,
    screenshotBlocker: screenshotBlocker,
    pinProv: pinProv,
    vaultProv: vaultProv,
    navigationPreference: navigationPreference,
    trashRetentionPref: trashRetentionPref,
    voicePref: voicePref,
  );
}

void _launchMainApp({
  required AppDatabase db,
  required ThemePreference themePref,
  required BiometricGate biometricGate,
  required ScreenshotBlocker screenshotBlocker,
  required PinProvider pinProv,
  required VaultPasswordProvider vaultProv,
  required NavigationPreference navigationPreference,
  required TrashRetentionPreference trashRetentionPref,
  required VoicePreference voicePref,
}) {
  // Soft-deleted items older than the retention window are purged on cold
  // start so the Bin matches the "auto-deletes after N days" promise.
  // Failures are logged — never block app startup on a purge error.
  unawaited(
    TrashAutoPurger(db, retentionDays: trashRetentionPref.days)
        .purgeExpired()
        .catchError((Object e) {
      talker.warning('Trash auto-purge failed: $e');
      return const TrashPurgeResult();
    }),
  );

  runApp(
    ProviderScope(
      overrides: [
        themePreferenceProvider.overrideWith((ref) => themePref),
        biometricGateProvider.overrideWith((ref) => biometricGate),
        screenshotBlockerProvider.overrideWith((ref) => screenshotBlocker),
        pinProvider.overrideWith((ref) => pinProv),
        vaultPasswordProvider.overrideWith((ref) => vaultProv),
        trashRetentionProvider.overrideWith((ref) => trashRetentionPref),
        voicePreferenceProvider.overrideWith((ref) => voicePref),
        navigationPreferenceProvider
            .overrideWith((ref) => navigationPreference),
        databaseProvider.overrideWith((ref) => db),
      ],
      child: const NookApp(),
    ),
  );

  // Initialize desktop features (system tray + global hotkeys) after the
  // first frame renders so the navigator is available.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    NookSystemTray.initialize(
      onQuickNote: () {
        // The navigator is available via NookApp's GlobalKey.
        final context = NookApp.navigatorKey.currentContext;
        if (context != null) {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) => const QuickNoteOverlay(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        }
      },
      onShowWindow: () {
        // Window manager show/focus — handled by window_manager package.
      },
    );

    NookGlobalHotkeys.initialize(
      onQuickNote: () {
        final context = NookApp.navigatorKey.currentContext;
        if (context != null) {
          Navigator.of(context).push(
            PageRouteBuilder(
              opaque: false,
              pageBuilder: (_, __, ___) => const QuickNoteOverlay(),
              transitionsBuilder: (_, animation, __, child) =>
                  FadeTransition(opacity: animation, child: child),
            ),
          );
        }
      },
    );
  });
}

class _VaultGateBootApp extends StatelessWidget {
  const _VaultGateBootApp({
    required this.dekManager,
    required this.hasRecoveryKey,
    required this.themePref,
    required this.biometricGate,
    required this.screenshotBlocker,
    required this.pinProv,
    required this.vaultProv,
    required this.navigationPreference,
    required this.trashRetentionPref,
    required this.voicePref,
  });

  final DekManager dekManager;
  final bool hasRecoveryKey;
  final ThemePreference themePref;
  final BiometricGate biometricGate;
  final ScreenshotBlocker screenshotBlocker;
  final PinProvider pinProv;
  final VaultPasswordProvider vaultProv;
  final NavigationPreference navigationPreference;
  final TrashRetentionPreference trashRetentionPref;
  final VoicePreference voicePref;

  @override
  Widget build(BuildContext context) {
    final seed = themePref.seedColor;
    final lightScheme = ColorScheme.fromSeed(seedColor: seed);
    final darkScheme = ColorScheme.fromSeed(
      seedColor: seed,
      brightness: Brightness.dark,
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(colorScheme: lightScheme, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: darkScheme, useMaterial3: true),
      themeMode: themePref.themeMode,
      home: VaultDbGateScreen(
        dekManager: dekManager,
        hasRecoveryKey: hasRecoveryKey,
        onUnlocked: (dek, _) async {
          late final AppDatabase db;
          try {
            db = await openEncryptedDatabase(overrideKey: dek);
            talker.info('DB opened after C2 vault unlock');
          } catch (e) {
            db = AppDatabase(NativeDatabase.memory());
            talker.warning('DB fallback to memory: $e');
          }
          vaultProv.markUnlockedWithDek(dek);
          _launchMainApp(
            db: db,
            themePref: themePref,
            biometricGate: biometricGate,
            screenshotBlocker: screenshotBlocker,
            pinProv: pinProv,
            vaultProv: vaultProv,
            navigationPreference: navigationPreference,
            trashRetentionPref: trashRetentionPref,
            voicePref: voicePref,
          );
        },
      ),
    );
  }
}
