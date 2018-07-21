$x509_store = new-object System.Security.Cryptography.X509Certificates.X509Store("My", `
    [System.Security.Cryptography.X509Certificates.StoreLocation]::CurrentUser)

Try {
    $x509_store.Open([System.Security.Cryptography.X509Certificates.OpenFlags]::OpenExistingOnly)

    ForEach ($cert in $x509_store.Certificates) {
        Write-Host
        Write-Host "Friendly Name:`t$($cert.FriendlyName)"
        Write-Host "Subject:`t$($cert.Subject)"
        Write-Host "Serial:`t0x$($cert.SerialNumber)"
        Write-Host "Valid From:`t$($cert.NotBefore) - $($cert.NotAfter)"
        Write-Host "Issuer:`t$($cert.IssuerName.Name)"
        Write-Host
    }
}

Catch [System.Security.Cryptography.CryptographicException]
    {Write-Host "Could not open CurrentUser store [My]"}
Catch [System.Security.SecurityException]
    {Write-Host "You do not have the required permissions"}
Finally {$x509_store.Close()}