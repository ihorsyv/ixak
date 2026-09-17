-- IXAK installer: asks where to install, copies the app there, adds a
-- Desktop shortcut, then deletes itself. No network access, no external
-- tools beyond what macOS ships.

set appName to "IXAK.app"
set installerPath to POSIX path of (path to me)
set payloadPath to installerPath & "Contents/Resources/" & appName

try
	set destFolder to POSIX path of (choose folder with prompt "Where should IXAK be installed? / Куда установить IXAK?" default location (path to desktop))
on error number -128
	-- User cancelled; do nothing.
	return
end try

set destPath to destFolder & appName
set desktopPath to (POSIX path of (path to desktop)) & appName

-- Zip transfer and Telegram's own sandboxing on the sending side can strip
-- the executable bit and always invalidate any prior signature, so both are
-- reasserted here rather than assumed to have survived the trip intact.
try
	do shell script "rm -rf " & quoted form of destPath & ¬
		" && cp -R " & quoted form of payloadPath & " " & quoted form of destPath & ¬
		" && xattr -cr " & quoted form of destPath & ¬
		" && chmod +x " & quoted form of (destPath & "/Contents/MacOS/IXAK") & ¬
		" && codesign --force --deep -s - " & quoted form of destPath

	set shortcutMessage to ""
	if destPath is not equal to desktopPath then
		do shell script "rm -f " & quoted form of desktopPath & " && ln -s " & quoted form of destPath & " " & quoted form of desktopPath
		set shortcutMessage to return & return & "A shortcut was added to the Desktop." & return & return & "Ярлык добавлен на рабочий стол."
	end if

	display dialog "IXAK installed to:" & return & destPath & return & return & "IXAK установлен в:" & return & destPath & shortcutMessage buttons {"OK"} default button "OK" with icon note

	-- Remove the installer after it quits (self-delete while running is unreliable).
	do shell script "(sleep 1; rm -rf " & quoted form of installerPath & ") > /dev/null 2>&1 &"
on error errMsg
	display dialog "Installation failed / Ошибка установки:" & return & errMsg buttons {"OK"} default button "OK" with icon stop
end try
