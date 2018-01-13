<#
.SYNOPSIS
    Loads compliance detail windows controls and components.

.DESCRIPTION
    Windows GUI components for viewing security compliance data.

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

    [Void]$Parent.TabPages.Add($ComplianceDetailTab)

    $Loader = [PSCustomObject]@{
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
        $this.OutputContainer.SplitterDistance = $this.OutputContainer.Width / 2

        $this.CommandOutputTextBox.BringToFront()
        $this.ExpectedOutputTextBox.BringToFront()

        $this.ComplianceDetailLayout.BringToFront()
        $this.ComplianceDeviceDetailTextBox.BringToFront()
        $this.ComplianceRuleDetailTextBox.BringToFront()
        $this.ComplianceRuleDescriptionTextBox.BringToFront()
    }
    [Void]$OnLoad.Add($Loader)
}

function Set-Content {
    param(
        [Parameter(Mandatory = $true)]
            [Object]$Data
    )
    
    $ComplianceDetailContainer.Data = $Data

    $CommandOutputTextBox.Text = ($Data.Results   -replace ("`r", "`n") -replace ("`n`n", "`n") -replace ("`n", "`r`n")).Trim()
    $ExpectedOutputTextBox.Text = ($Data.Expected -replace ("`r", "`n") -replace ("`n`n", "`n") -replace ("`n", "`r`n")).Trim()

    $DeviceInfo = ("Hostname: {0}`r`nIPv4: {1}`r`nDevice Type: {2}" -f
        $Data.Hostname,
        $Data.Device,
        $Data.Device_Type)

    $ComplianceDeviceDetailTextBox.Text = $DeviceInfo

    $RuleInfo = ("Validtion Command: {0}`r`nCategory: {1}`r`nFinding: {2}`r`nValidated Time: {3}" -f
        $Data.Command,
        $Data.Category,
        $Data.Findings,
        ([DateTime]::UtcNow.ToShortDateString() + " " + [DateTime]::UtcNow.ToShortTimeString()))

    $ComplianceRuleDetailTextBox.Text = $RuleInfo

    $ComplianceRuleDescriptionTextBox.Text = $Data.NetId
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

# Compliance Detail Tab
$ComplianceDetailTab = New-Object System.Windows.Forms.TabPage
    $ComplianceDetailTab.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComplianceDetailTab.Text = "Details"

    # Registered With Parent TabContainer by Register-Components

$ComplianceDetailContainer = New-Object System.Windows.Forms.TableLayoutPanel
& {
    $ComplianceDetailContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComplianceDetailContainer.AutoSize = $true
    $ComplianceDetailContainer.RowCount = 2

    # Button Section
    [Void]$ComplianceDetailContainer.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $ComplianceDetailContainer.RowStyles[0].SizeType = [System.Windows.Forms.SizeType]::Absolute
    $ComplianceDetailContainer.RowStyles[0].Height = 30

    # Rule Detailed Description Span Row
    [Void]$ComplianceDetailContainer.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $ComplianceDetailContainer.RowStyles[1].SizeType = [System.Windows.Forms.SizeType]::Percent
    $ComplianceDetailContainer.RowStyles[1].Height = 100

    # Static Property for tracking current NetId being viewed
    Add-Member -InputObject $ComplianceDetailContainer -MemberType NoteProperty -Name Data -Value $null

    $ComplianceDetailTab.Controls.Add( $ComplianceDetailContainer )
}

# Compliance Detail Section Button Bar
& {
    $ViewerButton = New-Object System.Windows.Forms.Button
    $ViewerButton.Dock = [System.Windows.Forms.DockStyle]::Left
    $ViewerButton.Text = "Open STIGViewer"
    $ViewerButton.Width = 125
    $ViewerButton.Height = 22
    $ViewerButton.Add_Click({
        $stig = $ComplianceDetailContainer.Data.Device_Type
        $m = [System.Text.RegularExpressions.Regex]::Match($ComplianceDetailContainer.Data.NetId, '([^\s]+) -')
        $id = $m.Groups[1].Value

        $viewer = Get-Viewer $id $stig
        
        [Void]$viewer.Show($MainForm)
    })

    $ButtonPanel = New-Object System.Windows.Forms.Panel
    $ButtonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ButtonPanel.BackColor = [System.Drawing.Color]::White
    $ButtonPanel.Controls.Add($ViewerButton)

    $ComplianceDetailContainer.Controls.Add($ButtonPanel, 0, 0)
}

# Validation Scan Command Output
#region
$ComplianceRightContainer = New-Object System.Windows.Forms.SplitContainer
&{
    $ComplianceRightContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComplianceRightContainer.Orientation = [System.Windows.Forms.Orientation]::Horizontal

    $ComplianceDetailContainer.Controls.Add($ComplianceRightContainer, 0, 1)
}

$OutputContainer = New-Object System.Windows.Forms.SplitContainer
    $OutputContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $OutputContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical

    $ComplianceRightContainer.Panel1.Controls.Add( $OutputContainer )

    $CommandOutputTextBox = New-Object System.Windows.Forms.TextBox
        $CommandOutputTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
        $CommandOutputTextBox.Multiline = $true
        $CommandOutputTextBox.WordWrap = $false
        $CommandOutputTextBox.ReadOnly = $true
        $CommandOutputTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $CommandOutputTextBox.BackColor = [System.Drawing.Color]::White
        $CommandOutputTextBox.Font = New-Object System.Drawing.Font("Lucida Console", 12)
        $CommandOutputTextBox.Text = "This is the command output text area."

        $CommandOutputLabel = New-Object System.Windows.Forms.Label
            $CommandOutputLabel.Dock = [System.Windows.Forms.DockStyle]::Top
            $CommandOutputLabel.BackColor = [System.Drawing.Color]::AliceBlue
            $CommandOutputLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $CommandOutputLabel.Text = "Verification Command Output"

        $OutputContainer.Panel1.Controls.Add( $CommandOutputLabel )
        $OutputContainer.Panel1.Controls.Add( $CommandOutputTextBox )

    $ExpectedOutputTextBox = New-Object System.Windows.Forms.TextBox
        $ExpectedOutputTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
        $ExpectedOutputTextBox.Multiline = $true
        $ExpectedOutputTextBox.WordWrap = $false
        $ExpectedOutputTextBox.ReadOnly = $true
        $ExpectedOutputTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $ExpectedOutputTextBox.BackColor = [System.Drawing.Color]::White
        $ExpectedOutputTextBox.Font = New-Object System.Drawing.Font("Lucida Console", 12)
        $ExpectedOutputTextBox.Text = "This is the expected output text area."

        $ExpectedOutputLabel = New-Object System.Windows.Forms.Label
            $ExpectedOutputLabel.Dock = [System.Windows.Forms.DockStyle]::Top
            $ExpectedOutputLabel.BackColor = [System.Drawing.Color]::AliceBlue
            $ExpectedOutputLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $ExpectedOutputLabel.Text = "Expected Command Output"

        $OutputContainer.Panel2.Controls.Add( $ExpectedOutputLabel )
        $OutputContainer.Panel2.Controls.Add( $ExpectedOutputTextBox )
#endregion //Validation Scan Command Output

# Node and Security Rule Details
#region
$ComplianceDetailLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $ComplianceDetailLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComplianceDetailLayout.AutoSize = $true
    $ComplianceDetailLayout.RowCount = 2
    $ComplianceDetailLayout.ColumnCount = 2

    # Device Info Column
    [Void]$ComplianceDetailLayout.ColumnStyles.Add( (New-Object System.Windows.Forms.ColumnStyle) )
    $ComplianceDetailLayout.ColumnStyles[0].SizeType = [System.Windows.Forms.SizeType]::Percent
    $ComplianceDetailLayout.ColumnStyles[0].Width = 50

    # Rule Info Column
    [Void]$ComplianceDetailLayout.ColumnStyles.Add( (New-Object System.Windows.Forms.ColumnStyle) )
    $ComplianceDetailLayout.ColumnStyles[1].SizeType = [System.Windows.Forms.SizeType]::Percent
    $ComplianceDetailLayout.ColumnStyles[1].Width = 50

    # Device Description and Rule Brief Description Row
    [Void]$ComplianceDetailLayout.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $ComplianceDetailLayout.RowStyles[0].SizeType = [System.Windows.Forms.SizeType]::Absolute
    $ComplianceDetailLayout.RowStyles[0].Height = 175

    # Rule Detailed Description Span Row
    [Void]$ComplianceDetailLayout.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $ComplianceDetailLayout.RowStyles[1].SizeType = [System.Windows.Forms.SizeType]::Percent
    $ComplianceDetailLayout.RowStyles[1].Height = 100

    $ComplianceRightContainer.Panel2.Controls.Add( $ComplianceDetailLayout )

$ComplianceDevicePanel = New-Object System.Windows.Forms.Panel
    $ComplianceDevicePanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComplianceDetailLayout.Controls.Add($ComplianceDevicePanel, 0, 0)

    $ComplianceDeviceDetailTextBox = New-Object System.Windows.Forms.TextBox
        $ComplianceDeviceDetailTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
        $ComplianceDeviceDetailTextBox.Multiline = $true
        $ComplianceDeviceDetailTextBox.WordWrap = $false
        $ComplianceDeviceDetailTextBox.ReadOnly = $true
        $ComplianceDeviceDetailTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $ComplianceDeviceDetailTextBox.BackColor = [System.Drawing.Color]::White
        $ComplianceDeviceDetailTextBox.Font = New-Object System.Drawing.Font($ComplianceDeviceDetailTextBox.Font.Name, 12)
        $ComplianceDeviceDetailTextBox.Text = "This is the security baseline device detail text area."

        $ComplianceDeviceDetailLabel = New-Object System.Windows.Forms.Label
            $ComplianceDeviceDetailLabel.Dock = [System.Windows.Forms.DockStyle]::Top
            $ComplianceDeviceDetailLabel.BackColor = [System.Drawing.Color]::AliceBlue
            $ComplianceDeviceDetailLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $ComplianceDeviceDetailLabel.Text = "Node Device Information"
        
        $ComplianceDevicePanel.Controls.Add( $ComplianceDeviceDetailTextBox )
        $ComplianceDevicePanel.Controls.Add( $ComplianceDeviceDetailLabel )

$ComplianceRuleInfoPanel = New-Object System.Windows.Forms.Panel
    $ComplianceRuleInfoPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComplianceDetailLayout.Controls.Add($ComplianceRuleInfoPanel, 1, 0)

    $ComplianceRuleDetailTextBox = New-Object System.Windows.Forms.TextBox
        $ComplianceRuleDetailTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
        $ComplianceRuleDetailTextBox.Multiline = $true
        $ComplianceRuleDetailTextBox.WordWrap = $false
        $ComplianceRuleDetailTextBox.ReadOnly = $true
        $ComplianceRuleDetailTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $ComplianceRuleDetailTextBox.BackColor = [System.Drawing.Color]::White
        $ComplianceRuleDetailTextBox.Font = New-Object System.Drawing.Font($ComplianceRuleDetailTextBox.Font.Name, 12)
        $ComplianceRuleDetailTextBox.Text = "This is the security baseline rule detail text area."

        $ComplianceRuleDetailLabel = New-Object System.Windows.Forms.Label
            $ComplianceRuleDetailLabel.Dock = [System.Windows.Forms.DockStyle]::Top
            $ComplianceRuleDetailLabel.BackColor = [System.Drawing.Color]::AliceBlue
            $ComplianceRuleDetailLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $ComplianceRuleDetailLabel.Text = "Rule Information"

        $ComplianceRuleInfoPanel.Controls.Add($ComplianceRuleDetailTextBox)
        $ComplianceRuleInfoPanel.Controls.Add($ComplianceRuleDetailLabel)

$ComplianceRuleDescriptionPanel = New-Object System.Windows.Forms.Panel
    $ComplianceRuleDescriptionPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComplianceDetailLayout.Controls.Add($ComplianceRuleDescriptionPanel, 0, 1)
    $ComplianceDetailLayout.SetColumnSpan($ComplianceRuleDescriptionPanel, 2)

    $ComplianceRuleDescriptionTextBox = New-Object System.Windows.Forms.TextBox
        $ComplianceRuleDescriptionTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
        $ComplianceRuleDescriptionTextBox.Multiline = $true
        $ComplianceRuleDescriptionTextBox.WordWrap = $true
        $ComplianceRuleDescriptionTextBox.ReadOnly = $true
        $ComplianceRuleDescriptionTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $ComplianceRuleDescriptionTextBox.BackColor = [System.Drawing.Color]::White
        $ComplianceRuleDescriptionTextBox.Font = New-Object System.Drawing.Font($ComplianceRuleDescriptionTextBox.Font.Name, 12)
        $ComplianceRuleDescriptionTextBox.Text = "This is the security baseline rule description text area."

        $ComplianceRuleDescriptionLabel = New-Object System.Windows.Forms.Label
            $ComplianceRuleDescriptionLabel.Dock = [System.Windows.Forms.DockStyle]::Top
            $ComplianceRuleDescriptionLabel.BackColor = [System.Drawing.Color]::AliceBlue
            $ComplianceRuleDescriptionLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $ComplianceRuleDescriptionLabel.Text = "Rule Description"
    
    $ComplianceRuleDescriptionPanel.Controls.Add($ComplianceRuleDescriptionTextBox)
    $ComplianceRuleDescriptionPanel.Controls.Add($ComplianceRuleDescriptionLabel)

#endregion //Node and Security Rule Details