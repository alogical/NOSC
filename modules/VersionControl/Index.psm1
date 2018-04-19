<#
.SYNOPSIS
    Index of a working directory for tracking changes.

.DESCRIPTION
    Provides context information of a working directory for determining what files
    have changed.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>

###############################################################################
###############################################################################
## SECTION 01 ## PUBILC FUNCTIONS AND VARIABLES
##
## Pass-thru Export-ModuleMember calls export all functions and variables
## to the global session that were passed to this modules session from nested
## modules.
###############################################################################
###############################################################################

$Index = [PSCustomObject]@{
    Entries = New-Object System.Collections.ArrayList
    Cache   = New-Object System.Collections.ArrayList
    Path    = [String]::Empty
}

Add-Member -InputObject $Index -MemberType ScriptMethod -Name Load -Value {
    param(
        # Index file path.
        [Parameter(Mandatory = $true)]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
        [String]
            $LiteralPath
    )

    $f = Get-Item $LiteralPath

    if (!$f) {
        throw (New-Object System.IO.FileNotFoundException("Could not locate index"))
    }

    $stream  = $f.OpenText()
    $content = $stream.ReadToEnd()

    $stream.Close()
    return ( ConvertFrom-PSObject (ConvertFrom-Json $content) )
}

Export-ModuleMember *

###############################################################################
###############################################################################
## SECTION 02 ## PRIVATE FUNCTIONS AND VARIABLES
##
## No function or variable in this section is exported unless done so by an
## explicit call to Export-ModuleMember
###############################################################################
###############################################################################

$InvocationPath  = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)