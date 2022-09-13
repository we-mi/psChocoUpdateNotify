function Start-PSChocoUpdateNotify {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [string]
        [ValidateSet("GUI","Notification")]
        $Mode = "Notification"
    )

    Start-Process -FilePath "powershell.exe" -ArgumentList "-file `"$(Join-Path $PSScriptRoot "psChocoUpdateNotify.ps1")`" -Mode $Mode" -WindowStyle "Hidden"
}
