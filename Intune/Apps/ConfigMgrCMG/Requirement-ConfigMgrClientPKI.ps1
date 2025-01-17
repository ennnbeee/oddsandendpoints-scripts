$ready = 0
$certCA = 'CN=ennbee-LAB-CA, DC=ennbee, DC=local' #Certificate Authority Name
$date = Get-Date #Used for checking valid certificate
$certPath = 'cert:\LocalMachine\My'
$certs = Get-ChildItem -Path $certPath

foreach ($cert in $certs) {

    $certThumbPath = $certPath + "\$($cert.Thumbprint)"
    if ($cert.Issuer -eq $certCA -and $cert.Extensions.EnhancedKeyUsages.FriendlyName -contains 'Client Authentication') {

        $certValid = Get-ChildItem -Path $certThumbPath | Select-Object NotAfter, NotBefore
        if ($date -gt $certValid.NotBefore -and $date -lt $certValid.NotAfter) {

            $ready++
        }
    }
}

if ($ready -gt 0) {
    Write-Output Ready
}
