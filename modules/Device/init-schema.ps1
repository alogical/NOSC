Add-Type -TypeDefinition @"
    namespace Device {
        public enum ObjectCategory
        {
            Default = 0,
            NetworkDevice,
            NetworkAppliance,
            Server
        }

        public enum AddressFamily

        [System.FlagsAttribute]
        public enum AccessMethod {
            None          = 0,
            SSH           = 1,
            Telnet        = 2,
            RemoteDesktop = 4,
            HTTP          = 8,
            HTTPS         = 16
        }

        public enum InterfaceMedia {
            CATX,
            COAX,
            Serial,
            Fiber
        }
    }
"@

function New-BaseObject {
    $base_object = @{
        # Global object identifier.
        GUID            = [System.Guid]::NewGuid().Guid

        # Management category.
        Category        = [Device.ObjectCategory]::Default

        # Host Operating System GUID.
        OperatingSystem = [String]::Empty

        # Fully Qualified Domain Name [Host] Component.
        Hostname        = [String]::Empty

        # Fully Qualified Domain Name [Domain] Component.
        Domain          = [String]::Empty

        # Internet protocol address for remote access.
        AccessIPv4      = [String]::Empty

        # Internet protocol address for remote access.
        AccessIPv6      = [String]::Empty

        # Internet protocol address for PING.
        PollingIPv4     = [String]::Empty

        # Internet protocol address for PING.
        PollingIPv6     = [String]::Empty

        # Remote management access method.
        AccessMethod    = [Device.AccessMethod]::None

        # Add Hardware and if not a virtual system.
        Virtual         = $false

        # Serial numbers collection.
        Serial          = New-Object System.Collections.ArrayList

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

function New-SerialNumber {
    $serial = @{
        # Serial number.
        Number    = [String]::Empty

        # Modular component identification.
        Component = [String]::Empty
    }
}

function New-HardwareExtension {
    $hardware_extension = @{
        GUID   = [System.Guid]::NewGuid().Guid
        Make   = [String]::Empty
        Model  = [String]::Empty
    }
    return $hardware_extension
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

function New-NetworkDeviceExtension {
    $network_device_extension = @{
        # DeviceInterface Objects
        Interfaces  = New-Object System.Collections.ArrayList
        Controllers = New-Object System.Collections.ArrayList
        Tunnels     = New-Object System.Collections.ArrayList
        Loopbacks   = New-Object System.Collections.ArrayList
    }
    return $network_device_extension
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

function New-DeviceInterface {
    param(
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Parent
    )
    $device_interface = @{
        # Global Identifier
        GUID        = [System.Guid]::NewGuid().Guid

        # Internet Protocol Address
        IPv4        = [String]::Empty

        # Parent device GUID this interface belongs to.
        Parent      = $Parent.Guid

        # Interface name.
        Name        = [String]::Empty
        Description = [String]::Empty
        Speed       = 100
        Type        = [System.Net.NetworkInformation.NetworkInterfaceType]::Unknown
        Media       = [Device.InterfaceMedia]::CATX
    }
    return $device_interface
}

function New-NetworkTunnel {
    param(
        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Source,

        [Parameter(Mandatory = $true)]
        [System.Guid]
            $Destination
    )
    $device_tunnel = New-DeviceInterface

    # Source Interface GUID
    $device_tunnel.Source      = $Source.Guid

    # Destination Interface GUID
    $device_tunnel.Destination = $Destination.Guid

    return $device_tunnel
}