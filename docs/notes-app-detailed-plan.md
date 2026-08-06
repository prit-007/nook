# Detailed Technical Plan — "Own Your Notes"
### Deep-dive companion to the master plan: schema, architecture, protocols, and screen-level specs

This document assumes you've read `notes-app-masterplan.md`. It goes one level deeper into *how* to actually build each piece.

---

## 1. Package List (exact, pin these in `pubspec.yaml`)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # State & navigation
  flutter_riverpod: ^2.6.1
  riverpod_annotation: ^2.6.1
  go_router: ^14.6.2

  # Local database
  drift: ^2.22.1
  sqlite3_flutter_libs: ^0.5.28
  sqlcipher_flutter_libs: ^0.6.4      # encrypted SQLite build
  path_provider: ^2.1.5
  path: ^1.9.0

  # Theming
  dynamic_color: ^1.7.0
  palette_generator: ^0.3.3.6         # extract dominant color from cover images

  # Editor — block/node-based, not Delta/linear (see §6 for why this matters)
  appflowy_editor: ^4.0.0             # confirm latest on pub.dev before pinning
  appflowy_editor_plugins: ^1.0.0     # ready-made block components to extend

  # Doodle / drawing — build custom on CustomPainter (no good maintained
  # standalone package exists as of 2026); study Saber's renderer for reference
  perfect_freehand: ^2.4.0            # stroke smoothing algorithm (FOSS, MIT)

  # Media
  image_picker: ^1.1.2
  gal: ^2.3.1                         # save note snapshots to gallery
  image: ^4.3.0                       # thumbnail generation / compression

  # Security
  local_auth: ^2.3.0
  flutter_secure_storage: ^9.2.2      # holds the DB encryption key (platform keystore)

  # Nearby sync
  nearby_service: ^2.0.2              # confirm latest on pub.dev before pinning
  crypto: ^3.0.5                      # payload checksums
  cbor: ^6.3.4                        # compact binary payload for sync bundles

  # Utilities
  uuid: ^4.5.1
  intl: ^0.19.0
  freezed_annotation: ^2.4.4
  json_annotation: ^4.9.0

dev_dependencies:
  build_runner: ^2.4.14
  drift_dev: ^2.22.1
  riverpod_generator: ^2.6.3
  freezed: ^2.5.7
  json_serializable: ^6.9.0
  flutter_lints: ^5.0.0
```

> Always re-check exact latest versions on pub.dev before you `flutter pub get` — the ecosystem moves fast, this list is your starting point not gospel.

---

## 2. Drift Schema (actual code)

```dart
// lib/data/tables/notebooks.dart
import 'package:drift/drift.dart';

class Notebooks extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().withLength(min: 1, max: 100)();
  TextColumn get colorSeed => text()();          // hex string, e.g. "#6750A4"
  TextColumn get icon => text().withDefault(const Constant('notebook'))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();

  @override
  Set<Column> get primaryKey => {id};
}

// lib/data/tables/notes.dart
class Notes extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get notebookId =>
      text().nullable().references(Notebooks, #id)();
  TextColumn get type => textEnum<NoteType>()();      // text | checklist | doodle | mixed
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get deltaContent => text().nullable()();  // Quill Delta JSON
  TextColumn get colorSeed => text().nullable()();     // per-note override
  TextColumn get coverImagePath => text().nullable()();
  BoolColumn get pinned => boolean().withDefault(const Constant(false))();
  BoolColumn get locked => boolean().withDefault(const Constant(false))();
  BoolColumn get deleted => boolean().withDefault(const Constant(false))(); // soft delete
  DateTimeColumn get deletedAt => dateTime().nullable()();
  DateTimeColumn get createdAt => dateTime().clientDefault(DateTime.now)();
  DateTimeColumn get updatedAt => dateTime().clientDefault(DateTime.now)();

  // Sync bookkeeping — put this in from day one
  TextColumn get deviceOriginId => text()();
  IntColumn get syncVersion => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class ChecklistItems extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get text => text()();
  BoolColumn get checked => boolean().withDefault(const Constant(false))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Attachments extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get type => textEnum<AttachmentType>()();  // image | doodleLayer
  TextColumn get filePath => text()();
  TextColumn get thumbnailPath => text().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();

  @override
  Set<Column> get primaryKey => {id};
}

class Tags extends Table {
  TextColumn get id => text().clientDefault(() => const Uuid().v4())();
  TextColumn get name => text().withLength(min: 1, max: 50)();
  TextColumn get colorSeed => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class NoteTags extends Table {
  TextColumn get noteId => text().references(Notes, #id)();
  TextColumn get tagId => text().references(Tags, #id)();

  @override
  Set<Column> get primaryKey => {noteId, tagId};
}

class SyncLog extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get deviceId => text()();
  TextColumn get deviceName => text()();
  TextColumn get noteId => text()();
  TextColumn get action => textEnum<SyncAction>()();   // sent | received | conflict
  DateTimeColumn get timestamp => dateTime().clientDefault(DateTime.now)();
}
```

Add a full-text search virtual table for the search screen:

```dart
// Drift supports FTS5 virtual tables directly
@DriftDatabase(tables: [Notebooks, Notes, ChecklistItems, Attachments,
    Tags, NoteTags, SyncLog])
class AppDatabase extends _$AppDatabase {
  AppDatabase(super.e);

  @override
  int get schemaVersion => 1;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await customStatement(
        'CREATE VIRTUAL TABLE notes_fts USING fts5(id UNINDEXED, title, plain_text)',
      );
    },
  );
}
```

Keep `plain_text` as a denormalized column you regenerate from the Quill Delta on every save (Quill's `Document.toPlainText()`) — this is what FTS actually indexes, since you can't FTS-search a JSON blob usefully.

---

## 3. Encryption Setup (SQLCipher + secure key storage)

```dart
Future<AppDatabase> openEncryptedDatabase() async {
  final dir = await getApplicationDocumentsDirectory();
  final dbFile = File(p.join(dir.path, 'notes.db'));

  const secureStorage = FlutterSecureStorage();
  var key = await secureStorage.read(key: 'db_encryption_key');
  if (key == null) {
    key = _generateRandomKey(32); // cryptographically random, base64
    await secureStorage.write(key: 'db_encryption_key', value: key);
  }

  final executor = NativeDatabase.createInBackground(
    dbFile,
    setup: (rawDb) {
      rawDb.execute("PRAGMA key = '$key';");
      rawDb.execute('PRAGMA cipher_page_size = 4096;');
    },
  );
  return AppDatabase(executor);
}
```

- The encryption key never touches your own code as a hardcoded string — it's generated once, stored in Android Keystore/iOS Keychain via `flutter_secure_storage`, and only decrypts the DB at runtime.
- Biometric gate (`local_auth`) sits **in front of** this — i.e., app requires biometric success before it even attempts to read the secure-storage key. Two independent layers.
- On "export all notes," decrypt to plaintext markdown/JSON only into a temp file the OS share sheet handles, then immediately delete the temp file.

---

## 4. Riverpod Architecture (provider tree)

```
databaseProvider              → AppDatabase (singleton, encrypted, opened once)
notebookRepositoryProvider    → wraps Notebooks DAO
noteRepositoryProvider        → wraps Notes/ChecklistItems/Attachments DAOs
tagRepositoryProvider

notesListProvider(filter)     → StreamProvider, reactive query from Drift
                                 (Drift streams push updates automatically —
                                 no manual refresh needed anywhere in the UI)
noteEditorProvider(noteId)    → StateNotifier holding in-progress edits,
                                 autosaves via debounce (e.g. 600ms after typing stops)

themeProvider                 → derives ColorScheme from:
                                 system dynamic color (if enabled) OR
                                 manual seed OR
                                 per-note seed (only inside the editor screen)

biometricGateProvider         → app-level lock state machine
syncProvider                  → nearby discovery state, transfer progress,
                                 pairing/trust state
```

Repositories are the only layer that talks to Drift directly — screens/widgets only ever see Riverpod providers. This keeps the sync engine (which also needs to read/write notes) decoupled from UI.

---

## 5. Theming System — Per-Note Material You in Practice

The trick to doing this without visual chaos: **the app chrome (nav bars, FAB, settings) always uses the *global* dynamic/manual seed.** Only the *editor screen's* local widgets (toolbar, background tint, card highlight when you return to Home) use the *note's own* seed. Never let a note's color bleed outside its own card/editor.

```dart
ColorScheme buildSchemeForSeed(Color seed, Brightness brightness) {
  return ColorScheme.fromSeed(
    seedColor: seed,
    brightness: brightness,
  );
}
```

**Seed color sources, in priority order, when creating a note:**
1. User explicitly picks a color from the swatch picker (12–16 curated M3-friendly seeds, not a raw color wheel — constraint breeds better results).
2. If the note has a cover image: run `palette_generator` on it, take the dominant vibrant swatch, snap it to the nearest M3 seed-friendly hue.
3. Otherwise: inherit the notebook's color, or fall back to the global app seed.

```dart
Future<Color> deriveSeedFromImage(File imageFile) async {
  final palette = await PaletteGenerator.fromImageProvider(
    FileImage(imageFile),
    maximumColorCount: 12,
  );
  return palette.vibrantColor?.color ??
      palette.dominantColor?.color ??
      const Color(0xFF6750A4); // sensible default fallback
}
```

For system dynamic color (Android 12+ wallpaper-based), wrap the app root:

```dart
DynamicColorBuilder(
  builder: (lightDynamic, darkDynamic) {
    final useDynamic = ref.watch(useDynamicColorProvider);
    final light = useDynamic && lightDynamic != null
        ? lightDynamic
        : ColorScheme.fromSeed(seedColor: manualSeed);
    final dark = useDynamic && darkDynamic != null
        ? darkDynamic
        : ColorScheme.fromSeed(seedColor: manualSeed, brightness: Brightness.dark);
    return MaterialApp.router(
      theme: ThemeData(colorScheme: light, useMaterial3: true),
      darkTheme: ThemeData(colorScheme: dark, useMaterial3: true),
      ...
    );
  },
)
```

---

## 6. Editor Engine — AppFlowy Editor (replaces flutter_quill)

### 6.1 Why this swap matters for *this* product specifically

flutter_quill models a document as one linear **Delta** (a flat sequence of text runs and inline "embeds"). AppFlowy Editor models a document as a **tree of Nodes** — the same conceptual model as Notion's block editor. Concretely:

| | flutter_quill (Delta) | appflowy_editor (Node tree) |
|---|---|---|
| Data shape | Flat list of `{insert, attributes}` ops | Tree of `Node{type, attributes, children}` |
| Checklist item | An inline "embed" bolted into the text stream | A first-class `todo_list` node with its own `checked` attribute, nestable, independently stylable |
| Doodle / image | Custom embed block, has to fight the linear text-flow model for layout | A first-class block node (`image`, or your custom `doodle` type) that sits in the tree like any other block — no fighting the text flow |
| Mixed note (text + checklist + doodle in one note) | Awkward — Quill wasn't designed to compose heterogeneous block types cleanly | Natural — this is exactly what the tree model is for |
| Nesting (sub-checklist, indented notes) | Not really supported | Native, since children live directly on the node |
| Precedent | — | AppFlowy itself migrated away from Quill for precisely these reasons (see prior message) |

Since your product's whole differentiator is "one note can artistically mix text, a checklist, a doodle, and an image, each themed," the node-tree model is the right foundation — you're not fighting the library to get the behavior you actually want.

### 6.2 Document Storage Change

This changes what you store in `Notes.deltaContent`. Instead of a Quill Delta JSON, you store the **AppFlowy Editor document JSON** (a serialized node tree):

```dart
// Renamed conceptually — same column, different content shape.
// Notes.deltaContent now holds:
{
  "document": {
    "type": "page",
    "children": [
      { "type": "paragraph", "attributes": { "delta": [{"insert": "Grocery run"}] } },
      { "type": "todo_list", "attributes": { "checked": false, "delta": [{"insert": "Milk"}] } },
      { "type": "todo_list", "attributes": { "checked": true,  "delta": [{"insert": "Eggs"}] } },
      { "type": "doodle", "attributes": { "attachmentId": "a1b2c3", "aspectRatio": 1.4 } },
      { "type": "image",  "attributes": { "attachmentId": "d4e5f6" } }
    ]
  }
}
```

`EditorState.document.toJson()` / `Document.fromJson()` give you this for free — same "store as JSON, never as HTML/Markdown" principle from the master plan still applies, just at the tree level instead of the Delta level.

### 6.3 Basic Wiring

```dart
final editorState = EditorState(document: Document.fromJson(storedJson));

AppFlowyEditor(
  editorState: editorState,
  editorStyle: buildEditorStyleFromNoteSeed(noteColorScheme), // see §6.5
  blockComponentBuilders: _buildComponentMap(),
  characterShortcutEvents: standardCharacterShortcutEvents,
  commandShortcutEvents: standardCommandShortcutEvents,
);
```

Every edit goes through a `Transaction` (insert/update/delete node operations) applied to `EditorState` — this is also your natural hook point for autosave: listen to `editorState.transactionStream`, debounce ~600ms, serialize `document.toJson()`, write to Drift.

### 6.4 Custom Node Types You'll Build

The built-in `paragraph`, `todo_list`, `bulleted_list`, `numbered_list`, `quote`, `image` block types cover most of it out of the box (via `appflowy_editor_plugins`). You add two custom node types of your own:

**`doodle` node** — wraps your `DoodleCanvas` widget (§7) inline in the document flow:
```dart
class DoodleBlockComponentBuilder extends BlockComponentBuilder {
  @override
  BlockComponentWidget build(BlockComponentContext context) {
    final node = context.node;
    final attachmentId = node.attributes['attachmentId'] as String;
    final aspectRatio = (node.attributes['aspectRatio'] as num).toDouble();
    return DoodleBlockWidget(
      key: context.node.key,
      node: node,
      attachmentId: attachmentId,
      aspectRatio: aspectRatio,
      editorState: context.editorState,
    );
  }

  @override
  BlockComponentValidate get validate => (node) =>
      node.attributes['attachmentId'] is String;
}
```
`DoodleBlockWidget` renders a thumbnail of the doodle inline; tapping it opens the full-screen `DoodleCanvas` editor (§7), and on save it writes back the updated PNG/stroke-data to the `Attachments` table and just keeps the `attachmentId` reference in the node — the document tree stays lightweight, binary data lives in your attachments table/filesystem as already planned.

**`checklist-item` styling override** — the built-in `todo_list` node is functionally right, but for your "enjoy the note-taking" goal you'll want to override its `BlockComponentBuilder` to add the strikethrough animation and swipe-to-check gesture from the master plan's §5.3, rather than the default static checkbox. This is exactly the pattern AppFlowy's own docs demonstrate ("Todo List Block Component demonstrates how to extend new styles based on existing rich text components") — you're not writing a node type from scratch, just re-skinning the existing one.

Register both in the builder map:
```dart
Map<String, BlockComponentBuilder> _buildComponentMap() => {
  ...standardBlockComponentBuilderMap,   // paragraph, lists, quote, image, etc.
  'todo_list': CustomTodoListBlockComponentBuilder(), // your re-skinned version
  'doodle': DoodleBlockComponentBuilder(),            // your custom type
};
```

### 6.5 Theming Integration (ties back to §5's per-note seed color)

`EditorStyle` in AppFlowy Editor exposes granular control over text style, block padding, cursor color, selection color, etc. — build it directly from the note's derived `ColorScheme`:

```dart
EditorStyle buildEditorStyleFromNoteSeed(ColorScheme scheme) {
  return EditorStyle.desktop(
    cursorColor: scheme.primary,
    selectionColor: scheme.primaryContainer.withOpacity(0.4),
    textStyleConfiguration: TextStyleConfiguration(
      text: TextStyle(color: scheme.onSurface, fontSize: 16, height: 1.5),
      bold: TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface),
      href: TextStyle(color: scheme.primary, decoration: TextDecoration.underline),
    ),
    textSpanDecorator: (context, node, index, text, before, after) => before,
  );
}
```

This is what makes "different notes, different themes, dynamically" actually reach into the editor itself rather than just the surrounding chrome — the cursor, selection highlight, checkbox tint, and link color all shift with the note's own seed color, while your `todo_list` override and `doodle` block both read the same `ColorScheme` for their own painting.

### 6.6 Things to Know / Gotchas Before You Start

- **Mobile support is newer than desktop/web support** in this library's history — test touch gestures (selection handles, long-press menu, slash-command menu) early on real Android devices, don't assume desktop-verified behavior transfers 1:1.
- **Localization delegate is required** — `AppFlowyEditorLocalizations.delegate` must be added to your `MaterialApp.localizationsDelegates` or the editor throws at runtime. Easy to miss, easy fix.
- **No built-in Drift/database persistence** — that's expected and fine, you're already doing your own persistence layer; just remember autosave is *your* responsibility via the transaction stream, not something the package does for you.
- **Slash-command menu (`/`) is where "enjoyable" UX lives** — this is the moment a user decides "insert checklist," "insert doodle," "insert image." Skin this menu with your app's iconography and the note's seed color; it's a small surface area with outsized impact on how premium the app feels.
- **Migration path if this ever becomes limiting**: because you're storing your own JSON node tree (not tied to Quill Delta), swapping the *rendering* layer later without losing data is realistic — the risk this swap protects you from is exactly the one AppFlowy itself hit.

---

## 7. Doodle Canvas — Technical Design

Since there's no well-maintained standalone FOSS doodle-editor *package* for Flutter in 2026 (Saber is a full app, not a reusable package), build this as its own widget:

**Core pieces:**
- `DoodleController` (ChangeNotifier): holds `List<Stroke>`, undo/redo stacks, current tool (pen/highlighter/eraser), current color/width.
- `Stroke`: `{points: List<Offset>, pressure: List<double>?, color, width, tool}`.
- Use **`perfect_freehand`** (MIT-licensed Dart port of the popular freehand stroke-smoothing algorithm) to convert raw point lists into smooth variable-width polygons — this is the single biggest visual-quality lever for a drawing feature, don't hand-roll stroke smoothing.
- Render via `CustomPainter`, repainting only the current in-progress stroke each frame (keep committed strokes cached in a `Picture` via `PictureRecorder` so old strokes aren't re-rasterized every frame — critical for performance on longer doodles).
- Background templates: blank / dotted grid / ruled lines / graph — drawn as a separate cheap `CustomPainter` layer beneath the strokes.
- Pressure input: `Listener` with `onPointerDown/Move` gives you `event.pressure` on supported stylus hardware (S-Pen etc.); fall back to constant width on plain touch.
- Export: `RepaintBoundary` wrapping the whole canvas → `toImage()` → PNG bytes, used both for the "save doodle as attachment" path and the "export note as image" feature.

**Layers (optional but nice for "artistic" positioning):** store `List<DoodleLayer>` each with its own strokes + opacity + visibility, composited bottom-to-top. Even 2–3 layers (sketch / ink / highlight) feels premium without much extra complexity.

---

## 8. Note → Image Export / "Save as Image" Feature

```dart
final boundaryKey = GlobalKey();

// Wrap the note's rendered content in:
RepaintBoundary(key: boundaryKey, child: NoteRenderWidget(note: note));

Future<void> exportNoteAsImage() async {
  final boundary = boundaryKey.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
  final image = await boundary.toImage(pixelRatio: 3.0); // high-res
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngBytes = byteData!.buffer.asUint8List();

  await Gal.putImageBytes(pngBytes, name: 'note_${note.id}');
}
```

Build a dedicated `NoteRenderWidget` (separate from the interactive editor widget) that lays out the note purely for visual export — title, content, checklist state, doodle, all styled with the note's own color seed — so exported images look like intentional shareable cards, not a screenshot of an editing UI.

---

## 9. Nearby Sync — Full Protocol Spec

### 8.1 Roles & State Machine
```
IDLE → ADVERTISING (receiver) / DISCOVERING (sender)
     → DEVICE_FOUND → PAIRING_CONFIRM (numeric code shown both sides)
     → CONNECTED → TRANSFERRING → COMPLETE / FAILED → IDLE
```
Both devices must show and confirm the same short numeric code (derived from the connection's shared secret, like Bluetooth "just works" pairing) before any payload transfers — this prevents connecting to the wrong nearby stranger's device by accident.

### 8.2 Payload Format (CBOR-encoded bundle)
```dart
class SyncBundle {
  final String protocolVersion;      // "1.0"
  final String senderDeviceId;
  final String senderDeviceName;
  final DateTime sentAt;
  final List<SyncNoteEntry> notes;
}

class SyncNoteEntry {
  final String noteId;
  final int syncVersion;
  final DateTime updatedAt;
  final String deviceOriginId;
  final Map<String, dynamic> noteFields;   // full Notes row
  final List<Map<String, dynamic>> checklistItems;
  final List<AttachmentBlob> attachments;  // binary, chunked separately
}
```

Serialize with `cbor` (compact, binary, well-suited for the byte-stream transport `nearby_service` exposes) rather than raw JSON — smaller payloads matter over Wi-Fi Direct's throughput, especially with image/doodle attachments.

### 8.3 Transfer Flow
1. Sender selects note(s) → builds `SyncBundle` → computes SHA-256 checksum of the whole serialized bundle.
2. Sender sends bundle size + checksum as a small header message first.
3. Sender streams the bundle in fixed-size chunks (e.g. 64KB) with sequence numbers.
4. Receiver reassembles, verifies checksum, only then deserializes — reject and request resend on mismatch rather than silently accepting corrupt data.
5. Receiver runs each `SyncNoteEntry` through the **merge resolver** (below).
6. Receiver sends an ack (`{received: [noteIds], rejected: [noteIds]}`) back to sender.
7. Both sides write a `SyncLog` row.

### 8.4 Merge Resolver (the part that protects user trust)
```dart
Future<MergeAction> resolveIncoming(SyncNoteEntry incoming) async {
  final existing = await noteRepo.findById(incoming.noteId);

  if (existing == null) {
    return MergeAction.insertAsNew; // straightforward: brand-new note appears
  }
  if (incoming.syncVersion <= existing.syncVersion &&
      incoming.updatedAt.isBefore(existing.updatedAt)) {
    return MergeAction.ignore; // we already have the newer version
  }
  if (incoming.deviceOriginId == existing.deviceOriginId) {
    return MergeAction.overwrite; // genuinely the same lineage, just newer edit
  }
  // Same note ID but edited independently on two devices — true conflict
  return MergeAction.promptUser;
}
```

For `promptUser`, surface a small conflict card in the Sync screen: "Note 'Groceries' was edited on both devices. [Keep this device's version] [Keep incoming version] [Keep both as separate notes]." Never auto-resolve a genuine conflict silently — this is the single most trust-destroying bug class for a sync feature, so budget real QA time here (deliberately edit the same note on two emulators/devices and verify each resolution path).

### 8.5 What NOT to build v1
- No mesh/multi-hop relay (device A → B → C) — direct pairs only for v1, it's already complex enough.
- No automatic background sync — always user-initiated per the "explicit consent" principle from the master plan; you can add a "trusted devices auto-sync on Wi-Fi" convenience toggle later, once the manual flow is bulletproof.

---

## 10. Screen-Level Widget Breakdown

### 9.1 Home Grid
```
HomeScreen
 ├─ AppBarSearch (collapses into SliverAppBar on scroll)
 ├─ ViewToggle (grid/list) — persisted preference
 ├─ NotesMasonryGrid
 │   └─ NoteCard (per note)
 │       ├─ tonal background from note.colorSeed via ColorScheme.fromSeed
 │       ├─ CoverPreview (image thumb / doodle thumb / first 3 lines of text /
 │       │   checklist preview with checked-count)
 │       ├─ PinBadge (if pinned)
 │       └─ LockBadge (if locked — content preview hidden, shows blurred placeholder)
 ├─ SpeedDialFab (Text / Checklist / Doodle / Scan-image)
 └─ SyncStatusPill (only visible during/after an active sync session)
```

### 9.2 Editor
```
NoteEditorScreen
 ├─ ImmersiveAppBar (fades to transparent on scroll-down, reappears on scroll-up)
 │   ├─ ColorSwatchButton → opens ThemePickerSheet
 │   ├─ MoreMenu (lock / pin / notebook / tags / export / send nearby / trash)
 ├─ TitleField (large, borderless, auto-grows)
 ├─ Body — one of:
 │   ├─ AppFlowyEditor (text/mixed notes — checklist + doodle + image
 │   │   nodes all composed inline in the same node tree, see §6)
 │   ├─ ChecklistEditor (checklist-only notes) — ReorderableListView + swipe actions,
 │   │   a lighter-weight path than a full AppFlowyEditor instance for pure to-do notes
 │   └─ DoodleCanvas (doodle-only notes, full-screen — same widget the inline
 │       `doodle` node opens when tapped)
 └─ ContextualToolbar (appears above keyboard only when text selected/focused)
```

### 9.3 Sync Screen
```
SyncScreen
 ├─ ModeToggle (Send / Receive)
 ├─ Send mode:
 │   ├─ NoteSelectionList (checkboxes; "Select all" shortcut)
 │   └─ DiscoveredDevicesList (radar animation while scanning)
 ├─ Receive mode:
 │   └─ DiscoverableToggle + IncomingRequestCard (accept/decline)
 ├─ PairingConfirmDialog (numeric code, both devices)
 ├─ TransferProgressSheet (per-note progress, overall %, cancel button)
 └─ SyncHistoryList (past transfers, tap to view SyncLog detail)
```

---

## 11. Testing Strategy (don't skip — this is what "rock solid" actually requires)

| Layer | Approach |
|---|---|
| Data layer | Unit tests against an in-memory Drift `NativeDatabase.memory()` — test every DAO method, migration, and FTS query |
| Merge resolver | Table-driven unit tests covering every branch in §8.4 explicitly (new note, older incoming, same-lineage newer, true conflict) |
| Widgets | `flutter_test` golden tests for NoteCard in each color seed / locked / pinned state — catches theming regressions visually |
| Sync integration | Two-emulator integration test harness (Android emulators *can* talk to each other over a virtual network for Nearby Connections testing — verify this early, it's a known rough edge) |
| Crash/perf | Manual soak test: create 500+ notes with mixed types, verify grid scroll stays 60fps and search stays instant — Drift + FTS5 should handle this fine, but verify on a real low-end device, not just your dev phone |

---

## 12. Task-Level Roadmap (expands Phase 0–2 from the master plan into concrete tickets)

**Phase 0 tickets:**
- [ ] Repo scaffold, lint rules, CI (analyze + test on push)
- [ ] Drift schema + migrations + FTS virtual table
- [ ] Encrypted DB bootstrap (SQLCipher + secure storage key)
- [ ] Riverpod provider skeleton + go_router routes
- [ ] Design tokens file: color seed palette (12–16 curated), type scale, spacing scale, corner radii, elevation/tonal-surface rules

**Phase 1 tickets:**
- [ ] Home grid (empty state first, then real data)
- [ ] Create/edit/delete text note, AppFlowy Editor integration + custom
      `todo_list` re-skin + slash-command menu theming (see §6)
- [ ] Notebooks CRUD + assign note to notebook
- [ ] Tags CRUD + chip picker
- [ ] Search screen wired to FTS

**Phase 2 tickets:**
- [ ] Checklist note type + reorder + swipe-to-check animation
- [ ] Doodle canvas MVP (single layer, pen + eraser, perfect_freehand smoothing)
- [ ] `doodle` custom node type registered in AppFlowy Editor's block map (§6.4)
- [ ] Image attachment picker + thumbnailing
- [ ] Note → image export (RepaintBoundary path)
- [ ] Save exported image to gallery

(Phases 3–7 task breakdowns follow the same pattern — expand each once you're actually starting that phase, since specifics will shift based on what you learn in Phases 0–2.)

---

## 13. Open Decisions to Make Before You Start Coding

1. **Minimum Android version** — `local_auth` and dynamic color both work best from API 31+ (Android 12), but you can support lower with graceful degradation (manual seed color instead of wallpaper-derived, PIN fallback instead of biometric). Decide your floor now, it affects several APIs above.
2. **Web build scope** — Drift supports web via WASM, but `nearby_service`, `local_auth`, and `sqlcipher` won't work on web. Decide whether Web is "full app" or "read/export-only companion" — I'd recommend the latter for v1 to avoid three-way platform branching everywhere.
3. **License**: GPL-3.0 vs AGPL-3.0 — AGPL matters most if you ever add a server component (you're not planning one), so plain GPL-3.0 is probably the simpler correct choice here.
