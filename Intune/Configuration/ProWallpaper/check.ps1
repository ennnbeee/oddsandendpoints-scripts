$packageName = "CompanyBranding"
$packageVersion = 1

$currentProgramVersion = Get-Content -Path "C:\ProgramData\scloud\Validation\$packageName"

if($currentProgramVersion -eq $packageVersion){
    Write-Host "Found it!"
}