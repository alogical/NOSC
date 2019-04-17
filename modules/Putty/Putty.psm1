<#
.SYNOPSIS
    PuTTY configuration and session manager.

.DESCRIPTION
    Controls PuTTY configuration and credentials for establishing SSH sessions
    to network devices.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>

$ModuleInvocationPath  = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

###############################################################################
###############################################################################
## SECTION 01 ## PUBILC FUNCTIONS AND VARIABLES
##
## Pass-thru Export-ModuleMember calls export all functions and variables
## to the global session that were passed to this modules session from nested
## modules.
###############################################################################
###############################################################################

function Initialize-Components {
    param(
        [Parameter(Mandatory = $true)]
            [AllowNull()]
            [System.Windows.Forms.Form]
            $Window,

        [Parameter(Mandatory = $true)]
            [AllowNull()]
            [System.Windows.Forms.Control]
            $Parent,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.MenuStrip]
            $MenuStrip,

        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $OnLoad
    )

    # Register Menus
    [void]$MenuStrip.Items.Add($Menu.Putty.Root)
}

function Open-SSH ($Target) {
    if ($Script:Credential -eq $null) {
        $Script:Credential = Get-Credential
    }

    $profile = Set-RegistryProfile $Target

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $connect = ("{0} -load `"{1}`" -l {2} -pw `$pw" -f
        $PUTTY,
        $profile,
        $Credential.UserName
    )
    Invoke-Expression $connect
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
}

function Send-File ($Target, $File) {
    if ($Script:Credential -eq $null) {
        $Script:Credential = Get-Credential
    }

    $fname = Split-Path $File.FullName -Leaf

    $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($bstr)
    $ConnectString = ("{0} -pw `$pw -scp '{1}' {2}@{3}:flash:'{4}'" -f
        $PSCP,
        $File.FullName,
        $Credential.UserName,
        $Target.ip,
        $fname
    )

    if (![System.IO.File]::Exists($pscp)) {
        Copy-Item "$NOSC\bin\pscp.exe" $pscp
    }

    try {
        Invoke-Expression $ConnectString
    }
    catch {
        [System.Windows.Forms.MessageBox]::Show(
            "$_",
            "pSCP Secure File Transfer",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Error)
    }
    finally {
        [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($bstr)
    }
}

Export-ModuleMember -Function *

# Global Objects
$Script:Credential = $null

Export-ModuleMember -Variable Credential

###############################################################################
###############################################################################
## SECTION 02 ## PRIVATE FUNCTIONS AND VARIABLES
##
## No function or variable in this section is exported unless done so by an
## explicit call to Export-ModuleMember
###############################################################################
###############################################################################

Set-Variable -Name NOSC -Value "$env:USERPROFILE\Documents\WindowsPowerShell\Programs\NOSC" -Option Constant
Set-Variable -Name PSCP -Value "$env:USERPROFILE\Desktop\pscp.exe" -Option Constant
Set-Variable -Name PUTTY -Value "putty" -Option Constant
Set-Variable -Name CONFDB -Value "$NOSC\database\puttydb" -Option Constant
$env:Path += "$NOSC\bin;"

function Set-RegistryProfile ($Device) {

    $hostname = $Device.Hostname.Trim() -replace '[^\w]', '-'

    $conf    = Join-Path $CONFDB ("{0}.reg" -f $hostname)
    $default = Join-Path $CONFDB default.reg

    if (!(Test-Path -Path $conf)){
        Copy-Item $default $conf | Out-Null
    }
    $profile = Get-Content $conf

    $i = 0
    foreach ($line in $profile){
        switch -regex ($line) {
            '^\[HKEY_CURRENT_USER\\SOFTWARE\\SimonTatham\\PuTTY\\Sessions[^]]+]$' {
                $profile[$i] = "[HKEY_CURRENT_USER\SOFTWARE\SimonTatham\PuTTY\Sessions\{0}]" -f $hostname
            }
            '^"HostName"="[^"]*"$' {
                $profile[$i] = "`"HostName`"=`"{0}`"" -f $Device.ip
            }
            '^"WinTitle"="[^"]*"$' {
                $profile[$i] = "`"WinTitle`"=`"{0}  [{1}]`"" -f $hostname, $Device.ip
            }
        }
        $i++
    }

    $profile > $conf
    $command = "regedit /s $conf"
    Invoke-Expression $command
    return $hostname
}

###############################################################################
### Main Menu Definitions
$Menu = @{}

### Main Menu -----------------------------------------------------------------
$Menu.Putty = @{}
$Menu.Putty.ResetCredential = New-Object System.Windows.Forms.ToolStripMenuItem("Reset Credential", $null, {
    param($sender, $e)
    $Script:Credential = Get-Credential
})
$Menu.Putty.ResetCredential.Name = "ResetCredential"

$Menu.Putty.Root = New-Object System.Windows.Forms.ToolStripMenuItem("PuTTY", $null, @($Menu.Putty.ResetCredential))
$Menu.Putty.Name = 'Putty'
