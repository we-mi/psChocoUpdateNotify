[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [Object[]]
    $OutdatedPackages,

    [Parameter(Mandatory=$false)]
    [string]
    [ValidateSet("GUI","Notification")]
    $Mode = "Notification"
)

$ErrorActionPreference = "Stop"

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')

# Loading helper functions
. "$PSScriptRoot\helpers.ps1"

# Define GUI version
$script:version = "1.1.1"

# Define some other useful variables
$script:projectRootFolder = $PSScriptRoot

if ($Mode -eq "Notification") {
    Import-Module (Join-Path $script:projectRootFolder ".\BurntToast\BurntToast.psd1")

    # Checking if psChocoUpdateNotifyUpdate:// and psChocoUpdateNotifyGUI:// protocol handlers are present
    New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
    $ProtocolHandlerUpdate = Get-ItemProperty 'HKCR:\psChocoUpdateNotifyUpdate\Shell\open\command' -Name '(Default)' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty '(Default)'
    $ProtocolHandlerGUI = Get-ItemProperty 'HKCR:\psChocoUpdateNotifyGUI\Shell\open\command' -Name '(Default)' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty '(Default)'
    Remove-PSDrive -Name HKCR

    $ProtocolHandlerUpdateDesiredValue = "cscript.exe `"$(Join-Path $script:projectRootFolder 'psChocoUpdateNotifyUpdate.vbs')`""
    $ProtocolHandlerGUIDesiredValue = "cscript.exe `"$(Join-Path $script:projectRootFolder 'psChocoUpdateNotifyGUI.vbs')`""
    $LogonTask = Get-ScheduledTask -TaskName "psChocoUpdateNotify-Logon" -TaskPath "\psChocoUpdateNotify\" -ErrorAction SilentlyContinue

    if ([String]::IsNullOrWhiteSpace($ProtocolHandlerUpdate) -or [String]::IsNullOrWhiteSpace($ProtocolHandlerGUI) -or
        $ProtocolHandlerUpdate -ne $ProtocolHandlerUpdateDesiredValue -or $ProtocolHandlerGUI -ne $ProtocolHandlerGUIDesiredValue -or
        $null -eq $LogonTask) {

        $sh = New-Object -ComObject "Wscript.Shell"
        $answer = $sh.Popup("This looks like it's either the first time you're starting this application or some path/the scheduled task needs an update.`n`nYou might be asked for elevated permissions in order to install or update protocol handlers or the task!`n`nDo you want to continue? If you do not click 'Yes' here, some basic things might not work for you!`n`nYes = Go ahead`nNo = Dont install/update`nCancel = exit application`n`nThis window will autoclose with 'OK' in 120 seconds",120,"Protocol Handler/scheduled task install/update",3+32)

        if ($answer -eq -1 -or $answer -eq 6) { # -1 = Timeout reached; 6 = Yes

            $ps1File = Join-Path $env:TEMP "Create-ProtocolHandler.ps1"
        @"
New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null

New-item 'HKCR:\psChocoUpdateNotifyUpdate' -Force
Set-ItemProperty 'HKCR:\psChocoUpdateNotifyUpdate' -Name '(DEFAULT)' -value 'url:psChocoUpdateNotifyUpdate' -Force
Set-ItemProperty 'HKCR:\psChocoUpdateNotifyUpdate' -Name 'URL Protocol' -value '' -Force
New-ItemProperty -Path 'HKCR:\psChocoUpdateNotifyUpdate' -PropertyType dword -Name 'EditFlags' -value 2162688
New-Item 'HKCR:\psChocoUpdateNotifyUpdate\Shell\Open\command' -Force
Set-ItemProperty 'HKCR:\psChocoUpdateNotifyUpdate\Shell\Open\command' -Name '(DEFAULT)' -value 'cscript.exe "$(Join-Path $script:projectRootFolder 'psChocoUpdateNotifyUpdate.vbs')"' -Force

New-item 'HKCR:\psChocoUpdateNotifyGUI' -Force
Set-ItemProperty 'HKCR:\psChocoUpdateNotifyGUI' -Name '(DEFAULT)' -value 'url:psChocoUpdateNotifyGUI' -Force
Set-ItemProperty 'HKCR:\psChocoUpdateNotifyGUI' -Name 'URL Protocol' -value '' -Force
New-ItemProperty -Path 'HKCR:\psChocoUpdateNotifyGUI' -PropertyType dword -Name 'EditFlags' -value 2162688
New-Item 'HKCR:\psChocoUpdateNotifyGUI\Shell\Open\command' -Force
Set-ItemProperty 'HKCR:\psChocoUpdateNotifyGUI\Shell\Open\command' -Name '(DEFAULT)' -value 'cscript.exe "$(Join-Path $script:projectRootFolder 'psChocoUpdateNotifyGUI.vbs')"' -Force

`$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-NonInteractive -NoLogo -NoProfile -File '$(Join-Path $script:projectRootFolder "psChocoUpdateNotify.ps1")'"
`$Trigger = New-ScheduledTaskTrigger -AtLogOn
`$Settings = New-ScheduledTaskSettingsSet
`$Task = New-ScheduledTask -Action `$Action -Trigger `$Trigger -Settings `$Settings
Register-ScheduledTask -TaskName 'psChocoUpdateNotify-Logon' -InputObject `$Task -TaskPath "\psChocoUpdateNotify" -Force

Remove-PSDrive -Name HKCR
"@ | Out-File -FilePath $ps1File

            Start-Process -FilePath "powershell.exe" -ArgumentList "-File $ps1File -WindowStyle Normal -NoProfile" -verb RunAs -Wait

            Remove-Item $ps1File -ErrorAction SilentlyContinue
        } elseif ($answer -eq 2) { # 2 = Cancel / Close Window / ESC
            Exit 0
        }
    }

    if (-not $OutdatedPackages) {
        $script:OutdatedPackages = @(Start-Choco -Command "outdated" -Options "--ignore-unfound")
    }

    if ($script:OutdatedPackages) {
        $appimage = New-BTImage -Source (Join-Path $script:projectRootFolder "Images\icon_256.png") -AppLogoOverride
        $Text1 = New-BTText -Content  "Chocolatey Package Updates"
        $Text2 = New-BTText -Content "$($script:OutdatedPackages.Count) Updates were found. Please select if you'd like to update them all now, open the GUI, or snooze this message."
        $Button1 = New-BTButton -Content "Update" -Arguments "psChocoUpdateNotifyUpdate:" -ActivationType Protocol
        $Button2 = New-BTButton -Content "GUI" -Arguments "psChocoUpdateNotifyGUI:" -ActivationType Protocol
        $Button3 = New-BTButton -Content "Snooze" -snooze -id 'SnoozeTime'
        $Button4 = New-BTButton -Content "Dismiss" -Dismiss
        $1Min = New-BTSelectionBoxItem -Id 1 -Content 'Snooze for 1 minute'
        $5Min = New-BTSelectionBoxItem -Id 5 -Content 'Snooze for 5 minutes'
        $15Min = New-BTSelectionBoxItem -Id 10 -Content 'Snooze for 15 minutes'
        $30Min = New-BTSelectionBoxItem -Id 30 -Content 'Snooze for 30 minutes'
        $1Hour = New-BTSelectionBoxItem -Id 60 -Content 'Snooze for 1 hour'
        $Items = $1Min, $5Min, $15Min, $30Min, $1Hour
        $SelectionBox = New-BTInput -Id 'SnoozeTime' -DefaultSelectionBoxItemId 5 -Items $Items
        $action = New-BTAction -Buttons $Button1, $Button2, $Button3, $Button4 -inputs $SelectionBox
        $Binding = New-BTBinding -Children $text1, $text2 -AppLogoOverride $appimage
        $Visual = New-BTVisual -BindingGeneric $Binding
        $Content = New-BTContent -Visual $Visual -Actions $action
    } else {
        $appimage = New-BTImage -Source (Join-Path $script:projectRootFolder "Images\icon_256.png") -AppLogoOverride
        $Text1 = New-BTText -Content  "Chocolatey Package Updates"
        $Text2 = New-BTText -Content "Your packages are up-to-date :>"
        $Button = New-BTButton -Content "Dismiss" -Dismiss
        $action = New-BTAction -Buttons $Button
        $Binding = New-BTBinding -Children $text1, $text2 -AppLogoOverride $appimage
        $Visual = New-BTVisual -BindingGeneric $Binding
        $Content = New-BTContent -Visual $Visual -Actions $action
    }    
    Submit-BTNotification -Content $Content

} elseif ($Mode -eq "GUI") {
    # Load XAML File
    Write-Logs -Message "Loading xml for mainWindow (window.xaml)" -Loglevel "debug"
    try {
        $xaml = [xml](Get-Content (Join-Path $script:projectRootFolder "window.xaml") -ErrorAction Stop)
        $window = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xaml) )
    } catch [System.Management.Automation.RuntimeException] {
        if ($_.CategoryInfo.Reason -eq "RuntimeException") { # file could not be parsed as a xml
            Write-Logs -Message "XAML-File could not be parsed as a xml file. Check the XAMl-Content" -Loglevel "emergency"
            Exit
        } elseif ($_.CategoryInfo.Reason -eq "MethodInvocationException") { # Xml could not be loaded by XamlReader
            Write-Logs -Message "XAML-Content could not be loaded by XamlReader-Object. Check the XAMl-Content" -Loglevel "emergency"
            Exit
        } elseif ($_.CategoryInfo.Reason -eq "ItemNotFoundException") {
            Write-Logs -Message "XAML-File was not found" -Loglevel "emergency"
            Exit
        }
    } catch  {
        Write-Logs -Message "Other error while reading and parsing the XAML-File ($($_.Exception))" -Loglevel "emergency"
        Exit
    }

    # Find Window Objects
    Write-Logs -Message "Converting elements to variables for mainWindow" -Loglevel "debug"
    foreach ($node in $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")){ 
        New-Variable -Name $node.Name -Value $window.FindName($node.Name) -Force -Scope "Script"
    }

    # Load events for the main window
    Write-Logs -Message "Load events-file for mainWindow" -Loglevel "debug"
    . (Join-Path $PSScriptRoot "events.ps1")

    # Show the main window
    Write-Logs -Message "Displaying mainWindow" -Loglevel "debug"
    [void]$window.ShowDialog()
}