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
            [System.Windows.Forms.TabControl]
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

function Open-Putty ($IP) {
    if ($Script:Credential -eq $null) {
        $Script:Credential = Get-Credential
    }
    $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Credential.Password)
    $pw = [System.Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
    $connect = ("{0} {1}@{2} -pw `$pw" -f
        $putty,
        $Credential.UserName,
        $IP
    )
    Invoke-Expression $connect
    [System.Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR)
}

Export-ModuleMember -Function *

# Global Objects
$Credential = $null

Export-ModuleMember -Variable Credential

###############################################################################
###############################################################################
## SECTION 02 ## PRIVATE FUNCTIONS AND VARIABLES
##
## No function or variable in this section is exported unless done so by an
## explicit call to Export-ModuleMember
###############################################################################
###############################################################################

$putty = "$ModuleInvocationPath\..\..\bin\putty.exe"

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