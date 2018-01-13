<#
.SYNOPSIS



.DESCRIPTION


.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com

#>


Add-Type -AssemblyName System.Windows.Forms

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

    # Register Menus
    [void]$MenuStrip.Items.Add($Menu)
    [void]$MenuStrip.Items.Add( (New-Object System.Windows.Forms.ToolStripSeparator) )

    [void]$Parent.TabPages.Add( $ComplianceTab )

    $Loader = [PSCustomObject]@{
        ValidationContainer = $ValidationContainer
        OutputContainer = $OutputContainer
        CommandOutputTextBox = $CommandOutputTextBox
        ExpectedOutputTextBox = $ExpectedOutputTextBox

        ComplianceDetailLayout = $ComplianceDetailLayout
        ComplianceDeviceDetailTextBox = $ComplianceDeviceDetailTextBox
        ComplianceRuleDetailTextBox = $ComplianceRuleDetailTextBox
        ComplianceRuleDescriptionTextBox = $ComplianceRuleDescriptionTextBox
    }
    Add-Member -InputObject $Loader -MemberType ScriptMethod -Name Load -Value {
        param($sender, $e)
        # Split the text box areas 50/50 of the parent container size
        $this.ValidationContainer.SplitterDistance = $this.ValidationContainer.Width / 2
        $this.OutputContainer.SplitterDistance = $this.OutputContainer.Width / 2

        $this.CommandOutputTextBox.BringToFront()
        $this.ExpectedOutputTextBox.BringToFront()

        $this.ComplianceDetailLayout.BringToFront()
        $this.ComplianceDeviceDetailTextBox.BringToFront()
        $this.ComplianceRuleDetailTextBox.BringToFront()
        $this.ComplianceRuleDescriptionTextBox.BringToFront()
    }
    [void]$OnLoad.Add($Loader)
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
$ModuleInvocationPath  = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

###############################################################################
# Scan Config Tab Content Container Definitions
#region
$ScanConfigTab = New-Object System.Windows.Forms.TabPage
    $ScanConfigTab.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ScanConfigTab.Text = "Scan Configuration"
    [void]$TabContainer.TabPages.Add( $ScanConfigTab )

$ScanConfigBaseContainer = New-Object System.Windows.Forms.SplitContainer
    $ScanConfigBaseContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ScanConfigBaseContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical
    $ScanConfigBaseContainer.Panel1.BackColor = [System.Drawing.Color]::White
    $ScanConfigBaseContainer.Panel2.BackColor = [System.Drawing.Color]::White
    $ScanConfigBaseContainer.BackColor = [System.Drawing.Color]::Black

    $ScanConfigTab.Controls.Add( $ScanConfigBaseContainer )

# Security Technical Implementation Guide (STIG) Rules TreeView
$RuleTreeView = New-Object System.Windows.Forms.TreeView
    $RuleTreeView.Dock = [System.Windows.Forms.DockStyle]::Fill

    $ScanConfigBaseContainer.Panel1.Controls.Add( $RuleTreeView )

# Security Technical Implementation Guide (STIG) Rules Details
$ScanConfigRightContainer = New-Object System.Windows.Forms.SplitContainer
    $ScanConfigRightContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ScanConfigRightContainer.Orientation = [System.Windows.Forms.Orientation]::Horizontal
    $ScanConfigRightContainer.Panel1.BackColor = [System.Drawing.Color]::White
    $ScanConfigRightContainer.Panel2.BackColor = [System.Drawing.Color]::White
    $ScanConfigRightContainer.BackColor = [System.Drawing.Color]::Black

    $ScanConfigBaseContainer.Panel2.Controls.Add( $ScanConfigRightContainer )

$ValidationContainer = New-Object System.Windows.Forms.SplitContainer
    $ValidationContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ValidationContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical
    $ValidationContainer.Panel1.BackColor = [System.Drawing.Color]::White
    $ValidationContainer.Panel2.BackColor = [System.Drawing.Color]::White
    $ValidationContainer.BackColor = [System.Drawing.Color]::Black

    $ScanConfigRightContainer.Panel1.Controls.Add( $ValidationContainer )

    $CompliantOutput = New-Object System.Windows.Forms.TextBox
        $CompliantOutput.Dock = [System.Windows.Forms.DockStyle]::Fill
        $CompliantOutput.WordWrap = $false
        $CompliantOutput.ReadOnly = $true
        $CompliantOutput.BackColor = [System.Drawing.Color]::White
        $CompliantOutput.Text = "This is the expected compliance command output text area."

        $ValidationContainer.Panel1.Controls.Add( $CompliantOutput )

    $NonCompliantOutput = New-Object System.Windows.Forms.TextBox
        $NonCompliantOutput.Dock = [System.Windows.Forms.DockStyle]::Fill
        $NonCompliantOutput.WordWrap = $false
        $NonCompliantOutput.ReadOnly = $true
        $NonCompliantOutput.BackColor = [System.Drawing.Color]::White
        $NonCompliantOutput.Text = "This is the expected non-compliance command output text area."

        $ValidationContainer.Panel2.Controls.Add( $NonCompliantOutput )

$ScanRuleDetailTextBox = New-Object System.Windows.Forms.TextBox
    $ScanRuleDetailTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ScanRuleDetailTextBox.WordWrap = $true
    $ScanRuleDetailTextBox.ReadOnly = $true
    $ScanRuleDetailTextBox.BackColor = [System.Drawing.Color]::White
    $ScanRuleDetailTextBox.Text = "This is the security baseline rule detail text area."

    $ScanConfigRightContainer.Panel2.Controls.Add( $ScanRuleDetailTextBox )
#endregion