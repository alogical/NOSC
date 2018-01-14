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
            [System.Windows.Forms.Form]
            $Window,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.TabControl]
            $Parent,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.MenuStrip]
            $MenuStrip,

        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $OnLoad
    )

    # Register Menus
    [void]$MenuStrip.Items.Add($Menu)
    [void]$MenuStrip.Items.Add( (New-Object System.Windows.Forms.ToolStripSeparator) )

    [void]$Parent.TabPages.Add( $ComplianceTab )

    $Loader = [PSCustomObject]@{
        ValidationContainer = $ValidationContainer
        #OutputContainer = $OutputContainer
    }
    Add-Member -InputObject $Loader -MemberType ScriptMethod -Name Load -Value {
        param($sender, $e)
        # Split the text box areas 50/50 of the parent container size
        $this.ValidationContainer.SplitterDistance = $this.ValidationContainer.Width / 2
        #$this.OutputContainer.SplitterDistance = $this.OutputContainer.Width / 2
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

$ConfigTab = New-Object System.Windows.Forms.TabPage
    $ConfigTab.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ConfigTab.Text = "Scan Configuration"
    [void]$TabContainer.TabPages.Add( $ConfigTab )

$BaseContainer = New-Object System.Windows.Forms.SplitContainer
    $BaseContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $BaseContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical
    $BaseContainer.Panel1.BackColor = [System.Drawing.Color]::White
    $BaseContainer.Panel2.BackColor = [System.Drawing.Color]::White
    $BaseContainer.BackColor = [System.Drawing.Color]::Black

    $ConfigTab.Controls.Add( $BaseContainer )

# Security Technical Implementation Guide (STIG) Rules TreeView
$RuleTreeView = New-Object System.Windows.Forms.TreeView
    $RuleTreeView.Dock = [System.Windows.Forms.DockStyle]::Fill

    $BaseContainer.Panel1.Controls.Add( $RuleTreeView )

# Security Technical Implementation Guide (STIG) Rules Details
$RightContainer = New-Object System.Windows.Forms.SplitContainer
    $RightContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $RightContainer.Orientation = [System.Windows.Forms.Orientation]::Horizontal
    $RightContainer.Panel1.BackColor = [System.Drawing.Color]::White
    $RightContainer.Panel2.BackColor = [System.Drawing.Color]::White
    $RightContainer.BackColor = [System.Drawing.Color]::Black

    $BaseContainer.Panel2.Controls.Add( $RightContainer )

$ValidationContainer = New-Object System.Windows.Forms.SplitContainer
    $ValidationContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ValidationContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical
    $ValidationContainer.Panel1.BackColor = [System.Drawing.Color]::White
    $ValidationContainer.Panel2.BackColor = [System.Drawing.Color]::White
    $ValidationContainer.BackColor = [System.Drawing.Color]::Black

    $RightContainer.Panel1.Controls.Add( $ValidationContainer )

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

$RuleDetail = New-Object System.Windows.Forms.TextBox
    $RuleDetail.Dock = [System.Windows.Forms.DockStyle]::Fill
    $RuleDetail.WordWrap = $true
    $RuleDetail.ReadOnly = $true
    $RuleDetail.BackColor = [System.Drawing.Color]::White
    $RuleDetail.Text = "This is the security baseline rule detail text area."

    $RightContainer.Panel2.Controls.Add( $RuleDetail )