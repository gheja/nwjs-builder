#!/bin/bash

dir="$1"

if [ "$dir" == "" ]; then
	echo "$0 <dir>"
	exit 1
fi

cd "$dir"

# find the latest exe
latest_exe=`ls -t *.exe | head -n 1`

config=`tempfile`
user="yes"

{
### part 1 a: dynamic header

echo "!define APP_NAME \"test-project\""
echo "!define COMP_NAME \"Company Name\""
echo "!define VERSION \"01.02.03.04\""
echo "!define COPYRIGHT \"Copyright Info\""
echo "!define DESCRIPTION \"NWJS builder test project\""
echo "!define MAIN_APP_EXE \"${latest_exe}\""

if [ "$user" == "yes" ]; then
	echo "!define INSTALLER_NAME \"..\\${dir}-installer-user.exe\""
	echo "RequestExecutionLevel user"
	echo "InstallDir \"\$APPDATA\applicationname\""
else
	echo "!define INSTALLER_NAME \"..\\${dir}-installer.exe\""
	echo "RequestExecutionLevel admin"
	echo "InstallDir \"\$PROGRAMFILES\applicationname\""
fi


### part 1 b: static header
cat <<'EOF'
!define INSTALL_TYPE "SetShellVarContext current"
!define REG_ROOT "HKCU"
!define REG_APP_PATH "Software\Microsoft\Windows\CurrentVersion\App Paths\${MAIN_APP_EXE}"
!define UNINSTALL_PATH "Software\Microsoft\Windows\CurrentVersion\Uninstall\${APP_NAME}"
!define WEB_SITE "https://github.com/gheja/nwjs-builder"

!define REG_START_MENU "Start Menu Folder"

var SM_Folder


VIProductVersion  "${VERSION}"
VIAddVersionKey "ProductName"  "${APP_NAME}"
VIAddVersionKey "CompanyName"  "${COMP_NAME}"
VIAddVersionKey "LegalCopyright"  "${COPYRIGHT}"
VIAddVersionKey "FileDescription"  "${DESCRIPTION}"
VIAddVersionKey "FileVersion"  "${VERSION}"


SetCompressor ZLIB
Name "${APP_NAME}"
Caption "${APP_NAME}"
OutFile "${INSTALLER_NAME}"
BrandingText "${APP_NAME}"
XPStyle on
InstallDirRegKey "${REG_ROOT}" "${REG_APP_PATH}" ""
# InstallDir "$PROGRAMFILES\applicationname"


!include "MUI.nsh"

!define MUI_ABORTWARNING
!define MUI_UNABORTWARNING

!insertmacro MUI_PAGE_WELCOME

!ifdef LICENSE_TXT
!insertmacro MUI_PAGE_LICENSE "${LICENSE_TXT}"
!endif

!insertmacro MUI_PAGE_DIRECTORY

!ifdef REG_START_MENU
!define MUI_STARTMENUPAGE_DEFAULTFOLDER "applicationname"
!define MUI_STARTMENUPAGE_REGISTRY_ROOT "${REG_ROOT}"
!define MUI_STARTMENUPAGE_REGISTRY_KEY "${UNINSTALL_PATH}"
!define MUI_STARTMENUPAGE_REGISTRY_VALUENAME "${REG_START_MENU}"
!insertmacro MUI_PAGE_STARTMENU Application $SM_Folder
!endif

!insertmacro MUI_PAGE_INSTFILES

!define MUI_FINISHPAGE_RUN "$INSTDIR\${MAIN_APP_EXE}"
!insertmacro MUI_PAGE_FINISH

!insertmacro MUI_UNPAGE_CONFIRM

!insertmacro MUI_UNPAGE_INSTFILES

!insertmacro MUI_UNPAGE_FINISH

!insertmacro MUI_LANGUAGE "English"



Section -MainProgram
${INSTALL_TYPE}
SetOverwrite ifnewer
EOF


### part 2: file install

last_dir=""

# find all files, remove "./" prefixes
find -type f | sed -r 's,^\./,,g' | while read file; do
	dir=`dirname "$file"`
	
	# if directory changed then change the install directory accordingly
	if [ "$dir" != "$last_dir" ]; then
		# change "/" to "\"
		a=`echo "$dir" | sed -r 's,/,\\\\,g'`
		
		if [ "$a" == "." ]; then
			echo "SetOutPath \"\$INSTDIR\""
		else
			echo "SetOutPath \"\$INSTDIR\\${a}\""
		fi
		
		last_dir="$dir"
	fi
	
	b=`echo "$file" | sed -r 's,/,\\\\,g'`
	
	echo "File \"$b\""
done


### part 3: static middle

cat <<'EOF'
SectionEnd


Section -Icons_Reg
SetOutPath "$INSTDIR"
WriteUninstaller "$INSTDIR\uninstall.exe"

!ifdef REG_START_MENU
!insertmacro MUI_STARTMENU_WRITE_BEGIN Application
CreateDirectory "$SMPROGRAMS\$SM_Folder"
CreateShortCut "$SMPROGRAMS\$SM_Folder\${APP_NAME}.lnk" "$INSTDIR\${MAIN_APP_EXE}"
CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${MAIN_APP_EXE}"
CreateShortCut "$SMPROGRAMS\$SM_Folder\Uninstall ${APP_NAME}.lnk" "$INSTDIR\uninstall.exe"

!ifdef WEB_SITE
WriteIniStr "$INSTDIR\${APP_NAME} website.url" "InternetShortcut" "URL" "${WEB_SITE}"
CreateShortCut "$SMPROGRAMS\$SM_Folder\${APP_NAME} Website.lnk" "$INSTDIR\${APP_NAME} website.url"
!endif
!insertmacro MUI_STARTMENU_WRITE_END
!endif

!ifndef REG_START_MENU
CreateDirectory "$SMPROGRAMS\applicationname"
CreateShortCut "$SMPROGRAMS\applicationname\${APP_NAME}.lnk" "$INSTDIR\${MAIN_APP_EXE}"
CreateShortCut "$DESKTOP\${APP_NAME}.lnk" "$INSTDIR\${MAIN_APP_EXE}"
CreateShortCut "$SMPROGRAMS\applicationname\Uninstall ${APP_NAME}.lnk" "$INSTDIR\uninstall.exe"

!ifdef WEB_SITE
WriteIniStr "$INSTDIR\${APP_NAME} website.url" "InternetShortcut" "URL" "${WEB_SITE}"
CreateShortCut "$SMPROGRAMS\applicationname\${APP_NAME} Website.lnk" "$INSTDIR\${APP_NAME} website.url"
!endif
!endif

WriteRegStr ${REG_ROOT} "${REG_APP_PATH}" "" "$INSTDIR\${MAIN_APP_EXE}"
WriteRegStr ${REG_ROOT} "${UNINSTALL_PATH}"  "DisplayName" "${APP_NAME}"
WriteRegStr ${REG_ROOT} "${UNINSTALL_PATH}"  "UninstallString" "$INSTDIR\uninstall.exe"
WriteRegStr ${REG_ROOT} "${UNINSTALL_PATH}"  "DisplayIcon" "$INSTDIR\${MAIN_APP_EXE}"
WriteRegStr ${REG_ROOT} "${UNINSTALL_PATH}"  "DisplayVersion" "${VERSION}"
WriteRegStr ${REG_ROOT} "${UNINSTALL_PATH}"  "Publisher" "${COMP_NAME}"

!ifdef WEB_SITE
WriteRegStr ${REG_ROOT} "${UNINSTALL_PATH}"  "URLInfoAbout" "${WEB_SITE}"
!endif
SectionEnd


Section Uninstall
${INSTALL_TYPE}
EOF


### part 4: uninstall

# find all files, remove "./" prefixes
find -type f | sed -r 's,^\./,,g' | while read file; do
	# remove "./", and change "/" to "\"
	a=`echo "$file" | sed -r 's,/,\\\\,g'`
	
	echo "Delete \"\$INSTDIR\\$a\""
done

# find all directories, reverse their order (to delete subdirs first), remove "./" prefixes
find -type d | tac | sed -r 's,^\./,,g' | while read dir; do
	if [ "$dir" != "." ]; then
		# remove "./", and change "/" to "\"
		a=`echo "$dir" | sed -r 's,/,\\\\,g'`
		
		echo "RmDir \"\$INSTDIR\\$a\""
	fi
done


### part 5: static footer

cat <<'EOF'
Delete "$INSTDIR\uninstall.exe"
!ifdef WEB_SITE
Delete "$INSTDIR\${APP_NAME} website.url"
!endif

RmDir "$INSTDIR"

!ifdef REG_START_MENU
!insertmacro MUI_STARTMENU_GETFOLDER "Application" $SM_Folder
Delete "$SMPROGRAMS\$SM_Folder\${APP_NAME}.lnk"
Delete "$SMPROGRAMS\$SM_Folder\Uninstall ${APP_NAME}.lnk"
!ifdef WEB_SITE
Delete "$SMPROGRAMS\$SM_Folder\${APP_NAME} Website.lnk"
!endif
Delete "$DESKTOP\${APP_NAME}.lnk"

RmDir "$SMPROGRAMS\$SM_Folder"
!endif

!ifndef REG_START_MENU
Delete "$SMPROGRAMS\applicationname\${APP_NAME}.lnk"
Delete "$SMPROGRAMS\applicationname\Uninstall ${APP_NAME}.lnk"
!ifdef WEB_SITE
Delete "$SMPROGRAMS\applicationname\${APP_NAME} Website.lnk"
!endif
Delete "$DESKTOP\${APP_NAME}.lnk"

RmDir "$SMPROGRAMS\applicationname"
!endif

DeleteRegKey ${REG_ROOT} "${REG_APP_PATH}"
DeleteRegKey ${REG_ROOT} "${UNINSTALL_PATH}"
SectionEnd

EOF
} > $config

echo "NSIS configuration:"
cat $config

# cannot use "makensis $config" as it defaults source dir to config dir

cat $config | makensis -
