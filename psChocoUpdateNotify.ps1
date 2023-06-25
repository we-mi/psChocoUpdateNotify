[CmdletBinding()]
param (
    [Parameter(Mandatory=$false)]
    [Object[]]
    $OutdatedPackages,

    [Parameter(Mandatory=$false)]
    [string]
    [ValidateSet("GUI","Notification")]
    $Mode = "Notification",

    [Parameter(
        Mandatory = $false
    )]
    [System.IO.FileInfo]
    $SettingsFile = (Join-Path $env:APPDATA "psChocoUpdateNotify\settings.json"),

    [Parameter(Mandatory=$false)]
    [switch]$IgnoreStartupChecks,

    [Parameter(Mandatory=$false)]
    [switch]$SkipGUIInitialSearch
)

$ErrorActionPreference = "Stop"

[void][System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms")
[void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
[void][System.Reflection.Assembly]::LoadWithPartialName('presentationframework')
[void][System.Reflection.Assembly]::LoadWithPartialName('Microsoft.VisualBasic')

# Loading helper functions
. (Join-Path $PSScriptRoot "helpers.ps1")

# Define GUI version
$script:version = "1.2.2"

# Define some other useful variables
$script:projectRootFolder = $PSScriptRoot

# Load settings.json
Write-Logs -Message "Load settings" -LogLevel DEBUG
if (Test-Path $settingsFile ) {
    $script:settings = Get-Content -Encoding UTF8 -Path $settingsFile | ConvertFrom-Json

    if ($null -eq $settings) {
        $settings = [PSCustomObject]@{}
    }
    $settings = Test-Settings -settings $settings

    Write-Logs -Message "Loaded settings from $($settingsFile)" -LogLevel Info

} else { # if non-existant: create dir and default-configfile

    if (-not (Test-Path (Split-Path $settingsFile) ) ) {
        New-Item -ItemType Directory (Split-Path $settingsFile)
    }

    $settings = Test-Settings # this will create all default settings
    Write-Logs -Message "Loaded default settings because the currently set config file was not found ($settingsFile)" -LogLevel Info
}

if ($Mode -eq "Notification") {
    Write-Logs -Message "Starting script in notification-mode" -LogLevel Info

    # BurntToast-Module requires Windows 10 or Server 2019. Show a warning on other operating systems
    [int]$buildNumber = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\" -Name CurrentBuildNumber | Select-Object -ExpandProperty CurrentBuildNumber
    if ($buildNumber -lt 17763) {
        Write-Logs -Message "Operating system is not supported by the BurntToast-Module. Warn the user" -LogLevel Warning
        $answer = [System.Windows.Forms.MessageBox]::Show("This program requires at least Windows 10 1809 or Windows Server 2019 (Build number 17763 or higher)`n`nOther operating systems were not tested.`nProceed on your own, if you wish to continue?", "Operating system warning", "YesNo", "Warning")
        if ($answer -ne "Yes") {
            Write-Logs -Message "Operating system is not supported by the BurntToast-Module. Exited script by user-choice" -LogLevel Info
            Write-Host  "Cancel start on user-choice"
            Exit 0
        }
    }

    try {
        Import-Module (Join-Path $script:projectRootFolder ".\BurntToast\BurntToast.psd1")
    } catch {
        Write-Logs -Message "The BurntToast-Module could not be loaded. Cannot continue. Error message was: $($_)" -LogLevel Critical
    }

    if (Test-ChocolateyInstall) {
        # Checking if psChocoUpdateNotifyUpdate:// and psChocoUpdateNotifyGUI:// protocol handlers are present
        New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT -ErrorAction SilentlyContinue | Out-Null
        $ProtocolHandlerUpdate = Get-ItemProperty 'HKCR:\psChocoUpdateNotifyUpdate\Shell\open\command' -Name '(Default)' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty '(Default)'
        $ProtocolHandlerGUI = Get-ItemProperty 'HKCR:\psChocoUpdateNotifyGUI\Shell\open\command' -Name '(Default)' -ErrorAction SilentlyContinue | Select-Object -ExpandProperty '(Default)'
        Remove-PSDrive -Name HKCR

        $ProtocolHandlerUpdateDesiredValue = "cscript.exe `"$(Join-Path $script:projectRootFolder 'psChocoUpdateNotifyUpdate.vbs')`""
        $ProtocolHandlerGUIDesiredValue = "cscript.exe `"$(Join-Path $script:projectRootFolder 'psChocoUpdateNotifyGUI.vbs')`""
        $LogonTask = Get-ScheduledTask -TaskName "psChocoUpdateNotify-Logon" -TaskPath "\psChocoUpdateNotify\" -ErrorAction SilentlyContinue

        if ( $IgnoreStartupChecks.IsPresent -eq $false -and                                                                                 # Check if we should update things
            ([String]::IsNullOrWhiteSpace($ProtocolHandlerUpdate) -or [String]::IsNullOrWhiteSpace($ProtocolHandlerGUI) -or                 # Paths are present
            $ProtocolHandlerUpdate -ne $ProtocolHandlerUpdateDesiredValue -or $ProtocolHandlerGUI -ne $ProtocolHandlerGUIDesiredValue -or   # Values are correct
            $null -eq $LogonTask)                                                                                                           # Task is present (do not check the task itself. This means you can do changes to the task if you wish to, without loosing them on an update)
            ) {

            Write-Logs -Message "A protocol-handler or the task was not setup as expected. Warn the user about this and ask what to do" -LogLevel Warning

            $sh = New-Object -ComObject "Wscript.Shell"
            $answer = $sh.Popup("This looks like it's either the first time you're starting this application or some path/the scheduled task needs an update.`n`nYou might be asked for elevated permissions in order to install or update protocol handlers or the task!`n`nDo you want to continue? If you do not click 'Yes' here, some basic things might not work for you!`n`nYes = Go ahead`nNo = Dont install/update`nCancel = exit application`n`nThis window will autoclose with 'Yes' in 120 seconds",120,"Protocol Handler/scheduled task install/update",3+32)

            if ($answer -eq -1 -or $answer -eq 6) { # -1 = Timeout reached; 6 = Yes
                Write-Logs -Message "Updating protocol-handlers and the task. Might need to ask for elevated permissions..." -LogLevel Debug

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

`$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument "-WindowStyle Hidden -NonInteractive -NoLogo -NoProfile -File ```"$(Join-Path $script:projectRootFolder "psChocoUpdateNotify.ps1")```""
`$Trigger = New-ScheduledTaskTrigger -AtLogOn
`$Settings = New-ScheduledTaskSettingsSet
`$Task = New-ScheduledTask -Action `$Action -Trigger `$Trigger -Settings `$Settings
Register-ScheduledTask -TaskName 'psChocoUpdateNotify-Logon' -InputObject `$Task -TaskPath "\psChocoUpdateNotify" -Force

Remove-PSDrive -Name HKCR
"@ | Out-File -FilePath $ps1File

                Start-Process -FilePath "powershell.exe" -ArgumentList "-File $ps1File -WindowStyle Normal -NoProfile" -verb RunAs -Wait

                Remove-Item $ps1File -ErrorAction SilentlyContinue
            } elseif ($answer -eq 2) { # 2 = Cancel / Close Window / ESC
                Write-Logs -Message "Some protocol-handler or the task was not setup as expected but the user chose to not continue. Aborting here" -LogLevel Warning
                Exit 0
            }
        } else {
            Write-Logs "Protocol-Handlers and the scheduled task are setup correctly. Continuing." -LogLevel Debug
        }

        if (-not $OutdatedPackages) {
            Write-Logs "Finding outdated packages with 'choco outdated --ignore-unfound'" -LogLevel Debug
            $script:OutdatedPackages = @(Start-Choco -Command "outdated" -Options "--ignore-unfound")
            Write-Logs "Found $($script:OutdatedPackages.Count) outdated packages by using 'choco outdated --ignore-unfound'" -LogLevel Info

        } else {
            Write-Logs "Using packages from parameter 'Outdated-Packages'. This not really tested yet, use it with caution." -LogLevel Warning
        }

        Write-Logs "Building toast-notification depending on found packages" -LogLevel Debug
        try {
            if ($script:OutdatedPackages) {
                $appimage = New-BTImage -Source (Join-Path $script:projectRootFolder "Images\icon_256.png") -AppLogoOverride
                $Text1 = New-BTText -Content  "Chocolatey Package Updates"
                $Text2 = New-BTText -Content "$($script:OutdatedPackages.Count) Updates were found. Please choose if you'd like to update them all now, open the GUI, or snooze this message."
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
        } catch {
            Write-Logs "Could not build toast-notification. Cannot continue. The error message was $($_)" -LogLevel Critical
            Exit 1
        }

        Write-Logs "Showing toast-notification" -LogLevel Debug
        try {
            Submit-BTNotification -Content $Content
        } catch {
            Write-Logs "Could not show toast-notification. Cannot continue. The error message was $($_)" -LogLevel Critical
            Exit 1
        }
    } else { # choco not installed or not in PATH
        Write-Logs -Message "Chocolatey was not found. Inform the user about it and show a button where to download it" -LogLevel Warning
        $appimage = New-BTImage -Source (Join-Path $script:projectRootFolder "Images\icon_256.png") -AppLogoOverride
        $Text1 = New-BTText -Content  "Chocolatey Installation"
        $Text2 = New-BTText -Content "Chocolatey was not found on your system.`n`nYou can install it by visiting chocolatey.org and follow the instructions"
        $Button1 = New-BTButton -Content "Install" -Arguments "https://chocolatey.org/install" -ActivationType Protocol
        $Button2 = New-BTButton -Content "Dismiss" -Dismiss
        $action = New-BTAction -Buttons $Button1, $Button2
        $Binding = New-BTBinding -Children $text1, $text2 -AppLogoOverride $appimage
        $Visual = New-BTVisual -BindingGeneric $Binding
        $Content = New-BTContent -Visual $Visual -Actions $action

        Submit-BTNotification -Content $Content
    }

} elseif ($Mode -eq "GUI") {
    Write-Logs -Message "Starting script in gui-mode" -LogLevel Info

    # Load XAML File
    Write-Logs -Message "Loading xml for mainWindow (window.xaml)" -Loglevel "debug"
    try {
        $xaml = [xml](Get-Content (Join-Path $script:projectRootFolder "windows\mainWindow\window.xaml") -ErrorAction Stop)
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
    . (Join-Path $script:projectRootFolder "windows\mainWindow\events.ps1")

    # Show the main window
    Write-Logs -Message "Displaying mainWindow" -Loglevel "debug"
    try {
        [void]$window.ShowDialog()
    } catch {
        Write-Logs -Message "An unknown error occured when showing the mainWindow. This should not have happened. The error message was: $($_)"
    }
}

Write-Logs -Message "Saving settings back to $settingsFile"
$settings | ConvertTo-Json | Out-File -Encoding UTF8 -FilePath $settingsFile
