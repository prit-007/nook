# Google Stitch Prompts — Screen Visualization
### Paste each block below into Stitch as its own generation. Order roughly matches user flow.

General tip: Stitch tends to do best with one screen per prompt, a clear style anchor at the start, and explicit component lists rather than vague adjectives. Each prompt below follows that shape. Generate them in order — Home first, since its visual language (card shapes, tonal palette, type scale) is what you'll want every other screen to echo, and you can reference it in later prompts ("match the card style and color system from the home screen").

---

## 1. Onboarding — Welcome Screen

```
Design a mobile app onboarding welcome screen for a private, offline-first note-taking app called "Own." Material Design 3 style, dynamic color theming, warm violet-to-lavender tonal palette on a soft off-white background. Large friendly illustration in the upper two-thirds showing a notebook with a small padlock icon and a subtle wifi/sync glyph nearby, flat modern illustration style with soft rounded shapes, no photorealism. Below the illustration: a bold headline "Your notes. Your device. Yours." in a rounded sans-serif display font, and a shorter subtext line "No account. No cloud. No one else reads your notes." A large pill-shaped primary button at the bottom labeled "Get Started," filled with the primary tonal color, plus a smaller text-only "Skip" link above it. Three small dot page indicators just above the button row. Generous padding, edge-to-edge design, status bar area transparent.
```

## 2. Onboarding — Pick Your Vibe (theming intro)

```
Design a mobile app onboarding screen titled "Pick your vibe" for a notes app using Material You 3 dynamic color. Show a headline and one line of subtext explaining notes can each have their own color theme. Below that, a horizontal scrollable row of 8 circular color swatches (violet, teal, coral, sage green, amber, rose, sky blue, slate) each with a soft glow/selection ring on the currently chosen one. Beneath the swatches, a toggle row labeled "Match my wallpaper" with a Material 3 switch, subtitled "Use dynamic color from your device (Android 12+)." Below that, a live preview card showing a small mock note card that updates its tonal color to match the selection — rounded corners, soft shadow, a title line and two lines of placeholder text inside. Primary button "Continue" pill-shaped at the bottom. Clean, airy spacing, rounded 24px corners throughout.
```

## 3. Home — Notes Grid (core screen, the app's signature look)

```
Design a mobile app home screen for a notes app, Material Design 3, masonry/staggered grid layout of note cards, 2 columns. Each card has rounded 20px corners, soft tonal background color unique per card (violet, teal, coral, sage, amber — Material You tonal palette derived from a seed color), subtle drop shadow. Card contents vary: one shows a title and 3 lines of text, one shows a checklist preview with 2 checked and 2 unchecked items with small checkbox icons, one shows a doodle/sketch thumbnail filling most of the card, one shows a photo thumbnail with a short caption below, one has a small pin icon in the top-right corner indicating it's pinned, one has a lock icon overlay with blurred/obscured content indicating it's a locked note. Top of screen: a rounded search bar with a magnifying glass icon and placeholder text "Search notes," a small circular settings icon button to its right. Below the search bar, a horizontal row of filter chips: "All," "Pinned," "Checklists," "Doodles." Bottom-right: a large circular floating action button in the primary color with a plus icon. Bottom navigation bar with 4 icons: Home (filled/active), Notebooks, Tags, Trash. Soft off-white background behind the grid so card colors pop. Modern, warm, playful but clean aesthetic — like a cross between Google Keep and Samsung Notes.
```

## 4. Home — Speed Dial FAB Expanded

```
Design the same notes app home screen as before, but with the floating action button expanded into a speed-dial menu. Show 4 small circular mini-buttons stacked vertically above the main FAB, each with an icon and a text label to its left in a small rounded pill background: "Doodle" (pencil/draw icon), "Checklist" (checklist icon), "Scan image" (camera icon), "Text note" (document icon), ordered top to bottom with Doodle and Checklist nearest the main FAB. A soft dark scrim overlay behind the menu dimming the note grid beneath it. Material 3 style, rounded shapes, primary color tonal accents on each mini-button, smooth elevated shadows suggesting they're animating outward from the FAB.
```

## 5. Note Editor — Text/Mixed Note (immersive writing mode)

```
Design a mobile note editor screen, Material Design 3, immersive minimal style. Background is a soft tonal color derived from a warm teal seed color, matching the note's own theme. Top app bar is nearly transparent/blended into the background, containing only a back arrow, a small circular color-swatch button (showing the current teal theme), and a three-dot overflow menu icon — no visible toolbar border. Below the app bar, a large borderless title field showing placeholder-style bold text "Weekend trip packing list" in a large rounded serif-ish display font. Below the title, the note body shows a mix of block content: two lines of normal paragraph text, then a checklist block with 3 items (checkboxes, one checked with strikethrough text), then a rounded doodle thumbnail card with a small pencil-sketch icon in the corner suggesting a drawing block, then a small "+" block insertion hint below everything showing where new content would be added. A slim floating toolbar hovers just above the keyboard area at the bottom with icons for bold, italic, checklist, image, and a "+" for more block types — this toolbar has a soft rounded pill shape, elevated shadow, blending with the teal theme. Clean generous whitespace, cursor visible in the text.
```

## 6. Note Editor — Slash Command Menu Open

```
Design a mobile note editor screen with a slash-command popup menu open, Material Design 3 style. Background is the note editor from before with warm teal tonal theme, slightly dimmed by a soft scrim. In the middle-lower part of the screen, a rounded elevated card menu is open showing a search field at the top with a "/" character and cursor, and below it a vertical list of menu items each with a small rounded-square icon tile on the left and a label with a short description on the right: "Checklist — Track a to-do list," "Doodle — Sketch or draw," "Image — Add a photo," "Heading — Big section title," "Bulleted list," "Divider." The Checklist and Doodle items are visually near the top and their icon tiles are filled with the teal primary color, other items have neutral gray icon tiles. Rounded 16px corners on the menu card, soft shadow, comfortable padding between rows.
```

## 7. Doodle Canvas — Full Screen Drawing Mode

```
Design a full-screen mobile drawing/doodle canvas screen, Material Design 3 style. Top app bar is minimal: a close "X" icon on the left, undo and redo icons in the middle-right area, and a filled pill-shaped "Done" button on the far right in the primary color. Canvas area fills almost the entire screen with a soft dotted-grid background pattern (light dots on off-white), and shows a simple in-progress hand-drawn sketch with smooth variable-width ink strokes in a warm coral color — like a small doodle of a plant in a pot. At the bottom, a floating rounded toolbar bar containing: a color swatch row (5 small circles: black, coral, teal, amber, violet, with the coral one selected/highlighted with a ring), a pen icon button, a highlighter icon button, an eraser icon button, and a small stroke-width slider or dot-size selector. The toolbar has soft elevation, rounded pill shape, comfortable spacing. Overall aesthetic: playful, tactile, artistic, like Samsung Notes' sketch mode or GoodNotes.
```

## 8. Nearby Sync — Discovery/Send Screen

```
Design a mobile "nearby sync" screen for a notes app, Material Design 3, titled "Send Notes." Top segmented control/toggle switch between "Send" (selected) and "Receive." Below it, a section titled "Select notes" showing a compact horizontal scroll list of small note thumbnail cards with checkboxes in their corners, 3 selected shown with a colored selection ring. Below that, a section titled "Nearby devices" with a centered circular radar animation graphic — concentric soft-colored rings pulsing outward from a small phone icon in the center, suggesting active scanning. Below the radar, 2 discovered device cards in a list: each showing a device icon, a device name like "Priya's Pixel 8," a small signal-strength icon, and a rounded "Send" button on the right. Warm, trustworthy, tech-but-friendly aesthetic, soft primary-color accents, generous rounded corners, plenty of whitespace so it doesn't feel technical or intimidating.
```

## 9. Nearby Sync — Pairing Confirmation

```
Design a mobile pairing confirmation modal/screen for a device-to-device sync feature, Material Design 3 style, centered card layout on a dimmed background. Large centered numeric code displayed prominently, like "482 916," in a bold monospace-style font inside a rounded pill container. Above the code, text reads "Confirm this code matches on both devices." Below the code, two device icons face each other with a small animated-looking connection line/dots between them, one labeled "This device" and one labeled "Priya's Pixel 8." Two buttons at the bottom: a filled primary "Confirm & Connect" pill button, and a text-only "Cancel" button beneath it. Soft shadow on the card, rounded 28px corners, reassuring and secure visual tone — like a Bluetooth pairing screen but warmer and friendlier.
```

## 10. Lock Screen — Biometric Gate

```
Design a mobile app lock screen for a private notes app, Material Design 3 style. Soft gradient background blending the app's primary tonal color from top (deeper violet) to bottom (near-white), with a gentle blurred/frosted illustration of a notebook faintly visible behind a blur layer, suggesting content is hidden. Centered vertically: a large circular fingerprint icon inside a soft elevated white circle with tonal shadow, animated-looking pulse rings around it suggesting it's waiting for input. Below the icon, text reads "Unlock to see your notes" and a smaller line "Face ID or fingerprint required." Below that, a small text button "Use PIN instead." App name/logo small and centered at the very top. Calm, secure, minimal — no clutter, focus entirely on the unlock icon.
```

## 11. Settings — Root Screen

```
Design a mobile app settings screen, Material Design 3, grouped list style with rounded section cards on a soft off-white background. Top app bar with back arrow and title "Settings." First section titled "Appearance" containing rows: "Dynamic color" with a toggle switch (on), "Theme" with value "System" and a chevron, "Font" with value "Default" and a chevron — each row has a small rounded icon on the left. Second section titled "Security" containing: "Biometric lock" with a toggle (on), "Auto-lock timer" with value "1 minute," "Screenshot blocking" with a toggle (off). Third section titled "Storage & Sync" containing: "Storage used" showing "48 MB · 214 notes," "Export all notes," "Paired devices" with value "2 devices." Fourth section titled "About" containing: "Privacy policy," "Open source licenses," "Version 1.0.0." Each section has a soft card background with 20px rounded corners, comfortable row height, small leading icons in tonal primary color, trailing chevrons on navigable rows and Material 3 switches on toggle rows. Clean, organized, trustworthy aesthetic.
```

## 12. Trash / Locked Notes Screen

```
Design a mobile "Trash" screen for a notes app, Material Design 3 style. Top app bar with back arrow, title "Trash," and a small text button "Empty" on the right. Below the app bar, a slim informational banner in a soft tonal container reading "Notes are permanently deleted after 30 days" with a small info icon. Below that, a grid of note cards similar to the home screen but desaturated/grayscale-tinted to indicate they're deleted, each card showing a small countdown badge in the corner like "12 days left" and a small restore icon button overlaid in the top-right corner of each card. Empty state alternative shown faintly in background style notes: a simple centered illustration of an empty trash bin with the text "Nothing in trash" if no items — but for this design show 4 populated cards. Muted, low-emphasis visual tone compared to the vibrant home screen, since this is a background-utility screen.
```

---

## How to Use These Effectively

- **Generate Home (Screen 3) first.** Its card shapes, corner radius, and tonal color system become your visual anchor — when generating later screens, you can literally paste "match the card style, rounded corners, and color system from the home screen" at the front of subsequent prompts if Stitch supports referencing prior generations, or just re-paste the same style descriptors (rounded 20px corners, Material You 3, tonal palette) to keep everything consistent.
- **Iterate on one screen at a time**, don't dump all 12 into one session expecting perfect consistency — Stitch, like most AI UI tools, drifts stylistically across separate generations unless you keep re-anchoring the same descriptive language (Material Design 3, tonal palette, rounded corners, specific seed colors).
- **Once you have visuals you like**, screenshot/export them into a shared moodboard (Figma, or even just a folder) — that becomes your actual design reference doc for implementation, more useful than the text prompts alone once you start building.
- **Don't treat Stitch output as final UI** — it's a fast way to pressure-test whether the *concepts* in the master plan (per-note theming, block-based mixed content, radar-style sync discovery) actually look coherent and appealing before you invest real engineering time. Expect to refine spacing/hierarchy by hand once you're building in Flutter.
