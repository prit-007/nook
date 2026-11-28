import 'main_native.dart' if (dart.library.js_interop) 'main_web.dart' as entry;

Future<void> main() => entry.main();
