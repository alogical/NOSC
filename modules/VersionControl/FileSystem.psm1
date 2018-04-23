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

function New-FileManager {
    $FileSystem = [PSCustomObject]@{
        # File System Info
        ObjectPath  = $null
        ShaProvider = New-SecureHashProvider
    }

    Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name SetLocation -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $LiteralPath
        )

        $this.ObjectPath = $LiteralPath

        return (Test-Path $this.ObjectPath)
    }

    Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name Init -Value {
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

    Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name WriteBlob -Value {
        param(
            # A blob of data to be written to the content addressable file system.
            [Parameter(Mandatory = $true)]
            [byte[]]
                $Blob
        )

        $name = $this.ShaProvider.HashBytes($Blob)

        $object_path = $this.ResolvePath($name)
        $object_cache = Split-Path $object_path -Parent

        if (![System.IO.Directory]::Exists($object_cache)) {
            [void]([System.IO.Directory]::CreateDirectory($object_cache))
        }

        $writer = [System.IO.BinaryWriter]::new( [System.IO.File]::Open($object_path, [System.IO.FileMode]::Create) )
        $writer.Write($Blob)
        $writer.Flush()
        $writer.Close()

        return $name
    }

    Add-Member -InputObject $FileSystem -MemberType ScriptMethod -Name WriteStream -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.StreamReader]
                $Stream
        )

        $name = $this.ShaProvider.HashStream($Stream)

        $object_path = $this.ResolvePath($name)
        $object_cache = Split-Path $object_path -Parent

        if (![System.IO.Directory]::Exists($object_cache)) {
            [void]([System.IO.Directory]::CreateDirectory($object_cache))
        }

        $Stream.BaseStream.Position = 0
        $writer = [System.IO.BinaryWriter]::new( [System.IO.File]::Open($object_path, [System.IO.FileMode]::Create) )
        $writer.Write($Stream.ReadToEnd())
        $writer.Flush()
        $writer.Close()

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

    return $FileSystem
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

Import-Module "$AppPath\modules\Common\Objects.psm1"