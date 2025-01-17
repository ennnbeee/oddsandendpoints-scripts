#Specify your site server and sitecode:
$siteCode = 'ENB' # Site code
$providerMachineName = 'LAB-SCCM.ennbee.local'
$installPath = 'C:\Program Files (x86)\Microsoft Configuration Manager'

#import assemblies
[System.Reflection.Assembly]::LoadFrom("$installPath\AdminConsole\bin\Microsoft.ConfigurationManagement.ApplicationManagement.dll")
[System.Reflection.Assembly]::LoadFrom("$installPath\AdminConsole\bin\Microsoft.ConfigurationManagement.ApplicationManagement.Extender.dll")
[System.Reflection.Assembly]::LoadFrom("$installPath\AdminConsole\bin\Microsoft.ConfigurationManagement.ApplicationManagement.MsiInstaller.dll")


# Update package options
Get-CMPackageDeployment | ForEach-Object {
    Write-Host "Updating deployment options for $($_.ProgramName) " -ForegroundColor Cyan
    Set-CMPackageDeployment -InputObject $_ -StandardProgramName $_.ProgramName -FastNetworkOption DownloadContentFromDistributionPointAndRunLocally -SlowNetworkOption DownloadContentFromDistributionPointAndLocally
    Write-Host "Updated deployment options for $($_.ProgramName) " -ForegroundColor Green
}


# Update application options
$applications = gwmi -ComputerName $providerMachineName -Namespace root\sms\site_$siteCode -class sms_application | Where-Object { $_.IsLatest -eq $true }

foreach ($application in $applications) {
    #get the instance of the application
    $app = [wmi]$application.__PATH
    Write-Host "Getting deployment types for $($app.LocalizedDisplayName)" -ForegroundColor Magenta
    #deserialize the XML data
    $appXML = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::DeserializeFromString($app.SDMPackageXML, $true)
    #loop through the deployment types
    foreach ($dt in $appXML.DeploymentTypes) {
        #find the installer element of the XML
        $installer = $dt.Installer
        #the content for each installer is stored as an single element array
        $content = $installer.Contents[0]
        if ($content.OnSlowNetwork -ne 'Download') {
            Write-Host "Updating $($dt.Title) deployment type to download from neighbour boundary groups" -ForegroundColor Yellow
            $content.OnSlowNetwork = [Microsoft.ConfigurationManagement.ApplicationManagement.ContentHandlingMode]::Download
            #reserialize the XML
            $updatedXML = [Microsoft.ConfigurationManagement.ApplicationManagement.Serialization.SccmSerializer]::SerializeToString($appXML, $true)
            #add the serialized XML data to the application object
            $app.SDMPackageXML = $updatedXML
            #put the changes to the instance
            $app.Put()
            Write-Host "Updated $($dt.Title) deployment type to download from neighbour boundary groups" -ForegroundColor Green

        }
        else {
            Write-Host "$($dt.Title) Deployment Type already configured to download from neighbour boundary groups" -ForegroundColor Magenta
        }
    }

}
