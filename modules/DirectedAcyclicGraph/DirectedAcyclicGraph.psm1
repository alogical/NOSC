<#
.SYNOPSIS
    Directed Acyclic Graph (DAG) module.

.DESCRIPTION
    Provides DAG capabilities for data coloboration and version control.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>
Add-Type -TypeDefinition @"
namespace VersionControl {
    namespace DAG {
        public enum ObjectType {
            Blob,
            Commit,
            Tree,
            Tag
        }
    }
}
"@

Import-Module "$Global:AppPath\modules\CAFS\CAFS.psm1"

###############################################################################
###############################################################################
## SECTION 01 ## PUBILC FUNCTIONS AND VARIABLES
##
## Pass-thru Export-ModuleMember calls export all functions and variables
## to the global session that were passed to this modules session from nested
## modules.
###############################################################################
###############################################################################

$Graph = [PSCustomObject]@{
    
}

Add-Member -InputObject $Graph -MemberType ScriptMethod -Name Stage -Value {
    
}

Add-Member -InputObject $Graph -MemberType ScriptMethod -Name Commit -Value {
    
}

function Load-Tree {
    param(
        # Root directory of the content addressable files system.
        [Parameter(Mandatory = $true)]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
        [String]
            $LiteralPath,

        # SHA1 name of index tree.
        [Parameter(Mandatory = $true)]
        [String]
            $Name
    )

    $f = Get-Item (Join-Path $LiteralPath $Name)

    if (!$f) {
        throw (New-Object System.IO.FileNotFoundException("Could not locate index: $Name"))
    }

    $stream  = $f.OpenText()
    $content = $stream.ReadToEnd()

    $stream.Close()
    return ( ConvertFrom-PSObject (ConvertFrom-Json $content) )
}

function New-Commit {
    param(
        [Parameter(Mandatory = $true)]
        [String]
            $Parent,

        [Parameter(Mandatory = $true)]
        [String]
            $Author,

        [Parameter(Mandatory = $true)]
        [String]
            $Message,

        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]
            $Entries
    )

    $commit = @{
        Tree   = New-Tree $Entries
        Parent = $Parent
    }
}

function New-Tree {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]
            $Entries
    )

    $tree = @{}
    foreach ($entry in $Entries) {
        switch ($entry.Type) {
            ([ContentFileSystem.ObjectType]::Tree) {
                $tree[$entry.Name] = New-Tree $entry.Content
            }
            ([ContentFileSystem.ObjectType]::Blob) {
                $tree[$entry.Name] = $entry.Guid
            }
            default {
                throw (New-Object System.ApplicationException("Invalid index entry."))
            }
        }
    }
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

function New-SecureHashProvider {
    $provider = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider

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