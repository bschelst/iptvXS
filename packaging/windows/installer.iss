[Setup]
AppName=iptvXS
AppVersion=0.3.10
AppPublisher=Bart Schelstraete
AppPublisherURL=https://github.com/bschelst/iptvXS
DefaultDirName={autopf}\iptvXS
DefaultGroupName=iptvXS
OutputDir=..\..\
OutputBaseFilename=iptvXS-setup-x64
Compression=lzma2
SolidCompression=yes
ArchitecturesInstallIn64BitMode=x64compatible
SetupIconFile=..\..\app\iptvxs.ico
UninstallDisplayIcon={app}\iptvXS.exe
WizardStyle=modern
PrivilegesRequired=lowest

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "Create a desktop shortcut"; GroupDescription: "Additional icons:"

[Files]
Source: "..\..\package\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs

[Icons]
Name: "{group}\iptvXS"; Filename: "{app}\iptvXS.exe"; IconFilename: "{app}\iptvXS.exe"
Name: "{group}\Uninstall iptvXS"; Filename: "{uninstallexe}"
Name: "{autodesktop}\iptvXS"; Filename: "{app}\iptvXS.exe"; Tasks: desktopicon; IconFilename: "{app}\iptvXS.exe"

[Run]
Filename: "{app}\iptvXS.exe"; Description: "Launch iptvXS"; Flags: nowait postinstall skipifsilent
