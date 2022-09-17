Set objShell	= CreateObject("WScript.shell")
Set oFSO		= CreateObject("Scripting.FileSystemObject")
Dim sScriptDir : sScriptDir = oFSO.GetParentFolderName(WScript.ScriptFullName)

objShell.run "PowerShell.exe -Command ""Start-Process -Verb RunAs -FilePath 'choco' -ArgumentList 'upgrade -y all'""", 0, False