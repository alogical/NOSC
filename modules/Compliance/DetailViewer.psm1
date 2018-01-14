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

    [Void]$Parent.TabPages.Add($BaseContainer)

    $Loader = [PSCustomObject]@{
        OutputContainer = $OutputContainer
        CommandOutput   = $CommandOutput
        ExpectedOutput  = $ExpectedOutput
        DetailLayout    = $DetailLayout
        DeviceDetail    = $DeviceDetail
        RuleDetail      = $RuleDetail
        Description     = $Description
    }
    Add-Member -InputObject $Loader -MemberType ScriptMethod -Name Load -Value {
        param($sender, $e)
        # Split the text box areas 50/50 of the parent container size
        $this.OutputContainer.SplitterDistance = $this.OutputContainer.Width / 2

        $this.CommandOutput.BringToFront()
        $this.ExpectedOutput.BringToFront()

        $this.DetailLayout.BringToFront()
        $this.DeviceDetail.BringToFront()
        $this.RuleDetail.BringToFront()
        $this.Description.BringToFront()
    }
    [Void]$OnLoad.Add($Loader)
}

function Set-Content {
    param(
        [Parameter(Mandatory = $true)]
            [Object]
            $Data
    )
    
    $DetailContainer.Data = $Data

    $CommandOutput.Text  = ($Data.Results  -replace ("`r", "`n") -replace ("`n`n", "`n") -replace ("`n", "`r`n")).Trim()
    $ExpectedOutput.Text = ($Data.Expected -replace ("`r", "`n") -replace ("`n`n", "`n") -replace ("`n", "`r`n")).Trim()

    $DeviceInfo = ("Hostname: {0}`r`nIPv4: {1}`r`nDevice Type: {2}" -f
        $Data.Hostname,
        $Data.Device,
        $Data.Device_Type)

    $DeviceDetail.Text = $DeviceInfo

    $RuleInfo = ("Validtion Command: {0}`r`nCategory: {1}`r`nFinding: {2}`r`nValidated Time: {3}" -f
        $Data.Command,
        $Data.Category,
        $Data.Findings,
        ([DateTime]::UtcNow.ToShortDateString() + " " + [DateTime]::UtcNow.ToShortTimeString()))

    $RuleDetail.Text = $RuleInfo

    $Description.Text = $Data.NetId
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
$BaseContainer = New-Object System.Windows.Forms.TabPage
    $BaseContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $BaseContainer.Text = "Details"

    # Registered With Parent TabContainer by Register-Components

$DetailContainer = New-Object System.Windows.Forms.TableLayoutPanel

    $DetailContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $DetailContainer.AutoSize = $true
    $DetailContainer.RowCount = 2

    # Button Section
    [Void]$DetailContainer.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $DetailContainer.RowStyles[0].SizeType = [System.Windows.Forms.SizeType]::Absolute
    $DetailContainer.RowStyles[0].Height = 30

    # Rule Detailed Description Span Row
    [Void]$DetailContainer.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $DetailContainer.RowStyles[1].SizeType = [System.Windows.Forms.SizeType]::Percent
    $DetailContainer.RowStyles[1].Height = 100

    # Static Property for tracking current NetId being viewed
    Add-Member -InputObject $DetailContainer -MemberType NoteProperty -Name Data -Value $null

    $BaseContainer.Controls.Add( $DetailContainer )

# Compliance Detail Section Button Bar
& {
    $ViewerButton = New-Object System.Windows.Forms.Button
    $ViewerButton.Dock = [System.Windows.Forms.DockStyle]::Left
    $ViewerButton.Text = "Open STIGViewer"
    $ViewerButton.Width = 125
    $ViewerButton.Height = 22
    $ViewerButton.Add_Click({
        $stig = $DetailContainer.Data.Device_Type
        $m = [System.Text.RegularExpressions.Regex]::Match($DetailContainer.Data.NetId, '([^\s]+) -')
        $id = $m.Groups[1].Value

        $viewer = Get-Viewer $id $stig
        
        [Void]$viewer.Show($MainForm)
    })

    $ButtonPanel = New-Object System.Windows.Forms.Panel
    $ButtonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ButtonPanel.BackColor = [System.Drawing.Color]::White
    $ButtonPanel.Controls.Add($ViewerButton)

    $DetailContainer.Controls.Add($ButtonPanel, 0, 0)
}

###############################################################################
### Validation Scan Command Output
$RightContainer = New-Object System.Windows.Forms.SplitContainer
    $RightContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $RightContainer.Orientation = [System.Windows.Forms.Orientation]::Horizontal

    $DetailContainer.Controls.Add($RightContainer, 0, 1)

$OutputContainer = New-Object System.Windows.Forms.SplitContainer
    $OutputContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $OutputContainer.Orientation = [System.Windows.Forms.Orientation]::Vertical

    $RightContainer.Panel1.Controls.Add( $OutputContainer )

    $CommandOutput = New-Object System.Windows.Forms.TextBox
        $CommandOutput.Dock = [System.Windows.Forms.DockStyle]::Fill
        $CommandOutput.Multiline = $true
        $CommandOutput.WordWrap = $false
        $CommandOutput.ReadOnly = $true
        $CommandOutput.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $CommandOutput.BackColor = [System.Drawing.Color]::White
        $CommandOutput.Font = New-Object System.Drawing.Font("Lucida Console", 12)
        $CommandOutput.Text = "This is the command output text area."

    $OutputContainer.Panel1.Controls.Add( $CommandOutput )

    # Command Output Label (Scope Protection)
    & {
        $label = New-Object System.Windows.Forms.Label
            $label.Dock = [System.Windows.Forms.DockStyle]::Top
            $label.BackColor = [System.Drawing.Color]::AliceBlue
            $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $label.Text = "Verification Command Output"

        $OutputContainer.Panel1.Controls.Add( $label )
    }

    $ExpectedOutput = New-Object System.Windows.Forms.TextBox
        $ExpectedOutput.Dock = [System.Windows.Forms.DockStyle]::Fill
        $ExpectedOutput.Multiline = $true
        $ExpectedOutput.WordWrap = $false
        $ExpectedOutput.ReadOnly = $true
        $ExpectedOutput.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $ExpectedOutput.BackColor = [System.Drawing.Color]::White
        $ExpectedOutput.Font = New-Object System.Drawing.Font("Lucida Console", 12)
        $ExpectedOutput.Text = "This is the expected output text area."

    $OutputContainer.Panel2.Controls.Add( $ExpectedOutput )

    # Expected Output Label (Scope Protection)
    & {
        $label = New-Object System.Windows.Forms.Label
            $label.Dock = [System.Windows.Forms.DockStyle]::Top
            $label.BackColor = [System.Drawing.Color]::AliceBlue
            $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $label.Text = "Expected Command Output"

        $OutputContainer.Panel2.Controls.Add( $label )
    }

###############################################################################
### Node and Security Rule Details

## Base Layout ----------------------------------------------------------------
$DetailLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $DetailLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $DetailLayout.AutoSize = $true
    $DetailLayout.RowCount = 2
    $DetailLayout.ColumnCount = 2

    # Device Info Column
    [Void]$DetailLayout.ColumnStyles.Add( (New-Object System.Windows.Forms.ColumnStyle) )
    $DetailLayout.ColumnStyles[0].SizeType = [System.Windows.Forms.SizeType]::Percent
    $DetailLayout.ColumnStyles[0].Width = 50

    # Rule Info Column
    [Void]$DetailLayout.ColumnStyles.Add( (New-Object System.Windows.Forms.ColumnStyle) )
    $DetailLayout.ColumnStyles[1].SizeType = [System.Windows.Forms.SizeType]::Percent
    $DetailLayout.ColumnStyles[1].Width = 50

    # Device Description and Rule Brief Description Row
    [Void]$DetailLayout.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $DetailLayout.RowStyles[0].SizeType = [System.Windows.Forms.SizeType]::Absolute
    $DetailLayout.RowStyles[0].Height = 175

    # Rule Detailed Description Span Row
    [Void]$DetailLayout.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $DetailLayout.RowStyles[1].SizeType = [System.Windows.Forms.SizeType]::Percent
    $DetailLayout.RowStyles[1].Height = 100

    $RightContainer.Panel2.Controls.Add( $DetailLayout )

## Device Information Panel ---------------------------------------------------
$DevicePanel = New-Object System.Windows.Forms.Panel
    $DevicePanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $DetailLayout.Controls.Add($DevicePanel, 0, 0)

    $DeviceDetail = New-Object System.Windows.Forms.TextBox
        $DeviceDetail.Dock = [System.Windows.Forms.DockStyle]::Fill
        $DeviceDetail.Multiline = $true
        $DeviceDetail.WordWrap = $false
        $DeviceDetail.ReadOnly = $true
        $DeviceDetail.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $DeviceDetail.BackColor = [System.Drawing.Color]::White
        $DeviceDetail.Font = New-Object System.Drawing.Font($DeviceDetail.Font.Name, 12)
        $DeviceDetail.Text = "This is the security baseline device detail text area."

    $DevicePanel.Controls.Add( $DeviceDetail )

    # Device Detail Label (Scope Protection)
    & {
        $label = New-Object System.Windows.Forms.Label
            $label.Dock = [System.Windows.Forms.DockStyle]::Top
            $label.BackColor = [System.Drawing.Color]::AliceBlue
            $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $label.Text = "Node Device Information"
        
        $DevicePanel.Controls.Add( $label )
    }

## Security Rule Panel --------------------------------------------------------
$RulePanel = New-Object System.Windows.Forms.Panel
    $RulePanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $DetailLayout.Controls.Add($RulePanel, 1, 0)

    $RuleDetail = New-Object System.Windows.Forms.TextBox
        $RuleDetail.Dock = [System.Windows.Forms.DockStyle]::Fill
        $RuleDetail.Multiline = $true
        $RuleDetail.WordWrap = $false
        $RuleDetail.ReadOnly = $true
        $RuleDetail.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $RuleDetail.BackColor = [System.Drawing.Color]::White
        $RuleDetail.Font = New-Object System.Drawing.Font($RuleDetail.Font.Name, 12)
        $RuleDetail.Text = "This is the security baseline rule detail text area."

        $RulePanel.Controls.Add($RuleDetail)

    # Rule Detail Label (Scope Protection)
    & {
        $label = New-Object System.Windows.Forms.Label
            $label.Dock = [System.Windows.Forms.DockStyle]::Top
            $label.BackColor = [System.Drawing.Color]::AliceBlue
            $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $label.Text = "Rule Information"

        $RulePanel.Controls.Add($label)
    }

## Description Panel ----------------------------------------------------------
$DescriptionPanel = New-Object System.Windows.Forms.Panel
    $DescriptionPanel.Dock = [System.Windows.Forms.DockStyle]::Fill

    $DetailLayout.Controls.Add($DescriptionPanel, 0, 1)
    $DetailLayout.SetColumnSpan($DescriptionPanel, 2)

    $Description = New-Object System.Windows.Forms.TextBox
        $Description.Dock = [System.Windows.Forms.DockStyle]::Fill
        $Description.Multiline = $true
        $Description.WordWrap = $true
        $Description.ReadOnly = $true
        $Description.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
        $Description.BackColor = [System.Drawing.Color]::White
        $Description.Font = New-Object System.Drawing.Font($Description.Font.Name, 12)
        $Description.Text = "This is the security baseline rule description text area."

    $DescriptionPanel.Controls.Add($Description)

    # Description Label (Scope Protection)
    & {
        $label = New-Object System.Windows.Forms.Label
            $label.Dock = [System.Windows.Forms.DockStyle]::Top
            $label.BackColor = [System.Drawing.Color]::AliceBlue
            $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleCenter
            $label.Text = "Rule Description"

        $DescriptionPanel.Controls.Add($label)
    }