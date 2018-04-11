<#
.SYNOPSIS
    Baseline network host device information management.

.DESCRIPTION
    Provides the entry point for loading configurations and data used to
    initialize Windows GUI components for managing the list of devices that make
    up the network baseline.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>

Add-Type -AssemblyName System.Windows.Forms

$ModuleInvocationPath  = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

###############################################################################
###############################################################################
## SECTION 01 ## PUBILC FUNCTIONS AND VARIABLES
##
## Pass-thru Export-ModuleMember calls export all functions and variables
## to the global session that were passed to this modules session from nested
## modules.
###############################################################################
###############################################################################

function Initialize-Components {
    param(
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Form]$Window,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.TabControl]$Parent,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.MenuStrip]$MenuStrip,

        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]$OnLoad
    )

    $Container, $Layout, $ComponentMenuStrip = New-Component
    [void]$Parent.TabPages.Add($Container)

    $ViewComponent = Initialize-ViewComponents -Window $Window -Parent $Container -MenuStrip $ComponentMenuStrip -OnLoad $OnLoad

    [Void]$Layout.Controls.Add($ViewComponent, 0, 1)
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
Import-Module "$ModuleInvocationPath\SingleView.psm1" -Prefix View

$ImagePath = "$ModuleInvocationPath\..\..\resources"
$BinPath   = "$ModuleInvocationPath\..\..\bin"

###############################################################################
# Static Objects and Scriptblocks


# Main Menu Definitions
#region
### File Menu -------------------------------------------------------------

#endregion

function New-Component() {
    ###############################################################################
    # Container Definitions
    $Component = New-Object System.Windows.Forms.TabPage
        $Component.Dock = [System.Windows.Forms.DockStyle]::Fill
        $Component.Text = "Devices"

        # Attached to Parent Control by Module Component Registration Function

        # Data Source Reference for Component
        Add-Member -InputObject $Component -MemberType NoteProperty -Name Data -Value (New-Object System.Collections.ArrayList)

    $Layout = New-Object System.Windows.Forms.TableLayoutPanel
        $Layout.Dock = [System.Windows.Forms.DockStyle]::Fill
        $Layout.AutoSize = $true
        $Layout.RowCount = 2

    # Button Section
    [Void]$Layout.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
        $Layout.RowStyles[0].SizeType = [System.Windows.Forms.SizeType]::Absolute
        $Layout.RowStyles[0].Height = 30

    # Rule Detailed Description Span Row
    [Void]$Layout.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
        $Layout.RowStyles[1].SizeType = [System.Windows.Forms.SizeType]::Percent
        $Layout.RowStyles[1].Height = 100

    [Void]$Component.Controls.Add($Layout)

    $DeviceMenu = New-Object System.Windows.Forms.MenuStrip
    $DeviceMenu.Dock = [System.Windows.Forms.DockStyle]::Fill
        [Void]$Layout.Controls.Add($DeviceMenu, 0, 0)

    return $Component, $Layout, $DeviceMenu
}
