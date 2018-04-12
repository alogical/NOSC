## Network Device Scan Cache Reader ##
param($path)
$json = (Get-Content $path) -join ""
$cache = ConvertFrom-Json $json

Write-Host "$path has been parsed into the global: `$cache"