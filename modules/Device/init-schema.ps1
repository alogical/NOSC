Add-Type -TypeDefinition @"
    namespace Device {
        public enum ObjectCategory
        {
            Default = 0,
            NetworkDevice,
            NetworkAppliance,
            Server
        }

        [System.FlagsAttribute]
        public enum AccessProtocol {
            None          = 0,
            SSH           = 1,
            Telnet        = 2,
            RemoteDesktop = 4,
            HTTP          = 8,
            HTTPS         = 16
        }

        public enum AccessSourceType {
            Hostname,
            Interface
        }

        namespace Interface {
            public enum Media {
                None,
                CATX,
                COAX,
                Serial,
                Fiber
            }

            namespace Tunnel {
                public enum Type {
                    Static,
                    Multipoint
                }

                public enum MultipointRole {
                    Headend,
                    Endpoint
                }
            }
        }
    }
"@

###############################################################################
## Content Addressable File System Management
## ------------------------------------------
## Provides the API for storing objects within and retrieving objects from the
## content addressable filesystem.
###############################################################################

$ObjectIndex = [PSCustomObject]@{
    Device          = $null
    Interface       = $null
    Hardware        = $null
    OperatingSystem = $null
    Contact         = $null
}

Add-Member -InputObject $ObjectIndex -MemberType ScriptMethod -Name Load -Value {
    
}

function Save-Object {
    param(
        # SHA1 of object data.
        [Parameter(Mandatory = $true)]
            $InputObject,

        # SHA1 of parent object.
        [Parameter(Mandatory = $true)]
        [String]
            $Parent
    )

    $json = ConvertTo-Json $InputObject

    $object = @{
        Name   = $Name
        Parent = $Parent
    }
}

function Load-Index {
    param(
        # Root directory of the content addressable files system.
        [Parameter(Mandatory = $true)]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
        [String]
            $LiteralPath,

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

function Get-Device {
    param(
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Identifier
    )


}

function Get-Interface {
    param(
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Identifier
    )


}

function Get-Hardware {
    param(
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Identifier
    )


}

function Get-OperatingSystem {
    param(
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Identifier
    )


}

function Get-Contact {
    param(
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Identifier
    )


}

###############################################################################
## Content Addressable File System Objects
## ---------------------------------------
## These data structures are stored as unique objects with the content
## addressable filesystem.  They represent basic level objects or relational
## objects containing information shared between multiple distinct objects.
###############################################################################
function New-Device {
    $base_object = @{
        # Global object identifier.
        GUID                = [System.Guid]::NewGuid().Guid

        # Management category.
        Category            = [Device.ObjectCategory]::Default

        # Host Operating System GUID.
        OperatingSystem     = [System.Guid]::Empty.Guid

        # Fully Qualified Domain Name [Host] Component.
        Hostname            = [String]::Empty

        # Fully Qualified Domain Name [Domain] Component.
        Domain              = [String]::Empty

        # Interface for remote access.
        ManagementInterface = [System.Guid]::Empty.Guid

        # Interface for PING polling.
        PollingInterface    = [System.Guid]::Empty.Guid

        # Remote management access protocol.
        AccessProtocol      = [Device.AccessProtocol]::None

        # Remote management IP address source.
        AccessSourceType    = [Device.AccessSourceType]::Interface

        # Add Hardware and if not a virtual system.
        Virtual             = $false

        # Default device physical location information.
        Location = @{
            Room     = [String]::Empty
            Building = [String]::Empty
            City     = [String]::Empty
            Country  = [String]::Empty
        }

        # Management personnel contact information GUIDs
        Contacts = New-Object System.Collections.ArrayList
    }
    return $base_object
}

function New-OperatingSystem {
    $os = @{
        GUID = [System.Guid]::NewGuid().Guid
        Name = [String]::Empty
        EOL  = $false
    }
    return $os
}

function New-Hardware {
    $hardware = @{
        GUID       = [System.Guid]::NewGuid().Guid
        Make       = [String]::Empty
        Model      = [String]::Empty

        # Primary system identification serial number.
        Serial     = New-SerialNumber

        # Collection of sub-component serial numbers.
        Components = New-Object System.Collections.ArrayList
    }
    return $hardware
}

function New-Contact {
    $contact = @{
        GUID  = [System.Guid]::NewGuid().Guid
        Name  = [String]::Empty
        Phone = [String]::Empty
        Email = [String]::Empty
    }
    return $contact
}

function New-Interface {
    param(
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Device
    )
    $interface = @{
        # Global Identifier
        GUID        = [System.Guid]::NewGuid().Guid

        # Internet Protocol version 4 address
        IPv4        = [String]::Empty

        # Internet Protocol version 6 address.
        IPv6        = [String]::Empty

        # Parent device GUID this interface belongs to.
        Device      = $Device.Guid

        # Interface Details.
        Name        = [String]::Empty
        Description = [String]::Empty

        # Speed is in Kbps
        Speed       = 100000
        Type        = [System.Net.NetworkInformation.NetworkInterfaceType]::Unknown
        Media       = [Device.Interface.Media]::CATX

        # Collection of Interface GUIDs participating in a link with this interface.
        Links       = New-Object System.Collections.ArrayList
    }
    return $interface
}

<#
.SYNOPSIS
    Tunnel object constructor.

.DESCRIPTION
    Constructor for static or multipoint tunnel interfaces.
#>
function New-Tunnel {
    [CmdletBinding()]
    param(
        # Device owning this interface.
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Device,

        # Tunnel physical source interface.
        #   Physical interfaces must be defined before creating a tunnel interface.
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Source,

        # Static destination endpoint tunnel interface.
        #   The destination endpoint object and interface must be defined before
        #   creating the tunnel interface.
        [Parameter(Mandatory = $true,
                   ParameterSetName = 'Static')]
        [System.Guid]
            $Destination,

        # Multipoint tunnel (DMVPN) role.
        [Parameter(Mandatory = $true,
                   ParameterSetName = 'Multipoint')]
        [Device.Interface.Tunnel.MultipointRole]
            $MultipointRole,

        # Multipoint tunnel Headend NHRP server.
        [Parameter(Mandatory = $false,
                   ParameterSetName = 'Multipoint')]
        [System.Guid]
            $NhrpServer
    )

    if ($PSCmdlet.ParameterSetName -eq 'Static') {
        $tunnel = New-StaticTunnel @PSBoundParameters
    }
    else {
        $tunnel = New-MultipointTunnel @PSBoundParameters
    }

    return $tunnel
}

<#
.SYNOPSIS
    Static Tunnel object constructor.

.DESCRIPTION
    Constructor for static tunnel interfaces.
#>
function New-StaticTunnel {
    param(
        # Device owning this interface.
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Device,

        # Tunnel physical source interface.
        #   Physical interfaces must be defined before creating a tunnel interface.
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Source,

        # Static destination endpoint tunnel interface.
        #   The destination endpoint object and interface must be defined before
        #   creating the tunnel interface.
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Destination
    )
    $tunnel = New-Interface $Device

    # Overwrite Interface defaults
    $tunnel.Media = [Device.Interface.Media]::None
    $tunnel.Speed = 500
    $tunnel.Type  = [System.Net.NetworkInformation.NetworkInterfaceType]::Tunnel

    # Source Interface GUID
    $tunnel.Source      = $Source.Guid

    # Destination Interface GUID
    $tunnel.Destination = $Destination.Guid

    # Tunnel type information
    $tunnel.TunnelType = [Device.Interface.Tunnel.Type]::Static

    # Update participating interface link info


    return $tunnel
}

<#
.SYNOPSIS
    Multipoint Tunnel object constructor.

.DESCRIPTION
    Constructor for multipoint tunnel interfaces.
#>
function New-MultipointTunnel {
    param(
        # Device owning this interface.
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Device,

        # Tunnel physical source interface.
        #   Physical interfaces must be defined before creating a tunnel interface.
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Source,

        # Multipoint tunnel (DMVPN) role.
        [Parameter(Mandatory = $true)]
        [Device.Interface.Tunnel.MultipointRole]
            $MultipointRole,

        # Multipoint tunnel Headend NHRP server.
        [Parameter(Mandatory = $false,
                   ParameterSetName = 'Multipoint')]
        [System.Guid]
            $NhrpServer
    )
    $tunnel = New-Interface $Device

    # Overwrite Interface defaults
    $tunnel.Media = [Device.Interface.Media]::None
    $tunnel.Speed = 500
    $tunnel.Type  = [System.Net.NetworkInformation.NetworkInterfaceType]::Tunnel

    # Source Interface GUID
    $tunnel.Source = $Source.Guid

    # Tunnel type information
    $tunnel.TunnelType   = [Device.Interface.Tunnel.Type]::Multipoint
    $tunnel.Role   = $MultipointRole

    # Update participating interface link info


    return $tunnel
}

###############################################################################
## Content Extension Objects
## -------------------------
## These objects extend or are stored inside a collection within a content
## addressable file system object.  They are never stored as a seperate object.
###############################################################################
function New-SerialNumber {
    $serial = @{
        # Serial number.
        Number    = [String]::Empty

        # Modular component identification.
        Component = [String]::Empty
    }
    return $serial
}

function New-StigExtension {
    param(
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Checklist
    )
    $stig_extension = @{
        # STIG Checklist GUID
        GUID = $Checklist.Guid
    }
    return $stig_extension
}

function New-InterfaceCollection {
    $collection = @{
        # Generic Interface Object GUIDs
        Interfaces  = New-Object System.Collections.ArrayList

        # Controller Interface Object GUIDs
        Controllers = New-Object System.Collections.ArrayList

        # Tunnel Interface Object GUIDs
        Tunnels     = New-Object System.Collections.ArrayList

        # Loopback Interface Object GUIDs
        Loopbacks   = New-Object System.Collections.ArrayList
    }
    return $collection
}

###############################################################################
## Object Conversion Utilities
## ---------------------------
## These functions provide conversion from stored data to in memory nested data
## structures.
###############################################################################
function ConvertFrom-PSObject {
    param(
        [Parameter(Mandatory         = $false,
                   ValueFromPipeline = $true)]
        $InputObject = $null
    )

    process
    {
        if (!$InputObject) {
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