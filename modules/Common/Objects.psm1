<#
.SYNOPSIS
    Common object manipulation utilities.

.DESCRIPTION
    Common routines for working with PowerShell objects used by many modules.

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

<#
.SYNOPSIS
    Performs a deep copy of a Hashtable memory structure.
#>
function Copy-Hashtable {
    param(
        [Parameter(Mandatory = $true)]
        [Hashtable]
            $InputObject
    )
    $hash = @{}
    foreach ($entry in $InputObject.GetEnumerator()) {
        $hash[$entry.Key] = $entry.Value
    }

    return $hash
}

function ConvertFrom-PSObject {
    param(
        [Parameter(Mandatory         = $false,
                   ValueFromPipeline = $true)]
        $InputObject = $null
    )

    process
    {
        if ($InputObject -eq $null) {
            return $null
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = New-Object System.Collections.ArrayList
            $collection.AddRange(
                @( foreach ($object in $InputObject) { ConvertFrom-PSObject $object } )
            )
            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertFrom-PSObject $property.Value
            }
            Write-Output -NoEnumerate $hash
        }
        else {
            Write-Output $InputObject
        }
    }
}

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

    Add-Member -InputObject $provider -MemberType ScriptMethod -Name HashStream -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.StreamReader]
                $Stream
        )
        [void]$this.ComputeHash( $Stream.BaseStream )
        return $this.OutString
    }

    Add-Member -InputObject $provider -MemberType ScriptMethod -Name HashBytes -Value {
        param(
            [Parameter(Mandatory = $true)]
            [byte[]]
                $InputBytes
        )
        [void]$this.ComputeHash($InputBytes)
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

Export-ModuleMember -Function *

###############################################################################
###############################################################################
## SECTION 02 ## PRIVATE FUNCTIONS AND VARIABLES
##
## No function or variable in this section is exported unless done so by an
## explicit call to Export-ModuleMember
###############################################################################
###############################################################################