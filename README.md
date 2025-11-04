Have this file call the installer Install-WinGet.cmd as a start up script.

Then These files as logon and off scripts
installAndUpdateWinGetApps.ps1
updateWinGetAppsEverything.ps1

The first script ideally as a logon script will install and update any specific apps.
The second script ideally as a logoff script as it will install and update many components on the system.
As a security advisory its possible that should another vendors repository be infected - that could be installed.

Also there are some large files that should be added to the installer repository.
https://icthero-my.sharepoint.com/:u:/g/personal/cj_icthero_co_uk/EcqSjwSxvIxCvBarlDVxmogBNjCCxUqTGv8m84YZMLkrhQ?e=IT5m7q
