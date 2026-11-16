; Zoraxy setup for Windows (x64): official zoraxy_windows_amd64.exe + WinSW service.
; Built by "make windows" with makensis, which defines:
;   VERSION, RELEASE, VI_VERSION (x.x.x.x), SRCDIR (staged files), OUTFILE
;
; Silent install: zoraxy-setup.exe /S        (add /NOSTART to leave the service stopped)
; Silent removal: "C:\Program Files\Zoraxy\uninstall.exe" /S

Unicode true
SetCompressor /SOLID lzma
RequestExecutionLevel admin
ManifestDPIAware true

!include "MUI2.nsh"
!include "LogicLib.nsh"
!include "x64.nsh"
!include "FileFunc.nsh"

!define PRODUCT     "Zoraxy"
!define SERVICE     "zoraxy"
!define UNINST_KEY  "Software\Microsoft\Windows\CurrentVersion\Uninstall\Zoraxy"
!define UI_URL      "http://127.0.0.1:8000/"
!define REPO_URL    "https://github.com/fdefilippo/zoraxy-linux-packages"

Name "${PRODUCT} ${VERSION}"
OutFile "${OUTFILE}"
InstallDir "$PROGRAMFILES64\${PRODUCT}"
InstallDirRegKey HKLM "${UNINST_KEY}" "InstallLocation"
BrandingText "${PRODUCT} ${VERSION}-${RELEASE}"

VIProductVersion "${VI_VERSION}"
VIFileVersion "${VI_VERSION}"
VIAddVersionKey "ProductName" "${PRODUCT}"
VIAddVersionKey "ProductVersion" "${VERSION}"
VIAddVersionKey "FileVersion" "${VERSION}-${RELEASE}"
VIAddVersionKey "FileDescription" "${PRODUCT} setup"
VIAddVersionKey "LegalCopyright" "Zoraxy authors, AGPL-3.0"
VIAddVersionKey "Comments" "${REPO_URL}"

Var Upgrade

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN
!define MUI_FINISHPAGE_RUN_TEXT "Open the management interface (${UI_URL})"
!define MUI_FINISHPAGE_RUN_FUNCTION OpenUI
!define MUI_FINISHPAGE_TEXT "The Zoraxy service is installed and started.$\r$\n$\r$\nOn the first visit, the management interface asks you to create the admin account. Command line options: $INSTDIR\zoraxy-service.xml. Data: $APPDATA\${PRODUCT}."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${SRCDIR}\LICENSE.txt"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "English"

Function .onInit
  ${IfNot} ${RunningX64}
    MessageBox MB_ICONSTOP "Zoraxy requires 64-bit Windows." /SD IDOK
    Abort
  ${EndIf}
  SetRegView 64
  SetShellVarContext all
FunctionEnd

Function un.onInit
  SetRegView 64
  SetShellVarContext all
FunctionEnd

Function OpenUI
  ExecShell "open" "${UI_URL}"
FunctionEnd

Section "Zoraxy" SecMain
  SectionIn RO
  StrCpy $Upgrade 0
  ${If} ${FileExists} "$INSTDIR\zoraxy-service.exe"
    StrCpy $Upgrade 1
    DetailPrint "Stopping the Zoraxy service"
    nsExec::ExecToLog '"$INSTDIR\zoraxy-service.exe" stop'
    Pop $0
    Sleep 2000
  ${EndIf}

  SetOutPath "$INSTDIR"
  File "${SRCDIR}\zoraxy.exe"
  File "${SRCDIR}\zoraxy-service.exe"
  File "${SRCDIR}\LICENSE.txt"
  ; keep the service configuration (command line options) on upgrade
  ${IfNot} ${FileExists} "$INSTDIR\zoraxy-service.xml"
    File "${SRCDIR}\zoraxy-service.xml"
  ${EndIf}

  ; data directory, writable by the service account (LocalService, SID S-1-5-19)
  CreateDirectory "$APPDATA\${PRODUCT}"
  CreateDirectory "$APPDATA\${PRODUCT}\log"
  nsExec::ExecToLog 'icacls "$APPDATA\${PRODUCT}" /grant "*S-1-5-19:(OI)(CI)M"'
  Pop $0

  ${If} $Upgrade == 0
    DetailPrint "Installing the Zoraxy service"
    nsExec::ExecToLog '"$INSTDIR\zoraxy-service.exe" install'
    Pop $0
    ${If} $0 != 0
      MessageBox MB_ICONSTOP "Could not install the Zoraxy service (exit code $0)." /SD IDOK
      Abort
    ${EndIf}
  ${EndIf}

  ; inbound HTTP, HTTPS and HTTP/3 for zoraxy.exe (the management port stays closed)
  nsExec::ExecToLog 'netsh advfirewall firewall delete rule name="Zoraxy"'
  Pop $0
  nsExec::ExecToLog 'netsh advfirewall firewall add rule name="Zoraxy" dir=in action=allow protocol=TCP localport=80,443 program="$INSTDIR\zoraxy.exe"'
  Pop $0
  nsExec::ExecToLog 'netsh advfirewall firewall add rule name="Zoraxy" dir=in action=allow protocol=UDP localport=443 program="$INSTDIR\zoraxy.exe"'
  Pop $0

  WriteUninstaller "$INSTDIR\uninstall.exe"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayName" "${PRODUCT}"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayVersion" "${VERSION}"
  WriteRegStr HKLM "${UNINST_KEY}" "Publisher" "Zoraxy (packaged by ${REPO_URL})"
  WriteRegStr HKLM "${UNINST_KEY}" "URLInfoAbout" "https://github.com/tobychui/zoraxy"
  WriteRegStr HKLM "${UNINST_KEY}" "InstallLocation" "$INSTDIR"
  WriteRegStr HKLM "${UNINST_KEY}" "DisplayIcon" "$INSTDIR\zoraxy.exe"
  WriteRegStr HKLM "${UNINST_KEY}" "UninstallString" '"$INSTDIR\uninstall.exe"'
  WriteRegStr HKLM "${UNINST_KEY}" "QuietUninstallString" '"$INSTDIR\uninstall.exe" /S'
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoModify" 1
  WriteRegDWORD HKLM "${UNINST_KEY}" "NoRepair" 1
  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  WriteRegDWORD HKLM "${UNINST_KEY}" "EstimatedSize" $0

  ${GetParameters} $R0
  ClearErrors
  ${GetOptions} $R0 "/NOSTART" $R1
  ${If} ${Errors}
    DetailPrint "Starting the Zoraxy service"
    nsExec::ExecToLog '"$INSTDIR\zoraxy-service.exe" start'
    Pop $0
  ${EndIf}
SectionEnd

Section "Uninstall"
  DetailPrint "Removing the Zoraxy service"
  nsExec::ExecToLog '"$INSTDIR\zoraxy-service.exe" stop'
  Pop $0
  Sleep 2000
  nsExec::ExecToLog '"$INSTDIR\zoraxy-service.exe" uninstall'
  Pop $0
  nsExec::ExecToLog 'netsh advfirewall firewall delete rule name="Zoraxy"'
  Pop $0

  Delete "$INSTDIR\zoraxy.exe"
  Delete "$INSTDIR\zoraxy-service.exe"
  Delete "$INSTDIR\zoraxy-service.xml"
  Delete "$INSTDIR\zoraxy-service.wrapper.log"
  Delete "$INSTDIR\LICENSE.txt"
  Delete "$INSTDIR\uninstall.exe"
  RMDir "$INSTDIR"
  DeleteRegKey HKLM "${UNINST_KEY}"
  ; the data (certificates, configuration, database) is kept
  DetailPrint "Data kept in $APPDATA\${PRODUCT}"
SectionEnd
