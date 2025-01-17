# Remove Built-In Windows Apps

Removes the consumer and non-business oriented apps from Windows 10 and later devices based on values in an array `$removeApps`, this allows for the use of `*` as a wildcard for searching for apps.

Update the array to include additional apps, or comment out apps that the customer wants to keep.

Log file stored in `env:ProgramData\Microsoft\IntuneManagementExtension\Logs\RemoveBuiltInApps.log`

## Deployment

| Item | Setting |
| - | - |
| Run this script using the logged on credentials | No |
| Enforce script signature check | No |
| Run script in 64 bit PowerShell Host | No |

## Assignment

| Assignment Type | Assignment Target |
| - | - |
| Included groups | All Windows Autopilot Devices |
| Excluded groups | n/a |
