# Using Nook Folder Mirror with Syncthing

Nook's **Folder Mirror** (`FolderMirrorService`) writes all live, **unlocked** notes as standard `.md` files into a user-selected directory and automatically prunes files when notes are deleted or locked.

## Setup with Syncthing

1. **Choose a mirror folder** on your device (e.g. `~/Documents/NookMirror` on desktop or a Storage Access Framework directory on Android).
2. **Run Folder Mirror** in Nook to populate `.md` files for all unlocked notes.
3. **Add that folder in Syncthing** on your devices (Send & Receive or Send Only).
4. **Locked notes stay private**: Nook never writes `locked == true` notes to the mirror folder.
