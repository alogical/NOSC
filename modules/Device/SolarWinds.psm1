Add-Type -AssemblyName System.ServiceModel
###############################################################################
###############################################################################
## SECTION 01 ## PUBILC FUNCTIONS AND VARIABLES
##
## Pass-thru Export-ModuleMember calls export all functions and variables
## to the global session that were passed to this modules session from nested
## modules.
###############################################################################
###############################################################################
function Get-Nodes () {
    if ($Script:SWIS_CONNECTION -eq $null)
    {
        Write-Error "SolarWinds Information Service connection not initialized."
        return
    }

    $nodes = Get-SwisData -Query $QRY_NODE_INFO_BASE -SwisConnection $Script:SWIS_CONNECTION
    foreach ($n in $nodes)
    {
        $custom_properties = Get-SwisData -Query ($Script:DQRY_NODE_INFO_CUSTOM -f $n.NodeID) -SwisConnection $Script:SWIS_CONNECTION
        $node_settings = Get-SwisData -Query ($DQRY_NODE_SETTINGS -f $n.NodeID) -SwisConnection $Script:SWIS_CONNECTION
        foreach ($setting in $node_settings)
        {
            if ($setting.SettingName -match 'SSH')
            {
                $ssh = $setting.SettingValue
                continue
            }
            if ($setting.SettingName -match 'Web')
            {
                $url = $setting.SettingValue
            }
        }

        $node = @{
            NodeID = $n.NodeID
            Hostname = $n.Caption
            IP = $n.IPAddress
            Vendor = $n.Vendor
            DNS = $n.DNS
            SSH = $ssh
            URL = $url
            MachineType = $n.MachineType
        }

        $node.RemoteManagement = 'URL'
        switch ($node.Vendor)
        {
            'Cisco' {
                if ($node.SSH -ne $null)
                {
                    $node.RemoteManagement = 'SSH'
                }
            }

            'Windows' {
                $node.RemoteManagement = 'RDP'
            }
        }

        for ($i = 0; $i -lt $Script:CUSTOM_PROPLIST.Count; $i++)
        {
            $node.($Script:CUSTOM_PROPLIST[$i]) = $custom_properties.($Script:CUSTOM_PROPLIST[$i])
        }

        Write-Output ([PSCustomObject]$node)
    }
}

function Open-SwisConnection {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
        [String]
            $ServerName,

        [Parameter(Mandatory = $false)]
        [PSCredential]
            $Credential
    )

    if ($Credential -ne $null)
    {
        $Script:SWIS_CONNECTION = Connect-Swis -Hostname $ServerName -Credential $Credential
    }
    else
    {
        $Script:SWIS_CONNECTION = Connect-Swis -Hostname $ServerName -Trusted
    }

    if ($Script:SWIS_CONNECTION -ne $null)
    {
        $Script:CUSTOM_PROPLIST = Get-SwisData -Query $QRY_CUSTOM_PROPLIST -SwisConnection $Script:SWIS_CONNECTION
        $Script:DQRY_NODE_INFO_CUSTOM = Set-NodeCustomPropertiesQuery
        return $true
    }
    else
    {
        return $false
    }
}

function Test-SwisConnection {
    if ($Script:SWIS_CONNECTION.ChannelFactory.State -eq [System.ServiceModel.CommunicationState]::Opened)
    {
        return $true
    }
    return $false
}

function Close-SwisConnection () {
    try
    {
        $Script:SWIS_CONNECTION.Close()
        $Script:SWIS_CONNECTION.Dispose()
    }
    catch
    {
        Write-Error $_.Exception
    }
    finally
    {
        # Nothing else to do.
    }
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
Import-Module SwisPowerShell
$Script:SWIS_CONNECTION = $null
$Script:CUSTOM_PROPLIST = $null
$Script:DQRY_NODE_INFO_CUSTOM = $null

function Set-NodeCustomPropertiesQuery () {
    $qry_builder = New-Object System.Text.StringBuilder
    [void]$qry_builder.Append('SELECT ')
    for ($i = 0; $i -lt $Script:CUSTOM_PROPLIST.Count; $i++)
    {
        if ($i -eq 0)
        {
            [void]$qry_builder.Append( ("{0}" -f $Script:CUSTOM_PROPLIST[$i]) )
        }
        else
        {
            [void]$qry_builder.Append( (", {0}" -f $Script:CUSTOM_PROPLIST[$i]) )
        }
    }
    [void]$qry_builder.Append(' FROM Orion.NodesCustomProperties WHERE NodeID = {0};')

    return $qry_builder.ToString()
}

$QRY_NODE_INFO_BASE = @"
SELECT NodeID, Caption, IPAddress, Vendor, DNS, MachineType
FROM Orion.Nodes
"@

$QRY_CUSTOM_PROPLIST = @"
SELECT Name
FROM Metadata.Property
WHERE EntityName = 'Orion.NodesCustomProperties'
    AND IsNavigable=FALSE
    AND IsInherited=FALSE
    AND Name != 'NodeID'
    AND Name != 'InstanceType'
"@

$DQRY_NODE_SETTINGS = @"
SELECT SettingName, SettingValue
FROM Orion.NodeSettings
    WHERE NodeID = {0};
"@
