<#
.SYNOPSIS
    Content Addressable File System

.DESCRIPTION
    Provides content addressable file system (CAFS) capabilities.

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

$FileSystem = [PSCustomObject]@{
    # File System Info
    ObjectPath  = $null
    ShaProvider = Get-SecureHashProvider
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name SetLocation -Value {
    param(
        [Parameter(Mandatory = $true)]
        [String]
            $LiteralPath
    )

    $this.ObjectPath = $LiteralPath

    if (![System.IO.Directory]::Exists($this.ObjectPath) )
    {
        return $false
    }

    return $true
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name InitLocation -Value {
    param(
        [Parameter(Mandatory = $true)]
        [String]
            $LiteralPath
    )

    # Returns the directories created | NULL
    if (!$this.SetLocation($LiteralPath)) {
        New-Item $this.ObjectPath -ItemType Directory
    }
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name Hash -Value {
    param(
        # Data to be turned into a blob.
        [Parameter(Mandatory = $true)]
            $InputObject
    )

    if ($InputObject -is [String]) {
        $name = $this.ShaProvider.HashString( $InputObject )
    }
    elseif ($InputObject -is [System.IO.FileInfo]) {
        $name = $this.ShaProvider.HashFile( $InputObject )
    }
    else {
        throw (New-Object System.ArgumentException("Cannot serialize data of type [$($InputObject.GetType().Name)]"))
    }

    return $name
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name Write -Value {
    param(
        # Data to be turned into a blob.
        [Parameter(Mandatory = $true)]
            $InputObject
    )

    $name = $this.Hash($InputObject)

    $object_path = $this.ResolvePath($name)
    $object_cache = Split-Path $object_path -Parent

    if (![System.IO.Directory]::Exists($object_cache)) {
        [void]([System.IO.Directory]::CreateDirectory($object_cache))
    }

    ConvertTo-Json $blob > $object_path

    return $name
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name Get -Value {
    param(
        # Name of object to be returned.
        [Parameter(Mandatory = $true)]
            $Name
    )
    return (Get-Item $this.ResolvePath($Name))
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name Remove -Value {
param(
        # Name of object to be deleted.
        [Parameter(Mandatory = $true)]
            $Name
    )
    $object_path = $this.ResolvePath($Name)
    $cache_path  = Split-Path $object_path -Parent
    Remove-Item $object_path

    if ( !(Get-ChildItem $cache_path) )
    {
        Remove-Item $cache_path
    }
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name Exists -Value {
    param(
        # SHA1 identifier of the object blob being checked.
        [Parameter(Mandatory = $true)]
            $Name
    )
    return [System.IO.File]::Exists( $this.ResolvePath($Name) )
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name ResolvePath -Value {
    param(
        # SHA1 identifier of the object blob being checked.
        [Parameter(Mandatory = $true)]
            $Name
    )
    $object_cache = $Name.Substring(0, 2)
    $object_file  = $Name.Substring(2, 38)
    return ( Join-Path $this.ObjectPath (Join-Path $object_cache $object_file) )
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