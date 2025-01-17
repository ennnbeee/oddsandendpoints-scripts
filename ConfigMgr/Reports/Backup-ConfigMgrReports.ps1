#note this is tested on PowerShell v2 and SSRS 2008 R2
[void][System.Reflection.Assembly]::LoadWithPartialName('System.Xml.XmlDocument');
[void][System.Reflection.Assembly]::LoadWithPartialName('System.IO');

#$ReportServerUri = 'http://yourreportserver/ReportServer/ReportService2005.asmx';

$ReportServerUri = Read-Host 'Please provide the Report Server URL i.e. http://yourreportserver/ReportServer/ReportService2005.asmx'

$Proxy = New-WebServiceProxy -Uri $ReportServerUri -Namespace SSRS.ReportingService2005 -UseDefaultCredential ;

#create a timestamped folder, format similar to 2011-Mar-28-0850PM
$Folder = Read-Host 'Please provide a folder path for the reports to be saved to i.e. C:\Temp\Reports\'
$folderName = Get-Date -Format 'yyyy-MMM-dd-hhmmtt';
$fullFolderName = $Folder + $folderName;

#check out all members of $Proxy
#$Proxy | Get-Member
#http://msdn.microsoft.com/en-us/library/aa225878(v=SQL.80).aspx

#second parameter means recursive
$items = $Proxy.ListChildren('/', $true) | `
    Select-Object Type, Path, ID, Name | `
    Where-Object { $_.type -eq 'Report' };

#create a new folder where we will save the files
#PowerShell datetime format codes http://technet.microsoft.com/en-us/library/ee692801.aspx


[System.IO.Directory]::CreateDirectory($fullFolderName) | Out-Null

foreach ($item in $items) {
    #need to figure out if it has a folder name
    $subfolderName = Split-Path $item.Path;
    $reportName = Split-Path $item.Path -Leaf;
    $fullSubfolderName = $fullFolderName + $subfolderName;
    if (-not(Test-Path $fullSubfolderName)) {
        #note this will create the full folder hierarchy
        [System.IO.Directory]::CreateDirectory($fullSubfolderName) | Out-Null
    }

    $rdlFile = New-Object System.Xml.XmlDocument;
    [byte[]] $reportDefinition = $null;
    $reportDefinition = $Proxy.GetReportDefinition($item.Path);

    #note here we're forcing the actual definition to be
    #stored as a byte array
    #if you take out the @() from the MemoryStream constructor, you'll
    #get an error
    [System.IO.MemoryStream] $memStream = New-Object System.IO.MemoryStream(@(, $reportDefinition));
    $rdlFile.Load($memStream);

    $fullReportFileName = $fullSubfolderName + '\' + $item.Name + '.rdl';
    #Write-Host $fullReportFileName;
    $rdlFile.Save( $fullReportFileName);

}