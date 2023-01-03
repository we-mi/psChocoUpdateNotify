$packageDetailsWindow.Add_Loaded({
    # This is the icon in the upper left hand corner of the app
    $this.Icon = (Join-Path $script:projectRootFolder "Images\icon_256.png")

    # This is the toolbar icon and description
    $this.TaskbarItemInfo.Overlay = (Join-Path $script:projectRootFolder "Images\icon_256.png")
    $this.TaskbarItemInfo.Description = $window.this

    $imgLogo.Source = (Join-Path $script:projectRootFolder "Images\icon_256.png")

    $gPackageDetailsOverlay.Visibility="Visible"
})

$packageDetailsWindow.Add_ContentRendered({

    $ProgressPreference = "SilentlyContinue"
    $urlRegEx = '^https?:\/\/(www\.)?[-a-zA-Z0-9@:%._\+~#=]{1,256}\.[a-zA-Z0-9()]{1,6}\b([-a-zA-Z0-9()@:%_\+.~#?&\/\/=]*)'


    $Results = @()
    [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

    # Loop through every chocolatey source
    $sources = Start-Choco -command "source" | Where-Object { $_.Enabled -eq $True }

    foreach ($source in $sources) {
        $url = "$($source.Url)/Packages()?`$filter=( (Id eq '$($lPackageID.Content)') and (Version eq '$($lPackageVersion.Content)') )"
        $WebResult = [array](Invoke-RestMethod -UseBasicParsing -Uri $url -ErrorAction SilentlyContinue -TimeoutSec 5)
        foreach ($package in $WebResult) {
            if ($package -is [System.Xml.XMLElement]) {
                try {
                    $package.properties.SetAttribute("Repository", $source.SourceName)
                } catch {
                    Write-Warning "Could not add repository to package information"
                }
            }
        }
        $Results += $WebResult
    }

    if ($Results.Count -gt 1) {
        [System.Windows.Forms.MessageBox]::Show("More than one package of '$($lPackageID.Content)' version '$($lPackageVersion.Content)' was found, maybe due to multiple repositories. `nOnly the first package is shown here", "Multiple packages", "OK","Information")
    } elseif ($Results.Count -eq 1) {

        $Result = $Results[0]

        if ($Result -is [System.Xml.XMLElement]) {
            $lPackageRepo.Content = $result.properties.Repository
            $tbPackageTitle.Text = $result.properties.Title
            $tbPackageAuthors.Text = $result.Author.name
            $tbLastUpdated.Text = $result.updated

            if ($result.properties.ProjectUrl -match $urlRegEx) {
                $hProjectUrl.NavigateUri = $hProjectUrl.Tooltip = $tbProjectUrl.Text = $result.properties.ProjectUrl
                $hProjectUrl.Add_Click({ Start-Process $this.NavigateUri })
            } else {
                $hProjectUrl.IsEnabled = $tbProjectUrl.IsENabled = $False
                $tbProjectUrl.Text = "N/A"
                $hProjectUrl.Cursor = $null
            }

            if ($result.properties.ProjectSourceUrl -match $urlRegEx) {
                $hProjectSourceUrl.NavigateUri = $hProjectSourceUrl.Tooltip = $tbProjectSourceUrl.Text = $result.properties.ProjectSourceUrl
                $hProjectSourceUrl.Add_Click({ Start-Process $this.NavigateUri })
            } else {
                $hProjectSourceUrl.IsEnabled = $tbProjectSourceUrl.IsENabled = $False
                $tbProjectSourceUrl.Text = "N/A"
                $hProjectSourceUrl.Cursor = $null
            }

            if ($result.properties.IconUrl -match $urlRegEx) {
                $hIconUrl.NavigateUri = $hIconUrl.Tooltip = $tbIconUrl.Text = $result.properties.IconUrl
                $hIconUrl.Add_Click({ Start-Process $this.NavigateUri })

                if ($result.properties.IconUrl -like "*.png" -or 
                    $result.properties.IconUrl -like "*.jpg" -or
                    $result.properties.IconUrl -like "*.jpeg") {
                    $imgLogo.Source = $result.properties.IconUrl
                } else {
                    (Join-Path $script:projectRootFolder "Images\icon_256.png")
                }
            } else {
                $hIconUrl.IsEnabled = $tbIconUrl.IsENabled = $False
                $tbIconUrl.Text = "N/A"
                $hIconUrl.Cursor = $null
            }

            if ($result.properties.LicenseUrl -match $urlRegEx) {
                $hLicenseUrl.NavigateUri = $hLicenseUrl.Tooltip = $tbLicenseUrl.Text = $result.properties.LicenseUrl
                $hLicenseUrl.Add_Click({ Start-Process $this.NavigateUri })
            } else {
                $hLicenseUrl.IsEnabled = $tbLicenseUrl.IsENabled = $False
                $tbLicenseUrl.Text = "N/A"
                $hLicenseUrl.Cursor = $null
            }

            if ($result.properties.DocsUrl -match $urlRegEx) {
                $hDocsUrl.NavigateUri = $hDocsUrl.Tooltip = $tbDocsUrl.Text = $result.properties.DocsUrl
                $hDocsUrl.Add_Click({ Start-Process $this.NavigateUri })
            } else {
                $hDocsUrl.IsEnabled = $tbDocsUrl.IsENabled = $False
                $tbDocsUrl.Text = "N/A"
                $hDocsUrl.Cursor = $null
            }

            if ($result.properties.MailingListUrl -match $urlRegEx) {
                $hMailingListUrl.NavigateUri = $hMailingListUrl.Tooltip = $tbMailingListUrl.Text = $result.properties.MailingListUrl
                $hMailingListUrl.Add_Click({ Start-Process $this.NavigateUri })
            } else {
                $hMailingListUrl.IsEnabled = $tbMailingListUrl.IsENabled = $False
                $tbMailingListUrl.Text = "N/A"
                $hMailingListUrl.Cursor = $null
            }

            if ($result.properties.BugTrackerUrl -match $urlRegEx) {
                $hBugTrackerUrl.NavigateUri = $hBugTrackerUrl.Tooltip = $tbBugTrackerUrl.Text = $result.properties.BugTrackerUrl
                $hBugTrackerUrl.Add_Click({ Start-Process $this.NavigateUri })
            } else {
                $hBugTrackerUrl.IsEnabled = $tbBugTrackerUrl.IsENabled = $False
                $tbBugTrackerUrl.Text = "N/A"
                $hBugTrackerUrl.Cursor = $null
            }

            if ($result.properties.ReleaseNotes -match $urlRegEx) {
                $hReleaseNotes.NavigateUri = $hReleaseNotes.Tooltip = $tbReleaseNotes.Text = $result.properties.ReleaseNotes
                $hReleaseNotes.Add_Click({ Start-Process $this.NavigateUri })
            } else {
                $hReleaseNotes.IsEnabled = $tbReleaseNotes.IsENabled = $False
                $tbReleaseNotes.Text = "N/A"
                $hReleaseNotes.Cursor = $null
            }

            $tbCopyright.Text = $result.properties.Copyright

            $tbTags.Text = $result.properties.Tags.'#text'
            $tbDependencies.Text = $result.properties.Dependencies
            $cbRequireLicenseAcceptance.IsChecked = [bool]$result.properties.RequireLicenseAcceptance.'#text'

            $tbSummary.Text = $result.summary.'#text'
            $tbDescription.Text = $result.properties.Description
        }
    } else {
        [System.Windows.Forms.MessageBox]::Show("No package with the name '$($lPackageID.Content)' and version '$($lPackageVersion.Content)' was found. This should not have happened oO", "No package information found", "OK","Error")
    }

    $gPackageDetailsOverlay.Visibility = "Hidden"

})

$gPackageDetailsOverlay.Add_IsVisibleChanged({
    # use this for triggering certain functions depending on the current action

    switch ($this.Visibility) {
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