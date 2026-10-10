#define AppName "Kvaltik Notepad"
#ifndef AppVersion
  #define AppVersion "1.1.0"
#endif
#ifndef AppSource
  #error AppSource is required (pass /DAppSource=<release directory>)
#endif

[Setup]
; Preserve the same application name/installer identity as the v1.0 workflow.
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\Kvaltik Notepad
DefaultGroupName=Kvaltik Notepad
OutputDir=dist
OutputBaseFilename=KvaltikNotepad-Setup
Compression=lzma
SolidCompression=yes

[Files]
Source: "{#AppSource}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion

[Tasks]
Name: "desktopicon"; Description: "Vytvorit zastupce na plose"; Flags: unchecked

[Icons]
Name: "{autoprograms}\Kvaltik Notepad"; Filename: "{app}\kvaltik_notepad.exe"
Name: "{autodesktop}\Kvaltik Notepad"; Filename: "{app}\kvaltik_notepad.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\kvaltik_notepad.exe"; Description: "Spustit Kvaltik Notepad"; Flags: nowait postinstall skipifsilent
