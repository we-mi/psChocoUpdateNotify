# psChocoUpdateNotify
Searches for chocolatey package updates and notifies the user about it. Includes a GUI where you can choose what to update

## Usage

[Download](https://github.com/we-mi/psChocoUpdateNotify/archive/refs/heads/main.zip) and extract this project, then start the file `psChocoUpdateNotify.ps1`.

Be sure to set your [ExecutionPolicy](https://docs.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_execution_policies) accordingly or this script might not start.

You might want to start this script as a scheduled task at logon.

## Hints

This script will check the existence of two protocol handlers in the registry and create it if they are missing. You need admin privileges for this, but you will need that anyway if you want to update chocolatey packages.

The protocol handlers are called when you click on `Update` or `GUI` in the notification toast.  
You can even call these handlers from within the Windows `Run`-Dialogue with `psChocoUpdateNotifyUpdate:` or `psChocoUpdateNotifyGUI:`

If you move the project folder to any other location, you need to delete or manually change these protocol handlers (See [this](https://github.com/we-mi/psChocoUpdateNotify/issues/1) issue) in the registry. They will get recreated on the next start.

The paths are:

- `HKEY_CLASSES_ROOT\psChocoUpdateNotifyUpdate`
- `HKEY_CLASSES_ROOT\psChocoUpdateNotifyGUI`
