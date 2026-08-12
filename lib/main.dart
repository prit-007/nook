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

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'app.dart';
import 'core/providers/biometric_provider.dart';
import 'core/providers/database_provider.dart';
import 'core/providers/pin_provider.dart';
import 'core/providers/screenshot_blocker_provider.dart';
import 'core/providers/theme_provider.dart';
import 'data/database.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final results = await Future.wait([
    ThemePreference.load(),
    BiometricGate.load(),
    ScreenshotBlocker.load(),
    PinProvider.load(),
  ]);

  final themePref = results[0] as ThemePreference;
  final biometricGate = results[1] as BiometricGate;
  final screenshotBlocker = results[2] as ScreenshotBlocker;
  final pinProv = results[3] as PinProvider;

  // Apply screenshot blocker flag on startup if persisted.
  await screenshotBlocker.applyPersisted();

  // Open the encrypted on-disk database. Falls back to an in-memory database
  // on platforms without SQLCipher support (e.g. bare desktop/web dev runs).
  late final AppDatabase db;
  try {
    db = await openEncryptedDatabase();
  } catch (_) {
    db = AppDatabase(NativeDatabase.memory());
  }

  runApp(
    ProviderScope(
      overrides: [
        themePreferenceProvider.overrideWith((ref) => themePref),
        biometricGateProvider.overrideWith((ref) => biometricGate),
        screenshotBlockerProvider.overrideWith((ref) => screenshotBlocker),
        pinProvider.overrideWith((ref) => pinProv),
        databaseProvider.overrideWith((ref) => db),
      ],
      child: const NookApp(),
    ),
  );
}
