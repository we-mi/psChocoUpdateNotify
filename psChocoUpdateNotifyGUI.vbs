Set objShell	= CreateObject("WScript.shell")
Set oFSO		= CreateObject("Scripting.FileSystemObject")
Dim sScriptDir : sScriptDir = oFSO.GetParentFolderName(WScript.ScriptFullName)

objShell.run "PowerShell.exe -Command ""Start-Process -WindowStyle Hidden -FilePath 'powershell.exe' -ArgumentList '-File " & sScriptDir & "\choco-updater.ps1 -Mode GUI'"" ", 0, True
