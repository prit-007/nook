# Deep Dive Part 3 — Doodle Block, Slash Menu, Full Routing Map & Bonus FOSS Libraries
### Companion to `notes-app-masterplan.md` and `notes-app-detailed-plan.md`

---

## 1. `DoodleBlockWidget` — Tap-to-Expand + Thumbnail Sync

Goal: a doodle sits inline in the note as a thumbnail card. Tap it → full-screen canvas opens with the existing strokes loaded → user draws → on close, the thumbnail updates and the node's data is saved back into the document tree (which then flows into your normal autosave via the transaction stream from §6.3 of the detailed plan).

### 1.1 Data Shape

Keep the actual stroke data **out of the node tree** — the tree should only hold a reference, exactly like the `image` node holds a reference. Strokes are stored as a separate JSON/CBOR blob on disk (via your `Attachments` table), the node just points at it:

```dart
// Node attributes for a 'doodle' block:
{
  "type": "doodle",
  "attributes": {
    "attachmentId": "a1b2c3",       // -> Attachments.id
    "thumbnailPath": "a1b2c3_thumb.png",  // cached raster preview, regenerated on save
    "aspectRatio": 1.4,
    "backgroundTemplate": "dotted"  // blank | dotted | ruled | grid
  }
}
```

The stroke data itself (vector, editable) lives in a sidecar file, e.g. `attachments/a1b2c3.strokes.json`:
```dart
class StrokeData {
  final List<Stroke> strokes;
  final int backgroundTemplateVersion;
}
```

This split matters: the thumbnail PNG is what renders cheaply inline in the editor (no need to re-run `perfect_freehand` smoothing on every scroll frame), while the vector stroke data is only loaded when the user actually opens the full canvas to keep editing.

### 1.2 The Inline Widget

```dart
class DoodleBlockWidget extends StatefulWidget {
  const DoodleBlockWidget({
    super.key,
    required this.node,
    required this.editorState,
  });

  final Node node;
  final EditorState editorState;

  @override
  State<DoodleBlockWidget> createState() => _DoodleBlockWidgetState();
}

class _DoodleBlockWidgetState extends State<DoodleBlockWidget>
    with SelectableMixin, BlockComponentConfigurable {
  // BlockComponentConfigurable / SelectableMixin are the mixins AppFlowy Editor
  // expects so the block participates correctly in selection/cursor navigation
  // alongside normal text blocks — see §6.4 of the detailed plan.

  late String attachmentId = widget.node.attributes['attachmentId'] as String;
  String? thumbnailPath = widget.node.attributes['thumbnailPath'] as String?;
  double aspectRatio = (widget.node.attributes['aspectRatio'] as num?)?.toDouble() ?? 1.4;

  Future<void> _openFullEditor() async {
    final repo = ref.read(attachmentRepositoryProvider); // via ProviderScope bridge, see note below
    final strokeData = await repo.loadStrokes(attachmentId);

    final result = await Navigator.of(context).push<DoodleEditResult>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => DoodleCanvasScreen(
          initialStrokes: strokeData?.strokes ?? [],
          seedColor: NoteThemeScope.of(context).colorScheme.primary, // ties into per-note theming
        ),
      ),
    );

    if (result == null) return; // user cancelled, nothing changes

    // 1. Persist updated vector strokes + regenerate thumbnail PNG
    final newThumbPath = await repo.saveStrokesAndThumbnail(
      attachmentId: attachmentId,
      strokes: result.strokes,
    );

    // 2. Write the new thumbnail path back into the node's attributes via a
    //    Transaction — this is what makes AppFlowy Editor's undo/redo and
    //    autosave-on-transaction-stream pick the change up automatically.
    final transaction = widget.editorState.transaction
      ..updateNode(widget.node, {
        ...widget.node.attributes,
        'thumbnailPath': newThumbPath,
      });
    widget.editorState.apply(transaction);

    setState(() => thumbnailPath = newThumbPath);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _openFullEditor,
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.outlineVariant,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: thumbnailPath == null
              ? _EmptyDoodlePlaceholder(onTap: _openFullEditor)
              : Image.file(File(thumbnailPath!), fit: BoxFit.cover),
        ),
      ),
    );
  }
}
```

A few things worth calling out:
- **`Navigator.push` with `fullscreenDialog: true`**, not a bottom sheet — a doodle deserves the whole screen and the "swipe/back to save" mental model people already know from Markup on iOS or Samsung Notes' sketch mode.
- **The full canvas screen never touches the document tree directly** — it only returns stroke data. All node-tree mutation happens back in `DoodleBlockWidget` via a proper `Transaction`. This keeps your custom node type playing by the same undo/redo rules as every built-in block.
- **`NoteThemeScope.of(context)`** — an `InheritedWidget` you define once (holding the current note's derived `ColorScheme`) and wrap around the whole editor screen, so any block — built-in or custom — can read the note's seed color without prop-drilling it through every builder.

### 1.3 The Full-Screen Canvas Screen

```dart
class DoodleCanvasScreen extends StatefulWidget {
  const DoodleCanvasScreen({
    super.key,
    required this.initialStrokes,
    required this.seedColor,
  });

  final List<Stroke> initialStrokes;
  final Color seedColor;

  @override
  State<DoodleCanvasScreen> createState() => _DoodleCanvasScreenState();
}

class _DoodleCanvasScreenState extends State<DoodleCanvasScreen> {
  late final controller = DoodleController(initialStrokes: widget.initialStrokes);

  void _save() {
    Navigator.of(context).pop(
      DoodleEndResult(strokes: controller.strokes),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ColorScheme.fromSeed(seedColor: widget.seedColor);
    return Theme(
      data: Theme.of(context).copyWith(colorScheme: scheme),
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(), // discard
          ),
          actions: [
            IconButton(icon: const Icon(Icons.undo), onPressed: controller.undo),
            IconButton(icon: const Icon(Icons.redo), onPressed: controller.redo),
            TextButton(onPressed: _save, child: const Text('Done')),
          ],
        ),
        body: DoodleCanvas(controller: controller), // from detailed plan §7
        bottomNavigationBar: DoodleToolbar(controller: controller), // pen/eraser/color/width
      ),
    );
  }
}
```

Discard-vs-save is explicit (`close` = discard, `Done` = save) rather than autosaving every stroke into the node tree — a doodle in progress shouldn't be triggering your app-wide note autosave/sync-eligibility on every pen stroke.

---

## 2. Slash-Command Menu Customization

This is the single highest-leverage UI surface for "enjoyable note-taking" — it's the moment of *choosing what kind of thing to create*. AppFlowy Editor exposes this via `SelectionMenu` / `characterShortcutEvents` (triggered by typing `/`).

### 2.1 Replacing the Default Menu Items

```dart
final slashMenuItems = <SelectionMenuItem>[
  SelectionMenuItem(
    name: 'Checklist',
    icon: (_, isSelected, style) => _MenuIcon(
      icon: Icons.checklist_rounded,
      selected: isSelected,
    ),
    keywords: ['todo', 'checklist', 'task', 'check'],
    handler: (editorState, menuService, context) {
      insertNodeAfterSelection(editorState, todoListNode(checked: false));
    },
  ),
  SelectionMenuItem(
    name: 'Doodle',
    icon: (_, isSelected, style) => _MenuIcon(
      icon: Icons.draw_rounded,
      selected: isSelected,
    ),
    keywords: ['doodle', 'draw', 'sketch', 'canvas'],
    handler: (editorState, menuService, context) async {
      final attachmentId = const Uuid().v4();
      await ref.read(attachmentRepositoryProvider).createEmptyDoodle(attachmentId);
      insertNodeAfterSelection(editorState, Node(
        type: 'doodle',
        attributes: {'attachmentId': attachmentId, 'aspectRatio': 1.4},
      ));
    },
  ),
  SelectionMenuItem(
    name: 'Image',
    icon: (_, isSelected, style) => _MenuIcon(icon: Icons.image_rounded, selected: isSelected),
    keywords: ['image', 'photo', 'picture'],
    handler: (editorState, menuService, context) async {
      final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (picked == null) return;
      final attachmentId = await ref.read(attachmentRepositoryProvider)
          .importImage(File(picked.path));
      insertNodeAfterSelection(editorState, Node(
        type: 'image',
        attributes: {'attachmentId': attachmentId},
      ));
    },
  ),
  // ...plus paragraph, heading, bulleted/numbered list, quote, divider —
  // reuse standardSelectionMenuItems for those rather than rebuilding them.
  ...standardSelectionMenuItems,
];
```

Wire it up on the editor:
```dart
AppFlowyEditor(
  editorState: editorState,
  characterShortcutEvents: [
    ...standardCharacterShortcutEvents.where((e) => e != slashCommand), // remove default
    customSlashCommand(slashMenuItems),
  ],
  ...
);
```

### 2.2 The Visual Polish That Actually Makes It "Enjoyable"

- **Icon tiles, not a plain text list.** Each `_MenuIcon` is a small rounded-square tile tinted with the note's `ColorScheme.primaryContainer` when selected — consistent with the per-note theming principle running through the whole app.
- **Reorder by expected frequency, not alphabetically** — Checklist and Doodle should sit near the top given they're your differentiators, not buried under "Heading 3."
- **Live filtering as you type after `/`** (e.g. `/check` narrows to Checklist) — this is built into `SelectionMenuItem.keywords`, just make sure you populate good keyword lists like above.
- **A one-time "did you know" tooltip on first use** pointing at the `/` trigger during onboarding (§5.1 in the master plan) — most users never discover slash menus in text editors unless nudged once.

### 2.3 Mobile: the slash menu becomes a toolbar (design decision)

The desktop `/` menu (a `SelectionMenu` overlay) does not survive touch: the
overlay closes the soft keyboard and its navigation relies on hardware-keyboard
events. Two coordinated decisions handle mobile:

1. **`tool/patch_appflowy_editor.dart` patches `slash_command.dart`** so the
   stock `_showSlashMenu`, on mobile, inserts the `/` character as a visual
   breadcrumb and consumes the event **without** showing the `SelectionMenu`.
   (Upstream 6.2.0 returns `false` on mobile, so `/` does nothing; simply
   removing that guard is not enough for the reasons above.)
2. **`MobileToolbarV2` replaces the overlay on mobile** — `note_editor_screen.dart`
   wraps the editor with a toolbar themed to the note's scheme, exposing the same
   block types as the desktop slash menu (H1/H2/H3, bulleted/numbered lists,
   checkbox, quote), a Doodle action item that opens the doodle canvas via
   `_insertDoodle()`, and `textDecorationMobileToolbarItemV2`.

Desktop keeps the real slash menu: the global keyboard shortcuts (AGENTS.md →
"Mobile toolbar & global shortcuts") are suppressed while the editor has focus,
so `/` still opens the menu while editing.

---

## 3. Full Screen & Routing Map (go_router)

### 3.1 Route Table

| Route | Path | Notes |
|---|---|---|
| Splash/Bootstrap | `/` | Opens encrypted DB, checks biometric lock state |
| Lock Screen | — | **No `/lock` route.** Replaced by an always-mounted `FrostedShield` overlay stacked in `MaterialApp.router.builder` (see ADR 0006). Blocks every route below until biometric unlock; keeps app state alive. |
| Onboarding | `/onboarding` | First-launch only, 3 sub-steps as a `PageView`, not separate routes |
| Home | `/home` | Notes grid — the app's default landing route post-lock |
| Search | `/home/search` | Presented as a full route (not just a dialog) so back-button/deep-link behaves correctly |
| Notebooks list | `/notebooks` | |
| Notebook detail | `/notebooks/:notebookId` | Filtered notes grid, reuses Home's grid widget |
| Tags list | `/tags` | |
| Tag detail | `/tags/:tagId` | Filtered notes grid |
| Note editor (new) | `/note/new?notebookId=&type=` | `type` param pre-selects text/checklist/doodle mode |
| Note editor (existing) | `/note/:noteId` | |
| Doodle full editor | `/note/:noteId/doodle/:attachmentId` | Pushed as `fullscreenDialog`, per §1.3 above — modeled as a route (not just a raw `Navigator.push`) so it survives process death / deep-link resume cleanly |
| Trash | `/trash` | Soft-deleted notes, restore/purge actions |
| Locked notes | `/locked` | Separate biometric re-prompt before revealing contents |
| Sync — Send | `/sync/send` | |
| Sync — Receive | `/sync/receive` | |
| Sync — Pairing confirm | `/sync/pairing` | Shown as a route so system back button cancels pairing cleanly instead of being trapped in a dialog |
| Sync — Transfer progress | `/sync/transfer/:sessionId` | |
| Sync — History | `/sync/history` | |
| Settings — root | `/settings` | |
| Settings — Appearance | `/settings/appearance` | |
| Settings — Security | `/settings/security` | |
| Settings — Storage & Backup | `/settings/storage` | |
| Settings — Sync devices | `/settings/sync-devices` | Paired-device history, distinct from the live `/sync/*` flow |
| Settings — Privacy | `/settings/privacy` | Privacy policy |
| Settings — App Logs | `/settings/logs` | Developer log viewer (`talker_flutter`) |
| Settings — About/License | `/settings/about` | |

That's **~28 routes** across 8 feature areas (Home, Search, Notebooks, Tags, Editor, Trash/Locked, Sync, Settings) — a healthy scope for a v1 that doesn't feel thin, without ballooning into over-engineering.

### 3.2 go_router Skeleton

> **Update (2026-08):** the biometric lock is no longer a redirect to a `/lock`
> route. `NookApp` is a `ConsumerStatefulWidget` with a `WidgetsBindingObserver`;
> `MaterialApp.router.builder` stacks `FrostedShield` above every route, so no
> router changes are needed to gate content (see ADR 0006). The skeleton below
> reflects the current implementation — there is no `/lock` route and no
> `redirect` callback.

```dart
final router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(path: '/', builder: (_, __) => const BootstrapScreen()),
    GoRoute(path: '/onboarding', builder: (_, __) => const OnboardingScreen()),
    ShellRoute(
      builder: (context, state, child) => AppShell(child: child), // bottom nav / rail
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(path: '/notebooks', builder: (_, __) => const NotebooksScreen()),
        GoRoute(
          path: '/notebooks/:notebookId',
          builder: (_, state) => NotebookDetailScreen(
            notebookId: state.pathParameters['notebookId']!,
          ),
        ),
        GoRoute(path: '/tags', builder: (_, __) => const TagsScreen()),
        GoRoute(path: '/trash', builder: (_, __) => const TrashScreen()),
        GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
        // ...settings sub-routes nested here similarly
      ],
    ),
    GoRoute(
      path: '/note/:noteId',
      builder: (_, state) => NoteEditorScreen(noteId: state.pathParameters['noteId']!),
    ),
    GoRoute(
      path: '/note/new',
      builder: (_, state) => NoteEditorScreen.newNote(
        notebookId: state.uri.queryParameters['notebookId'],
        type: state.uri.queryParameters['type'],
      ),
    ),
    GoRoute(
      path: '/sync/send',
      pageBuilder: (_, __) => const MaterialPage(
        fullscreenDialog: true,
        child: SyncSendScreen(),
      ),
    ),
    // ...remaining /sync/* and /note/:noteId/doodle/:attachmentId similarly
  ],
);
```

`ShellRoute` gives you the persistent bottom nav/rail around Home/Notebooks/Tags/Trash/Settings, while the editor and sync flows are pushed as their own full routes/dialogs — matches how Keep/Samsung Notes feel (nav chrome persists for browsing, disappears for focused editing).

---

## 4. High-Value, Low-Effort FOSS Libraries Worth Adding

These aren't in the original stack but each is a small integration cost for a disproportionate boost to how "premium" the app feels — genuinely worth the extra day or two each.

| Library | What it buys you | Effort |
|---|---|---|
| **`flutter_animate`** (MIT) | Declarative, chainable animations (`.fadeIn().scale()`) — use it for note-card entrance, checklist strikethrough, FAB speed-dial. Turns "functional" into "delightful" with very little code. | Very low |
| **`home_widget`** (MIT) | Real Android/iOS home-screen widgets — e.g. a "quick capture" widget or a pinned-notes widget. Genuinely differentiates you from most FOSS note apps that skip this. Can render existing Flutter widgets to an image for the widget surface, so you reuse your `NoteCard` design instead of hand-building native widget UI. | Medium |
| **`flutter_local_notifications`** (BSD) | Local-only reminders on notes/checklist items — no server, fits your zero-cloud promise perfectly, and "remind me" is a top-requested note-app feature. | Low–Medium |
| **`google_mlkit_text_recognition`** (Apache-2.0, on-device ML Kit) | On-device OCR — "scan a photo of handwritten/printed text into a note." Fully offline, no cloud call, matches your privacy story exactly, and it's the kind of feature that makes people say "wow" in reviews. | Medium |
| **`speech_to_text`** (BSD) | On-device (where supported) voice-to-text note capture — fast note creation while walking/driving. Pairs naturally with your FAB speed-dial. | Low–Medium |
| **`share_plus`** (BSD) | Standard OS share-sheet integration both ways: receive shared text/images *into* a new note from other apps, and share your exported note-images *out*. Cheap, expected, and currently missing from your plan. | Very low |
| **`receive_sharing_intent`** (Apache-2.0) | The "receive" half of the above — lets your app appear in the Android share sheet as a target ("Save to [App Name]") from browser/other apps. Big everyday-usefulness win for very little code. | Low |
| **`flutter_staggered_animations`** (MIT) | Staggered entrance animations specifically for grid/list items — makes the Home grid's first paint feel considered rather than items just "popping in." | Very low |
| **`shimmer`** (MIT) | Skeleton-loading placeholders for the (rare, since local) moments the grid is populating — nicer than a blank screen or spinner on cold start with a large note collection. | Very low |
| **`flex_color_picker`** (BSD) | A genuinely polished, Material-3-aware color picker widget — better starting point than building your own swatch/wheel picker for the per-note theme selector. | Very low |
| **`printing`** (Apache-2.0, same author as the `pdf` package) | "Export note as PDF" alongside your planned image export — near-zero extra cost since you'd already have the `pdf` package skill/knowledge from other document work, and it's a commonly requested export format. | Low |

**Recommended picks for v1** if you want the biggest delight-per-effort ratio without derailing your roadmap: `flutter_animate`, `share_plus` + `receive_sharing_intent`, `flutter_staggered_animations`, and `flex_color_picker` — all very low effort, all directly reinforce "enjoyable" and "artistic." Save `home_widget`, OCR, and voice-to-text for a fast-follow v1.1 — each is genuinely great but meaningfully bigger scope, and you don't want them blocking your first Play Store release.

---

## 5. How This All Fits Together

- The **doodle block** and **slash menu** work in §1–2 both plug directly into the AppFlowy Editor integration from the detailed plan's §6 — no architectural surprises, just filling in the two custom pieces that were flagged as "you'll build these."
- The **routing map** in §3 is the concrete version of the screen list from the master plan's §5 — now with actual paths, so you can start wiring `go_router` on day one of Phase 0 instead of guessing navigation structure mid-build.
- The **bonus libraries** in §4 are intentionally kept separate from the core stack in the detailed plan — treat them as a prioritized backlog you pull from once Phases 0–2 are solid, not as day-one dependencies competing for your attention.
