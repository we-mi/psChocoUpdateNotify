$window.Add_Loaded({

    $imgLogo.Source = (Join-Path $script:projectRootFolder "Images\icon_256.png")
    $imgSearch.Source = (Join-Path $script:projectRootFolder "Images\Search.png")
    $imgUpdate.Source = (Join-Path $script:projectRootFolder "Images\Update.png")
    $imgHelp.Source = (Join-Path $script:projectRootFolder "Images\Help.png")

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

    $dgUpdates.AddHandler([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent, $ClickHandler)

    $script:uiHash = [hashtable]::Synchronized(@{})
    $script:uiHash.Options = @{
        Silent = $False
        Hidden = $False
        WhatIf = $False
    }

    $cbSilent.IsChecked = $script:uiHash.Options.Silent
    $cbHidden.IsChecked = $script:uiHash.Options.Hidden
    $cbWhatIf.IsChecked = $script:uiHash.Options.WhatIf

    $window.Title = "psChocoUpdateNotify - v$($script:version)"
})

$window.Add_ContentRendered({
    Update-PackageList
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
})

$cbHidden.Add_Click({
    $script:uiHash.Options.Hidden = $this.IsChecked
})

$cbWhatIf.Add_Click({
    $script:uiHash.Options.WhatIf = $this.IsChecked
})

$bHelp.Add_Click({
    Start-Process 'https://github.com/we-mi/psChocoUpdateNotify'
})
