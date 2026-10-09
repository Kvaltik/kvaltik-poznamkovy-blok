#define AppName "Kvaltik Notepad"
#define AppVersion "1.0.0"
#ifndef AppSource
  #error AppSource is required
#endif
[Setup]
AppId={{B734F26A-83B8-43F2-9DA4-CDA9774E9D12}
AppName={#AppName}
AppVersion={#AppVersion}
DefaultDirName={autopf}\Kvaltik Notepad
DefaultGroupName=Kvaltik Notepad
OutputDir=dist
OutputBaseFilename=KvaltikNotepad-Setup
Compression=lzma
SolidCompression=yes
PrivilegesRequired=lowest
[Files]
Source: "{#AppSource}\*"; DestDir: "{app}"; Flags: recursesubdirs createallsubdirs ignoreversion
[Icons]
Name: "{autoprograms}\Kvaltik Notepad"; Filename: "{app}\kvaltik_notepad.exe"
Name: "{autodesktop}\Kvaltik Notepad"; Filename: "{app}\kvaltik_notepad.exe"; Tasks: desktopicon
[Tasks]
Name: "desktopicon"; Description: "Create desktop shortcut"; Flags: unchecked
[Run]
Filename: "{app}\kvaltik_notepad.exe"; Description: "Launch Kvaltik Notepad"; Flags: nowait postinstall skipifsilent
