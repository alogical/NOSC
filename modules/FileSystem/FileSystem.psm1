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
    Directory  = $null
    ObjectPath = $null
    ShaProvider = Get-SecureHashProvider
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name SetLocation -Value {
    param(
        [Parameter(Mandatory = $true)]
        [String]
            $LiteralPath
    )

    $this.Directory  = Join-Path $LiteralPath .cafs
    $this.ObjectPath = Join-Path $LiteralPath objects

    if (![System.IO.Directory]::Exists($this.Directory) -or
        ![System.IO.Directory]::Exists($this.ObjectPath) )
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
        New-Item $this.Directory  -ItemType Directory
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

    $object_cache = $name.Substring(0, 2)
    $object_file  = $name.Substring(2, 38)

    $object_cache_path = Join-Path $this.ObjectPath $object_cache
    if (![System.IO.Directory]::Exists($object_cache_path)) {
        [void][System.IO.Directory]::CreateDirectory($object_cache_path)
    }

    $object_path  = Join-Path $object_cache_path $object_file
    ConvertTo-Json $blob > $object_path

    return $name
}

Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name Get -Value {
    param(
        # Data to be turned into a blob.
        [Parameter(Mandatory = $true)]
            $Name
    )

    $object_cache = $name.Substring(0, 2)
    $object_file  = $name.Substring(2, 38)
    $object_path  = Join-Path $object_cache_path $object_file

    return (Get-Item $object_path)
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