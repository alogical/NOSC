param([string]$InputHash)

Add-Type -AssemblyName System.Windows.Forms

if ([String]::IsNullOrEmpty($InputHash)) {
    $InputHash = Read-Host "MD5"
}

# Remove any incidental whitespace in the hash string that may have been
# introduced during the user copy & paste operations.
$InputHash = $InputHash -replace '\s*',''

function Get-SecureHashProvider {
    $provider = New-Object System.Security.Cryptography.MD5CryptoServiceProvider

    if (!$provider) {
        return
    }

    Add-Member -InputObject $provider -MemberType ScriptMethod -Name HashFile -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.FileInfo]
                $File
        )
        $reader = [System.IO.StreamReader]$File.FullName
        [void] $this.ComputeHash( $reader.BaseStream )

        $reader.Close()

        return $this.OutString
    }

    Add-Member -InputObject $provider -MemberType ScriptMethod -Name HashString -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $InputString
        )

        $buffer = [System.Text.UnicodeEncoding]::UTF8.GetBytes($InputString)
        $this.ComputeHash($buffer)

        return $this.OutString
    }

    Add-Member -InputObject $provider -MemberType ScriptProperty -Name OutString -Value {
        $hash = $this.Hash | %{"{0:x2}" -f $_}
        return ($hash -join "")
    }

    return $provider
}

$Dialog = New-Object System.Windows.Forms.OpenFileDialog
    
<# Fix for dialog script hang bug #>
$Dialog.ShowHelp = $false
        
# Dialog Configuration
$Dialog.Filter = "All Files (*.*)|*.*"
$Dialog.Multiselect = $false
        
# Run Selection Dialog
if($($Dialog.ShowDialog()) -eq "OK") {
    $f = Get-Item $Dialog.FileName
}
else {
    return $false
}

$md5 = Get-SecureHashProvider

if (!$md5) {
    return $false
}

$CompareHash = $md5.HashFile($f)

if ($CompareHash -eq $InputHash) {
    Write-Host ("MATCH SUCCESS File://{0}`n`t[{1}]`n`t[{2}]" -f $f.Name, $CompareHash, $InputHash) -ForegroundColor Green
    return $true
}
else {
    Write-Host ("MATCH FAILURE File://{0}`n`t[{1}]`n`t[{2}]" -f $f.Name, $CompareHash, $InputHash) -ForegroundColor Red
    return $false
}