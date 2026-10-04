/// User-facing privacy explainer copy.
///
/// Kept as constants so tests can assert claims stay honest (no fear-mongering
/// marketing language, no false "military-grade" / "cloud backup" claims).
library;

/// Section: where data lives on device.
const String kPrivacyWhereDataLivesTitle = 'Where your data lives';

const String kPrivacyWhereDataLivesBody =
    'Your notes, checklists, doodles, and attachments are stored in an '
    'encrypted SQLite database on this device only. The database key is held '
    'in the platform keystore (Secure Enclave / Keychain / Keystore) and is '
    'never hardcoded or sent anywhere. There is no Nook server that holds a '
    'copy of your notes.';

/// Section: what peer-to-peer sync sends.
const String kPrivacyWhatSyncSendsTitle = 'What sync sends';

const String kPrivacyWhatSyncSendsBody =
    'Sync is optional and runs only when you start it. Notes travel directly '
    'between your own devices over your local network using a Noise-encrypted '
    'libp2p link. A short pairing code must be confirmed on both devices '
    'before anything is transferred. Frames are checksummed before '
    'deserialization. Nothing is routed through a relay or cloud account.';

/// Section: what Nook never collects.
const String kPrivacyNeverCollectsTitle = 'What we never collect';

const String kPrivacyNeverCollectsBody =
    'Nook has no account system, no analytics, no crash reporters, and no '
    'advertising identifiers. We do not receive your notes, titles, tags, or '
    'usage patterns. In-app logs stay on your device and can be cleared from '
    'Settings → Developer → App Logs.';

/// Section: how a user can verify the claims.
const String kPrivacyHowToVerifyTitle = 'How to verify';

const String kPrivacyHowToVerifyBody =
    'Export a .nook vault from Settings → Storage and inspect the files on '
    'disk. Build the app from source on GitHub (GPL-3.0) and read the sync '
    'and database code yourself. On F-Droid you can rebuild from the published '
    'metadata. If you leave the app, your export remains readable without a '
    'Nook account. Note: exported vaults are not password-wrapped; the vault '
    'password gates the in-app session only (C1).';

/// Forbidden phrases — unit tests assert copy never contains these.
const List<String> kPrivacyForbiddenPhrases = [
  'military-grade',
  'bank-level',
  'cloud backup',
  'we never lose your data',
  '100% unhackable',
  'guaranteed private',
];
