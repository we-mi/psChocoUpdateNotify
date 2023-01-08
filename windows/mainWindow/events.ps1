$window.Add_Loaded({

    $imgLogo.Source = (Join-Path $script:projectRootFolder "Images\icon_256.png")
    $imgSearch.Source = (Join-Path $script:projectRootFolder "Images\Search.png")
    $imgUpdate.Source = (Join-Path $script:projectRootFolder "Images\Update.png")
    $imgHelp.Source = (Join-Path $script:projectRootFolder "Images\Help.png")
    $imgUpdateAvail.Source = (Join-Path $script:projectRootFolder "Images\Information.png")

    # This is the icon in the upper left hand corner of the app
    $this.Icon = (Join-Path $script:projectRootFolder "Images\icon_256.png")

    # This is the toolbar icon and description
    $this.TaskbarItemInfo.Overlay = (Join-Path $script:projectRootFolder "Images\icon_256.png")
    $this.TaskbarItemInfo.Description = $window.this

    # initialize dataTable
    $script:dtUpdates = new-Object System.Data.DataTable
    [void]$dtUpdates.Columns.Add("DoUpdate") 
    [void]$dtUpdates.Columns.Add("PackageName") 
    [void]$dtUpdates.Columns.Add("CurrentVersion")
    [void]$dtUpdates.Columns.Add("UpdateVersion")
    $dgUpdates.ItemsSource = $dtUpdates.DefaultView
    $dtUpdates.DefaultView.RowFilter = ""

    [System.Windows.RoutedEventHandler]$ClickHandler = {
        $tbInfo.Text = Get-UpdateInfo -dtUpdates $dtUpdates
    }

    if ($SkipGUIInitialSearch.IsPresent -eq $False) {
        $dgUpdates.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $ClickHandler)
    }

    $script:uiHash = [hashtable]::Synchronized(@{})
    $script:uiHash.Options = @{
        Silent = $settings.choco_options.silent
        Hidden = $settings.choco_options.hidden
        WhatIf = $settings.choco_options.whatIf
    }

    $script:uiHash.gui = @{
        mainWindow = $window
    }

    $cbSilent.IsChecked = $script:uiHash.Options.Silent
    $cbHidden.IsChecked = $script:uiHash.Options.Hidden
    $cbWhatIf.IsChecked = $script:uiHash.Options.WhatIf

    $window.Title = "psChocoUpdateNotify - v$($script:version)"

    if (Test-ChocolateyInstall) {
        $script:ChocolateyInstalled = $True
    } else {
        $dgUpdates.Visibility = "Collapsed"
        $bControlSearch.IsEnabled = $False
        $bControlUpdate.IsEnabled = $False
        $cbSilent.IsEnabled = $False
        $cbHidden.IsEnabled = $False
        $cbWhatIf.IsEnabled = $False

        $tbInfo.Visibility = "Visible"
        $bChocoPage.Visibility = "Visible"
        $tbInfo.Text = "Chocolatey was not found on your system.`nYou can install it by visiting chocolatey.org and follow the instructions"

        $script:ChocolateyInstalled = $False
    }

    if ($settings.updater.checkVersionOnStartup -ne $False) {
        $GitHubVersion = Test-Version
        if ($null -ne $GitHubVersion ) {
            $bUpdateAvail.Parent.Visibility = "Visible"
            $bUpdateAvail.Tooltip = "New version '$($GitHubVersion.ToString())' is available"
        }
    }
})

$window.Add_ContentRendered({
    if ($script:ChocolateyInstalled -and $SkipGUIInitialSearch.IsPresent -eq $False) {
        Update-PackageList
    }
})

$bControlSearch.Add_Click({
    Update-PackageList
})

$bControlUpdate.Add_Click({
    Install-Updates
})

$gOverlay.Add_IsVisibleChanged({
    # use this for triggering certain functions depending on the current action

    switch ($gOverlay.Visibility) {
        "Visible" { # action is starting

        }

        "Collapsed" { # action has finished
            switch ($script:uiHash.currentAction) {
                "AfterInstall" { # Install the updates has finished. Trigger a second search
                    Update-PackageList
                }
            }
        }
    }
})

$cbSilent.Add_Click({
    $script:uiHash.Options.Silent = $this.IsChecked
    $settings.choco_options.silent = $this.IsChecked
})

$cbHidden.Add_Click({
    $script:uiHash.Options.Hidden = $this.IsChecked
    $settings.choco_options.hidden = $this.IsChecked
})

$cbWhatIf.Add_Click({
    $script:uiHash.Options.WhatIf = $this.IsChecked
    $settings.choco_options.whatIf = $this.IsChecked
})

$dgUpdates.Add_MouseDoubleClick({
    if ($dgUpdates.SelectedItems.Count -eq 1) {

        # Load assembly for the markdown renderer
        Add-Type -Path (Join-Path $script:projectRootFolder "res\dll\net5.0-windows7.0\MdXaml.dll")
        Add-Type -Path (Join-Path $script:projectRootFolder "res\dll\net6.0-windows7.0\ICSharpCode.AvalonEdit.dll")
        Add-Type -Path (Join-Path $script:projectRootFolder "res\dll\net5.0-windows7.0\MdXaml.Plugins.dll")

        # Load XAML File
        Write-Logs -Message "Loading xml for packageDetails (window.xaml)" -Loglevel "debug"
        try {
            $xaml = [xml](Get-Content (Join-Path $script:projectRootFolder "windows\packageDetails\window.xaml") -ErrorAction Stop)
            $packageDetailsWindow = [Windows.Markup.XamlReader]::Load( (New-Object System.Xml.XmlNodeReader $xaml) )
        } catch [System.Management.Automation.RuntimeException] {
            if ($_.CategoryInfo.Reason -eq "RuntimeException") { # file could not be parsed as a xml
                Write-Logs -Message "XAML-File could not be parsed as a xml file. Check the XAMl-Content" -Loglevel "error"
                return 1
            } elseif ($_.CategoryInfo.Reason -eq "MethodInvocationException") { # Xml could not be loaded by XamlReader
                Write-Logs -Message "XAML-Content could not be loaded by XamlReader-Object. Check the XAMl-Content" -Loglevel "error"
                return 1
            } elseif ($_.CategoryInfo.Reason -eq "ItemNotFoundException") {
                Write-Logs -Message "XAML-File was not found" -Loglevel "error"
                return 1
            }
        } catch  {
            Write-Logs -Message "Other error while reading and parsing the XAML-File ($($_.Exception))" -Loglevel "error"
            return 1
        }

        # Find Window Objects
        Write-Logs -Message "Converting elements to variables for packageDetailsWindow" -Loglevel "debug"
        foreach ($node in $xaml.SelectNodes("//*[@*[contains(translate(name(.),'n','N'),'Name')]]")){ 
            New-Variable -Name $node.Name -Value $packageDetailsWindow.FindName($node.Name) -Force -Scope "Script"
        }

        # Load events for the main window
        Write-Logs -Message "Load events-file for packageDetailsWindow" -Loglevel "debug"
        try {
            . (Join-Path $script:projectRootFolder "windows\packageDetails\events.ps1")
        } catch {
            Write-Logs -Message "Could not load events file for packageDetailsWindow ($($_.Exception))" -Loglevel "error"
            return 1
        }

        $script:uiHash.gui.packageDetailsWindow = $packageDetailsWindow

        # Show the main window
        Write-Logs -Message "Displaying packageDetailsWindow" -Loglevel "debug"
        $lPackageID.Content = $dgUpdates.SelectedItem.PackageName
        #$lPackageID.Content = "firefox"
        $lPackageVersion.Content = $dgUpdates.SelectedItem.UpdateVersion
        #$lPackageVersion.Content = "108.0.1"

        try {
            [void]$packageDetailsWindow.ShowDialog()
        } catch {
            Write-Logs -Message "Error while running packageDetailsWindow ($($_.Exception))" -Loglevel "error"
            return 1
        }
    }
})

$bHelp.Add_Click({
    Start-Process 'https://github.com/we-mi/psChocoUpdateNotify'
})

$cbUpdateAll.Add_Checked({
    $dtUpdates | ForEach-Object {
        $_.DoUpdate = $True
    }
})

$cbUpdateAll.Add_Unchecked({
    $dtUpdates | ForEach-Object {
        $_.DoUpdate = $False
    }
})

$bChocoPage.Add_Click({
    Start-Process 'https://chocolatey.org/install'
})

$bUpdateAvail.Add_Click({
    $answer = [System.Windows.Forms.MessageBox]::Show("Would you like to be redirected to the GitHub-Releases page?`n`nPlease also consult the Readme for this project in the root folder and how to update this program.", "New version available","YesNo","Information")

    if ($answer -eq "Yes") {
        Start-Process 'https://github.com/we-mi/psChocoUpdateNotify/releases'
    }
})
