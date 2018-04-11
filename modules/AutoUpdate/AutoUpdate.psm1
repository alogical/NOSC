<#
.SYNOPSIS
    Auto updates program script files from a remote repository.

.DESCRIPTION
    Uses the PackageManager module to manage program update installation.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>

function Check-Updates {
    if (Sync-Repository -Repository Network-Operations) {
        $installed  = Get-Package -Repository Installed -Package Network-Operations-Sustainment-Center-1.x.x
        $source = Get-Package -Repository Network-Operations -Package Network-Operations-Sustainment-Center-1.x.x

        # Symantic Version Number Wrappers
        $CurrentVersion = New-VersionWrapper $installed.Version
        $SourceVersion = New-VersionWrapper $source.Version

        # Compare versions to determine if update is necessary
        if ($CurrentVersion.Compare($SourceVersion) -eq -1) {
            return (Install-Update $source)
        }
    }

    return $false
}

Export-ModuleMember -Function *

###############################################################################
###############################################################################
## SECTION 02 ## PRIVATE FUNCTIONS AND VARIABLES
##
## No function or variable in this section is exported unless done so by an
## explicit call to Export-ModuleMember
###############################################################################
###############################################################################
Import-Module PackageManager

$ModuleInvocationPath  = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
$NOSC = "$env:USERPROFILE\Documents\WindowsPowerShell\Programs\NOSC"