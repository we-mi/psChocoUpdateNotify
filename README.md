# psChocoUpdateNotify

Searches for chocolatey package updates and notifies the user about it. Includes a GUI where you can choose what to update

* [Features](#features)
* [Install](#install)
* [Update](#update)
* [Usage](#usage)
* [Hints](#hints)
* [Credits/Acknowledgements](#creditsacknowledgements)

## Features

* Get notified about outdated chocolatey packages through a windows toast notification on every logon ![Toast](doc/img/Toast.png)
* List all outdated packages in a simple graphical interface  ![GUI](doc/img/GUI.png)
* Install all or a subset of your outdated packages with three different options
  * `Silent`: Don't ask for confirmation when updating chocolatey packages (Choco parameter `-y`)
  * `Hidden`: Don't show the chocolatey window
  * `WhatIf`: Don't make any changes. This is just for testing purposes
* Show detailed information about a package when double-clicking it.  ![PackageDetails](doc/img/PackageDetails.png)

## Install

The first mentioned method is the preferred method.  
The last mentioned method is the least preferred method.

### As a powershell module

Simply run `Install-Module -Name psChocoUpdateNotify -Scope AllUsers` and then start the script with `Start-PSChocoUpdateNotify` in any powershell session.

### Manual

1. Open the [Releases-Page](https://github.com/we-mi/psChocoUpdateNotify/releases) and download the latest Source-Code ZIP-File.
2. Extract the ZIP-File to a destination of your choice.
3. Open the extracted folder, right-click the file `psChocoUpdate-Notify.ps1` and choose `Run with powershell`

### Other

If you know what you're doing you can [Download](https://github.com/we-mi/psChocoUpdateNotify/archive/refs/heads/main.zip) the latest source code and start it the same way as described in the [manual](#manual) method.

## Update

### As a powershell module

This is as simple as running `Update-Module psChocoUpdateNotify`.

You might need to reopen your powershell session or unload the old module with `Remove-Module psChocoUpdateNotify` in order to have powershell use the new module.

### Manual

1. Open the [Releases-Page](https://github.com/we-mi/psChocoUpdateNotify/releases) and download the latest Source-Code ZIP-File.
2. Extract the ZIP-File to a destination of your choice.
   1. You *can* use the same folder and just replace the old files to skip the first start-questions, except something fundamental changed), but you can just use another folder.
3. Open the extracted folder, right-click the file `psChocoUpdate-Notify.ps1` and choose `Run with powershell`

## Usage

Be sure to set your [ExecutionPolicy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies) accordingly or this script might not start.

If you want to start this script in `Notification`-Mode use `psChocoUpdateNotify.ps1 -Mode Notification` or `Start-PSChocoUpdateNotify -Mode Notification` depending on your installation type

You can start the GUI with `psChocoUpdateNotify.ps1 -Mode GUI` or `Start-PSChocoUpdateNotify -Mode GUI`.

`Notification`-Mode is the default Mode.

You can choose to disable the start-up-checks (see Hints below) with `-IgnoreStartUpChecks`. This might be useful if you do not wish to use the protocol handlers or the scheduled task.

## Hints

This script will check the existence of two protocol handlers in the registry and a scheduled task. If they do not exist it will create them. You need admin privileges for this, but you will need that anyway if you want to update chocolatey packages.

The protocol handlers are called when you click on `Update` or `GUI` in the notification toast.  
You can even call these handlers from within the Windows `Run`-Dialogue with `psChocoUpdateNotifyUpdate:` or `psChocoUpdateNotifyGUI:`

The scheduled task is created in `\psChocoUpdateNotify\psChocoUpdateNotify-Logon` and will trigger at every logon.

The script detects if any change of the protocol handlers and the scheduled task happened and will fix them (you will need admin privileges again...)

The path to the protocol handlers are:

- `HKEY_CLASSES_ROOT\psChocoUpdateNotifyUpdate`
- `HKEY_CLASSES_ROOT\psChocoUpdateNotifyGUI`

## Credits/Acknowledgements

The 'hot chocolate' logo in the main window, in the notification-window and in the taskbar was designed by kerismaker and can be found [here](https://www.flaticon.com/free-icons/hot-chocolate).

The following 3rd party components are used in this project

* [MdXaml](https://github.com/whistyun/MdXaml); Released under the [MIT-License](https://github.com/whistyun/MdXaml/blob/master/LICENSE.txt); Used for rendering Markdown-Text
* [AvalonEdit](https://github.com/icsharpcode/AvalonEdit); Released under the [MIT-License](https://github.com/icsharpcode/AvalonEdit/blob/master/LICENSE); Used as a dependency for MdXaml
