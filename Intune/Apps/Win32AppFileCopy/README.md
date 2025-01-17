# Win32 App File Copy Scripts

Template for the copying of files/folders using a Win32 App in Microsoft Intune.

## Configuration

- Update the `$contentName` variable in both scripts giving the content name a description, avoid spaces as the variable is used for log files.
- Update the `$contentVersion` variable in the **Install.ps1** script, this is used to create a **tag** file for detection rules.
- Update the `$targetFolder` variable with the folder that the content is being deployed to, it will create the folder with the installation, and delete it with the uninstallation.
- The `$logFile` variable stores the logs in the IntuneManagementExtension folder so can be captured by diagnostics settings.

## Deployment

| Item | Detail |
| - | - |
| Install command | "%systemroot%\sysnative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File Install.ps1 |
| Uninstall command | "%systemroot%\sysnative\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -File Uninstall.ps1 |

## Detection Rules

| Item | Detail |
| - | - |
| Rules format | Manually configure detection rules |
| Rule type | File |
| Path | Path used in the `$targetFolder` variable |
| File or folder | The output of the `$contentTag` variable |
| Detection method | File or folder exists |
| Associated with a 32-bit app on 64-bit clients | No |
