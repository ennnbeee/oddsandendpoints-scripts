# Reads values from the module manifest file
$manifestData = Import-PowerShellDataFile -Path $PSScriptRoot\Intune-prototype-WindowsMDMFirewallRulesMigrationTool.psd1

#Installing dependencies if not already installed [Microsoft.Graph] and [ImportExcel] from the powershell gallery
$graphVersionBad = '2.26.1'
$graphVersionGood = '2.24.0'
$graphModules = Get-InstalledModule Microsoft.Graph.Authentication -ErrorAction ignore
$excelModules = Get-InstalledModule ImportExcel -ErrorAction ignore

#updated to support issues with Microsoft.Graph.Authentication 2.26.1 on PS 5
if ($PSVersionTable.PSVersion.Major -eq 5) {
    if ($graphModules.Version -contains $graphVersionBad) {
        Uninstall-Module Microsoft.Graph.Authentication -RequiredVersion $graphVersionBad -Force -ErrorAction Stop
    }
    if (!($graphModules.Version -contains $graphVersionGood)) {
        Write-Host 'Installing Microsoft.Graph.Authentication from Powershell Gallery...'
        Try {
            Install-Module Microsoft.Graph.Authentication -RequiredVersion $graphVersionGood -AllowClobber -Scope AllUsers -Force
        }
        Catch {
            Write-Error "Microsoft.Graph.Authentication was not installed successfully... `r`n$_"
            Break
        }
    }
}
else {
    if (-not($graphModules)) {
        Write-Host 'Installing Microsoft.Graph.Authentication from Powershell Gallery...'
        try {
            Install-Module Microsoft.Graph.Authentication -AllowClobber -Scope AllUsers -Force
        }
        Catch {
            Write-Error "Microsoft.Graph.Authentication was not installed successfully... `r`n$_"
            Break
        }
    }
}

if (-not($excelModules)) {
    Write-Host 'Installing ImportExcel Module from Powershell Gallery...'
    try {
        Install-Module ImportExcel -Force
    }
    catch {
        Write-Host "ImportExcel Module Powershell was not installed successfully... `r`n$_"
    }
}
# Ensure required modules are imported
ForEach ($module in $manifestData['RequiredModules']) {
    If (!(Get-Module $module)) {
        # Setting to stop will cause a terminating error if the module is not installed on the system
        Import-Module $module -ErrorAction Stop
    }
}

# Port all functions and classes into this module
$Public = @( Get-ChildItem -Path $PSScriptRoot\IntuneFirewallRulesMigration\Public\*.ps1 -ErrorAction SilentlyContinue -Recurse )

# Load each public function into the module
ForEach ($import in @($Public)) {
    Try {
        . $import.fullname
    }
    Catch {
        Write-Error -Message "Failed to import function $($import.fullname): $_"
    }
}

# Exports the cmdlets provided in the module manifest file, other members are not exported
# from the module
ForEach ($cmdlet in $manifestData['CmdletsToExport']) {
    Export-ModuleMember -Function $cmdlet
}