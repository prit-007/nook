import 'package:flutter/material.dart';

import 'features/web/web_companion_app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const WebCompanionApp());
}
