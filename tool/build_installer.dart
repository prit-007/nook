import 'dart:io';

/// Builds a Windows installer for nook using the Inno Setup compiler.
///
/// Pipeline (run on Windows):
///   flutter build windows --release
///   dart run tool/build_installer.dart
///
/// Flags:
///   --dry-run  Generate the .iss without requiring a Windows release build or
///              the Inno Setup compiler. Use this to validate the script on any
///              host.
///   --iscc     Absolute path to ISCC.exe when it is not resolvable from PATH.

const _publisher = "Developer's Paradise";
const _homeUrl = 'https://github.com/prit-007/nook';
// Stable AppId so Windows Update / upgrades install over a previous version.
const _appId = '{{26eb0e5d-00f0-40a0-ae68-21e0a62e5509}}';

const _releaseDir = 'build/windows/x64/runner/Release';
const _exeName = 'nook.exe';
const _iconPath = 'windows/runner/resources/app_icon.ico';
const _licensePath = 'LICENSE';
const _outputDir = 'build/installers';

void main(List<String> args) {
  final dryRun = args.contains('--dry-run');
  final isccOverride = _flagValue(args, '--iscc');

  final version = _appVersion();
  final exe = File('$_releaseDir/$_exeName');
  if (!dryRun && !exe.existsSync()) {
    stderr.writeln('Error: $_releaseDir/$_exeName not found.');
    stderr.writeln('Run `flutter build windows --release` first.');
    exit(1);
  }

  final outputDir = Directory(_outputDir)..createSync(recursive: true);
  final issFile = File('${outputDir.path}/nook_setup_$version.iss');
  issFile.writeAsStringSync(_buildIss(version, exe));
  stdout.writeln('Wrote ${issFile.path}');

  final iscc = isccOverride ?? _findIscc();
  if (iscc == null) {
    stdout.writeln(
      'iscc not found on PATH. Install Inno Setup from '
      'https://jrsoftware.org/isdl.php and re-run, or pass --iscc <path>.',
    );
    // Dry-run only validates the .iss generation (useful on non-Windows
    // hosts); a real build that cannot produce the .exe must fail loudly so
    // CI never ships a "successful" run without an installer.
    if (dryRun) return;
    exit(1);
  }

  stdout.writeln('Compiling installer with $iscc ...');
  final result = Process.runSync(iscc, [issFile.path]);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) exit(result.exitCode);
  stdout.writeln('Installer: ${outputDir.path}/nook_setup_$version.exe');
}

String _appVersion() {
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final match = RegExp(r'^version:\s*(\d+\.\d+\.\d+)', multiLine: true)
      .firstMatch(pubspec);
  if (match == null) {
    stderr.writeln('Could not parse version from pubspec.yaml.');
    exit(1);
  }
  return match.group(1)!;
}

String _buildIss(String version, File exe) {
  final releaseDir = exe.parent.absolute.path;
  final exePath = exe.absolute.path;
  final icon = File(_iconPath).absolute.path;
  final license = File(_licensePath).absolute.path;
  final outputDir = Directory(_outputDir).absolute.path;

  return '''
[Setup]
AppId=$_appId
AppName=nook
AppVersion=$version
AppVerName=nook $version
AppPublisher=$_publisher
AppPublisherURL=$_homeUrl
AppSupportURL=$_homeUrl
AppUpdatesURL=$_homeUrl
DefaultDirName={localappdata}\\nook
DefaultGroupName=nook
DisableProgramGroupPage=yes
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
WizardStyle=modern
OutputDir=$outputDir
OutputBaseFilename=nook_setup_$version
SetupIconFile=$icon
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
LicenseFile=$license
UninstallDisplayIcon={app}\\$_exeName
CloseApplications=yes

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
Source: "$exePath"; DestDir: "{app}"; Flags: ignoreversion
Source: "$releaseDir\\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\\nook"; Filename: "{app}\\$_exeName"
Name: "{autodesktop}\\nook"; Filename: "{app}\\$_exeName"; Tasks: desktopicon

[Run]
Filename: "{app}\\$_exeName"; Description: "{cm:LaunchProgram,nook}"; Flags: nowait postinstall skipifsilent
''';
}

String? _findIscc() {
  final pathEnv = Platform.environment['PATH'] ?? '';
  final separator = Platform.isWindows ? ';' : ':';
  for (final dir in pathEnv.split(separator)) {
    if (dir.isEmpty) continue;
    final candidate = File('$dir${Platform.pathSeparator}iscc.exe');
    if (candidate.existsSync()) return candidate.path;
  }
  // Common Inno Setup install location on Windows.
  const fallback = r'C:\Program Files (x86)\Inno Setup 6\ISCC.exe';
  return File(fallback).existsSync() ? fallback : null;
}

String? _flagValue(List<String> args, String flag) {
  final index = args.indexOf(flag);
  if (index == -1 || index + 1 >= args.length) return null;
  return args[index + 1];
}
