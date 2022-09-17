Set objShell	= CreateObject("WScript.shell")
Set oFSO		= CreateObject("Scripting.FileSystemObject")
Dim sScriptDir : sScriptDir = oFSO.GetParentFolderName(WScript.ScriptFullName)

objShell.CurrentDirectory = sScriptDir

objShell.run "Powershell.exe -WindowStyle Hidden -File psChocoUpdateNotify.ps1 -Mode GUI", 0, False
