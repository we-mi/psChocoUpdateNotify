function Write-Logs {
    [CmdletBinding()]
    [OutputType([boolean])]
    param (
        # Text which will be written into the eventlog
        [Parameter(
            Mandatory = $true
        )]
        [string[]]
        [Alias("text")]
        $Message,

        # LogLevel
        [Parameter(
            Mandatory = $false
        )]
        [ValidateSet(
            "Debug",
            "Info","Information","Informational",
            "Notice",
            "Warning",
            "Error",
            "Critical",
            "Alert",
            "Emergency"         
        )]
        [Alias("Level","Severity")]
        [string]
        $LogLevel = "informational",

        [Parameter(Mandatory = $false)]
        [ValidateSet("eventlog","console","file")]
        [String[]]$LogTypes = @("console","file"),

        [Parameter(Mandatory = $false)]
        [String]$LogFile = (Join-Path $env:APPDATA "psChocoUpdateNotify\psChocoUpdateNotify.log")
    )
    
    process {
        
        foreach ($logType in $LogTypes) {
            switch ($logType) {
                "eventlog" {
                    # Windows eventlog does not know about all LogLevels from syslog
                    if ( @("Debug","Informational","Notice") -contains $LogLevel) {
                        $LogLevel = "Information"
                    }
                    if ( @("Critical","Emergency") -contains $LogLevel) {
                        $LogLevel = "Error"
                    }

                    foreach ($logEntry in $Message) {
                        Write-EventLog -Logname "Application" -Source "psChocoUpdateNotifier" -EventId 1 -EntryType $LogLevel -Message $logEntry
                    }
                }

                "console" {
                    foreach ($logEntry in $Message) {
                        Write-Host "$($LogLevel.ToUpper()): $($logEntry)"
                    }
                }

                "file" {
                    if(!(Test-Path $LogFile)) {
                        New-Item -Path $LogFile -Force | Out-Null
                    }
                    foreach ($logEntry in $Message) {
                        Out-File -FilePath $LogFile -Encoding utf8 -Append -InputObject "$($LogLevel.ToUpper()): $($logEntry)"
                    }
                }

                Default {}
            }
        }
        
    }
}

function Start-Choco { # implement the pschoco module from https://gitlab.com/Paxz/choco_gui/tree/master/pschoco into this script, for better integration 
    <#
    .SYNOPSIS
    Chocolatey Output Parserfunction
    
    .DESCRIPTION
    This function behaves like the normal choco.exe, except that it interepretes the given results of some commands and parses them to PSCustomObjects.
    This should make working with chocolatey alot easier if you really want to integrate it into your scripts.
    
    .PARAMETER command
    Chocolatey Command - basically the same command you would write after `choco`.
    Original Documentation to Chocolatey Commands: https://github.com/chocolatey/choco/wiki/CommandsList
    
    .PARAMETER options
    Chocolatey Options - the same options that you would write after the command of an `choco`-Invoke
    Original Documentation to Chocolatey Options and Switches: https://github.com/chocolatey/choco/wiki/CommandsReference#default-options-and-switches

    .INPUTS
    Options can be given through the pipeline. Further explained in Example 4.

    .OUTPUTS
    [System.Management.Automation.PSCustomObject], PSCustomObject of all important informations returned by the `choco` call

    .EXAMPLE
    PS C:\>Start-Choco -Command "list" -Option "-lo"
    Runs `choco list -lo` and parses the output to an object with the Attributes `PackageName` and `Version`.
    The options parameter has to be written in `"` or `'` so that powershell doesn't interpret the Value as an extra Parameter for this function

    .EXAMPLE
    PS C:\>Start-Choco info vscode
    Runs `choco info vscode` and parses the output to an PSCustomObject
    
    .EXAMPLE
    PS C:\>pschoco outdated
    Runs `choco outdated` over the function alias and parses the output like explained in the first example.

    .EXAMPLE
    PS C:\>@("vscode","firefox") | Start-Choco info
    Options can be passed through the pipeline. Thisway each entry will be given as the option: `Start-Choco info <PipeElement>`.

    .LINK
    https://github.com/chocolatey/choco/wiki/CommandsList
    https://github.com/chocolatey/choco/wiki/CommandsReference#default-options-and-switches

    .NOTES
    Currently Supported Chocolatey Commands (everything else works like the default `choco.exe`):
        - outdated
        - search|list|find
        - source|sources
        - info
        - config
        - feature
        - pin
    #>
    
    [CmdletBinding()]
    [alias("schoco","pschoco")]
    param (
        [Parameter(
            Mandatory=$true,
            ValueFromPipelineByPropertyName=$true,
            Position=0
        )]
        [ValidateNotNullOrEmpty()]
        [string]
        $command,

        [Parameter(
            Mandatory=$false,
            ValueFromPipelineByPropertyName=$true,
            ValueFromPipeline=$true,
            Position=1
        )]
        [string[]]
        $options = @()
    )
    
    begin {

        $proc = $null
        try {
            $proc = Start-Process -FilePath "roco" -Wait -PassThru -NoNewWindow -ErrorAction SilentlyContinue
        } catch { }

        if ($null -eq $proc -or $proc.ExitCode -ne 0) {
            $ChocoEXE = "choco"
        } else {
            $ChocoEXE = "roco"
        }

        Write-Host "Using $ChocoEXE"
    }
    
    process {
        switch -Regex ($command) {
            '^(outdated)$' {
                & $ChocoEXE $command @options | Select-String -Pattern '^([\w-.]+)\|(.*)\|(.*)\|.*$' | ForEach-Object {
                    [PSCustomObject]@{
                        PackageName = $_.matches.groups[1].value
                        currentVersion = $_.matches.groups[2].value
                        newVersion = $_.matches.groups[3].value
                    }
                }
            }

            '^(search|list|find)$' {
                & $ChocoEXE $command @options | Select-String -Pattern '^([\w-.]+) ([\d.]+)' | ForEach-Object {
                    [PSCustomObject]@{
                        PackageName = $_.matches.groups[1].value
                        Version = $_.matches.groups[2].value
                    }
                }
            }

            '^(source[s]*)$' {
                if($options -notcontains 'add|disable|enable|remove') {
                    & $ChocoEXE $command @options | Select-String -Pattern '^([\w-.]+)( \[Disabled\])? - (\S+) \| Priority (\d)\|Bypass Proxy - (\w+)\|Self-Service - (\w+)\|Admin Only - (\w+)\.$' | ForEach-Object {
                        if ($_.matches.groups[2].value -eq ' [Disabled]') {
                            $Enabled = $False
                        } else {
                            $Enabled = $True
                        }
                        [PSCustomObject]@{
                            SourceName = $_.matches.groups[1].value
                            Enabled = $Enabled
                            Url = $_.matches.groups[3].value
                            Priority = $_.matches.groups[4].value
                            "Bypass Proxy" = $_.matches.groups[5].value
                            "Self-Service" = $_.matches.groups[6].value
                            "Admin Only" = $_.matches.groups[7].value
                        }
                    }
                }
                else {
                    & $ChocoEXE $command @options
                }
            }

            '^(info)$' {
                $infoArray = (((& $ChocoEXE $command @options) -split '\|') | Where-Object {$_ -match '.*: .*'}).trim() -replace ': ','=' | ConvertFrom-StringData
                
                $infoReturn = New-Object PSObject
                foreach ($infoItem in $infoArray) {
                    Add-Member -InputObject $infoReturn -MemberType NoteProperty -Name $infoItem.Keys -Value ($infoItem.Values -as [string])
                }
                return $infoReturn
            }
            
            '^(config)$' {
                if($options -notcontains 'get|set|unset') {
                    $chocoResult = & $ChocoEXE $command @options
                    
                    $Settings = foreach ($line in $chocoResult) {
                        Select-String -InputObject $line -Pattern "^(\w+) = (\w+|) \|.*"| ForEach-Object {
                            [PSCustomObject]@{
                                "Setting" = $_.matches.groups[1].value
                                "Value" = $_.matches.groups[2].value
                            }
                        }
                    }

                    $Features = foreach ($line in $chocoResult) {
                        Select-String -InputObject $line -Pattern "\[([x ])\] (\w+).*" | ForEach-Object {
                            if($_.matches.groups[1].value -eq "x") {
                                $value = $true
                            }
                            else {
                                $value = $false
                            }
                            [PSCustomObject]@{
                                "Setting" = $_.matches.groups[2].value
                                "Enabled" = $value
                            }
                        }
                    }
                    
                    return [PSCustomObject]@{
                        Settings = $Settings
                        Features = $Features
                    }
                }
                else {
                    & $ChocoEXE $command $options
                }
            }

            '^(feature[s]*)$' {
                if($options -notcontains 'disable|enable') {
                    & $ChocoEXE $command @options | Select-String -Pattern '\[([x ])\] (\w+).*' | ForEach-Object {
                        if($_.matches.groups[1].value -eq "x") {
                            $value = $true
                        }
                        else {
                            $value = $false
                        }
                        [PSCustomObject]@{
                            "Setting" = $_.matches.groups[2].value
                            "Enabled" = $value
                        }
                    }
                }
            }

            '^(pin)$' {
                if($options -notcontains 'add|remove') { # options enthält nicht add oder remove
                    & $ChocoEXE $command @options | Select-String -Pattern '^(.+)\|(.+)' | ForEach-Object {
                        [PSCustomObject]@{
                            packageName = $_.matches.groups[1].value
                            pinnedVersion = $_.matches.groups[2].value
                        }
                    }
                }
                else {
                    & $ChocoEXE $command @options
                }
            }
            Default {
                & $ChocoEXE $command @options
            }
        }
    }
    
    end {
    }
}

function Get-UpdateInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [Object[]]$dtUpdates
    )

    $dtUpdates = @($dtUpdates)
    $SelectedCount = ($dtUpdates | Group-Object -AsHashTable -Property doUpdate).True.Count

    $SelectedText = ""

    if ($dtUpdates.Count -eq 1) {
        $UpdateCountText = "Update"
    } else {
        $UpdateCountText = "Updates"
    }
    
    $SelectedText = "($SelectedCount selected for update)"
    

    if ($dtUpdates.Count -le 0) {
        "No updates available :>"
    } else {
        "$($dtUpdates.Count) $UpdateCountText available $SelectedText; Double-Click a package for more info"
    }
}

function Update-PackageList {
    $script:uiHash.currentAction = "Search"
    Show-Overlay -Text "Searching for updates"

    $dtUpdates.Clear()

    $script:uiHash.window = $window
    $script:uiHash.gOverlay = $gOverlay
    $script:uiHash.spOverlay = $spOverlay
    $script:uiHash.tbOverlay = $tbOverlay
    $script:uiHash.dgUpdates = $dgUpdates
    $script:uiHash.tbOverlayProgress = $tbOverlayProgress
    $script:uiHash.dtUpdates = $dtUpdates
    $script:uiHash.tbInfo = $tbInfo

    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.ApartmentState = "STA"
    $newRunspace.ThreadOptions = "ReuseThread"
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("uiHash",$Script:uiHash)
    $newRunspace.SessionStateProxy.Path.SetLocation($script:projectRootFolder)

    $psCmdUpdateOutdated = [PowerShell]::Create().AddScript({
        $ErrorActionPreference = "Stop"
    
        try {            
            . ".\helpers.ps1"
            
            Write-Logs -Message "Searching for outdated packages" -LogLevel "Info"
            $uiHash.OutdatedPackages = @(Start-Choco -Command "outdated" -Options "--ignore-unfound")
            Write-Logs -Message "$($uiHash.OutdatedPackages.Count) outdated packages found" -LogLevel "Info"
    
            $script:uiHash.window.Dispatcher.Invoke([System.Action] {
                try {
                    foreach ($package in $uiHash.OutdatedPackages) {
                        $script:uiHash.dtUpdates.Rows.Add(@(
                            $true,
                            $package.PackageName,
                            $package.currentVersion,
                            $package.newVersion
                        ))
                    }
    
                    $script:uiHash.tbInfo.Text = Get-UpdateInfo -dtUpdates $uiHash.dtUpdates
                    
                } catch {
                    Write-Logs -Message "Updating list of outdated packages failed with error '$_' on line $($_.InvocationInfo.Line)" -LogLevel "Error"
                } finally {
                    
                    $script:uiHash.currentAction = "None" # This will end the Progress overlay
                    $script:uiHash.spOverlay.Visibility = "Collapsed"
                    $script:uiHash.gOverlay.Visibility = "Collapsed"
                    $script:uiHash.tbInfo.Visibility = "Visible"

                    if ($script:uiHash.dgUpdates.Items.Count -gt 0) {
                        $script:uiHash.dgUpdates.Visibility = "Visible"
                    }
                }
    
            }, "Normal" )            
    
        } catch {
            Write-Logs -Message "Updating outdated packages failed with error '$_' on line $($_.InvocationInfo.Line)" -LogLevel "Error"
        }
    })

    $psCmdUpdateOutdated.Runspace = $newRunspace

    $script:handleSearch = $psCmdUpdateOutdated.BeginInvoke()
}

function Install-Updates {
    $script:uiHash.currentAction = "Install"
    Show-Overlay -Text "Installing updates"

    $script:uiHash.window = $window
    $script:uiHash.gOverlay = $gOverlay
    $script:uiHash.spOverlay = $spOverlay
    $script:uiHash.tbOverlay = $tbOverlay
    $script:uiHash.tbOverlayProgress = $tbOverlayProgress
    $script:uiHash.dtUpdates = $dtUpdates
    $script:uiHash.tbInfo = $tbInfo
    $script:uiHash.currentAction = $script:currentAction

    $newRunspace = [runspacefactory]::CreateRunspace()
    $newRunspace.ApartmentState = "STA"
    $newRunspace.ThreadOptions = "ReuseThread"
    $newRunspace.Open()
    $newRunspace.SessionStateProxy.SetVariable("uiHash",$Script:uiHash)
    $newRunspace.SessionStateProxy.Path.SetLocation($script:projectRootFolder)

    $psCmdInstallUpdates = [PowerShell]::Create().AddScript({
        $ErrorActionPreference = "Stop"
    
        try {        
            . ".\helpers.ps1"
    
            Write-Logs -Message "Installing packages" -LogLevel "Info"
    
            $PackageList = ($uiHash.dtUpdates | Group-Object -AsHashTable -Property doUpdate).True.PackageName

            Write-Logs -Message "Silent state: $($uiHash.Options.Silent)" -LogLevel "Debug"
            Write-Logs -Message "Hidden state: $($uiHash.Options.Hidden)" -LogLevel "Debug"
            Write-Logs -Message "WhatIf state: $($uiHash.Options.WhatIf)" -LogLevel "Debug"
    
            $ArgumentList = @("upgrade")

            if ( $uiHash.Options.Silent -or $uiHash.Options.Hidden) {
                $ArgumentList += @("-y")
            }
            if ( $uiHash.Options.WhatIf ) {
                $ArgumentList += @("--noop")
            }
            $ArgumentList += $PackageList

            $ProcessSplat = @{
                FilePath = "choco"
                ArgumentList = $ArgumentList -join ' '
                Wait = $True
                PassThru = $True
                Verb = "RunAs"
            }
            if ( $uiHash.Options.Hidden) {
                $ProcessSplat.WindowStyle = "Hidden"
            }

            Start-Process @ProcessSplat
    
            Write-Logs -Message "Installing packages finished" -LogLevel "Info"
    
            $script:uiHash.window.Dispatcher.Invoke( [System.Action] {
                $script:uiHash.currentAction = "AfterInstall"
                $script:uiHash.spOverlay.Visibility = "Collapsed"
                $script:uiHash.gOverlay.Visibility = "Collapsed"
            }, "Normal" )
    
        } catch {
            Write-Logs -Message "Installing chocolatey packages failed with error '$_' on line $($_.InvocationInfo.Line)" -LogLevel "Error"
        }
    })

    $psCmdInstallUpdates.Runspace = $newRunspace

    $script:handleInstall = $psCmdInstallUpdates.BeginInvoke()
}

function Show-Overlay {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $True)]
        [String]$Text
    )

    $tbOverlay.Text = $Text

    if ($gOverlay.IsVisible -eq $False) { # do not start the overlay process again. instead just update the text
        $gOverlay.Visibility = "Visible"
        $spOverlay.Visibility = "Visible"
        $dgUpdates.Visibility = "Collapsed"
        $tbInfo.Visibility = "Collapsed"

        $progressRunspace = [runspacefactory]::CreateRunspace()
        $progressRunspace.ApartmentState = "STA"
        $progressRunspace.ThreadOptions = "ReuseThread"          
        $progressRunspace.Open()
        $progressRunspace.SessionStateProxy.SetVariable("uiHash",$Script:uiHash)
        $progressRunspace.SessionStateProxy.Path.SetLocation($script:projectRootFolder)

        $psCmdProgress = [PowerShell]::Create().AddScript({
            $ErrorActionPreference = "Stop"
        
            try {
                
                . ".\helpers.ps1"
        
                while ($uiHash.currentAction -ne "None") {
                    Start-Sleep -Milliseconds 500
        
                    $script:uiHash.window.Dispatcher.Invoke([System.Action] {
                        switch($uiHash.tbOverlayProgress.Text) {
                            "" {
                                $uiHash.tbOverlayProgress.Text = "." 
                            }
                            "." {
                                $uiHash.tbOverlayProgress.Text = ".." 
                            }
                            ".." {
                                $uiHash.tbOverlayProgress.Text = "..." 
                            }
                            "..." {
                                $uiHash.tbOverlayProgress.Text = "" 
                            }
                            default {
                                $uiHash.tbOverlayProgress.Text = "."
                            }
                        }
        
                    }, "Normal" )
                }
            } catch {
                Write-Logs -Message "Updating search progress failed with error '$_' on line $($_.InvocationInfo.Line)" -LogLevel "Error"
            }
        })

        $psCmdProgress.Runspace = $progressRunspace
        $script:handleProgress = $psCmdProgress.BeginInvoke()
    }
}

function Test-ChocolateyInstall {
    [CmdletBinding()]
    [OutputType([boolean])]

    # Just doing a lazy check here. If it is not found in $PATH it won't work anyway

    $choco = Get-Command -Name choco -CommandType Application -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source
    
    if ( $null -eq $choco -or [String]::IsNullOrWhiteSpace($choco) ) { # choco not found
        return $false
    } else { # choco found
        return $true
    }
}

function Test-Settings {
    [CmdletBinding()]
    param (
        [Parameter(
            Mandatory = $False
        )]
        [PSCustomObject]
        $settings
    )

    begin {
        if ($null -eq $settings) {
            $settings = [PSCustomObject]@{}
        }
    }

    process {
        if ( !($settings.choco_options) ) {
            $ChocoOptionsTree = [PSCustomObject]@{
                silent = $False
                hidden = $False
                whatIf = $False
            }
            $settings | Add-Member -NotePropertyName "choco_options" -NotePropertyValue $ChocoOptionsTree
        } else {
            if ( !($settings.choco_options.psobject.Properties.name -contains "silent") ) { $settings.choco_options | Add-Member -NotePropertyName "silent" -NotePropertyValue $False}
            if ( !($settings.choco_options.psobject.Properties.name -contains "hidden") ) { $settings.choco_options | Add-Member -NotePropertyName "hidden" -NotePropertyValue $False}
            if ( !($settings.choco_options.psobject.Properties.name -contains "whatIf") ) { $settings.choco_options | Add-Member -NotePropertyName "whatIf" -NotePropertyValue $False}
        }

        if ( !($settings.general) ) {
            $generalTree = [PSCustomObject]@{
                checkVersionOnStartup = $true
                ignoreStartUpChecks = $false
            }
            $settings | Add-Member -NotePropertyName "general" -NotePropertyValue $generalTree
        } else {
            if ( !($settings.general.psobject.Properties.name -contains "checkVersionOnStartup") ) { $settings.general | Add-Member -NotePropertyName "checkVersionOnStartup" -NotePropertyValue $true }
            if ( !($settings.general.psobject.Properties.name -contains "ignoreStartUpChecks") ) { $settings.general | Add-Member -NotePropertyName "ignoreStartUpChecks" -NotePropertyValue $true }
        }

        $settings
    }
}
