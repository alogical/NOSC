<#
.SYNOPSIS
    Baseline security compliance viewer and reporting.

.DESCRIPTION
    Windows GUI components for managing baseline security compliance data.

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
            [System.Windows.Forms.Control]$Source,

        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]$OnLoad
    )
    
    [Void]$Parent.TabPages.Add($ComplianceReportTab)
    Add-Member -InputObject $BuildReportButton -MemberType NoteProperty -Name Source -Value $Source
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

# Compliance Report Tab
$ComplianceReportTab = New-Object System.Windows.Forms.TabPage
    $ComplianceReportTab.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComplianceReportTab.Text = "Report"

    # Registered With Parent TabContainer by Register-Components

# Layout
$ComplianceReportContainer = New-Object System.Windows.Forms.TableLayoutPanel
    $ComplianceReportContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ComplianceReportContainer.AutoSize = $true
    $ComplianceReportContainer.RowCount = 2

    # Button Section
    [Void]$ComplianceReportContainer.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $ComplianceReportContainer.RowStyles[0].SizeType = [System.Windows.Forms.SizeType]::Absolute
    $ComplianceReportContainer.RowStyles[0].Height = 30

    # Rule Detailed Description Span Row
    [Void]$ComplianceReportContainer.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $ComplianceReportContainer.RowStyles[1].SizeType = [System.Windows.Forms.SizeType]::Percent
    $ComplianceReportContainer.RowStyles[1].Height = 100

    [void]$ComplianceReportTab.Controls.Add( $ComplianceReportContainer )

# Report Builder
$ReportTextBox = New-Object System.Windows.Forms.TextBox
    $ReportTextBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ReportTextBox.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $ReportTextBox.Multiline = $true
    $ReportTextBox.WordWrap = $false
    $ReportTextBox.ReadOnly = $true
    $ReportTextBox.Font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericMonospace.Name, 12)
    
    [void]$ComplianceReportContainer.Controls.Add($ReportTextBox, 0, 1)

$BuildReportButton = New-Object System.Windows.Forms.Button
    $BuildReportButton.Dock = [System.Windows.Forms.DockStyle]::Left
    $BuildReportButton.Text = "Build Report" 
    $BuildReportButton.Height = 22

    [void]$BuildReportButton.Add_Click({
    # Source reference set by Initialize-Components [Compliance.BaseContainer]
        if ($this.Source.Tree.Display.DataNodes -eq $null) {
            $this.DisplayBox.Text = New-Report $this.Source.Data
        }
        else {
            $this.DisplayBox.Text = New-Report $this.Source.Tree.Display.GetChecked()
        }
    })

    Add-Member -InputObject $BuildReportButton -MemberType NoteProperty -Name DisplayBox -Value $ReportTextBox

$ButtonPanel = New-Object System.Windows.Forms.Panel
    $ButtonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ButtonPanel.BackColor = [System.Drawing.Color]::White

    [void]$ButtonPanel.Controls.Add($BuildreportButton)

    [void]$ComplianceReportContainer.Controls.Add($ButtonPanel, 0, 0)

function New-Report ($data) {
    $CommandState = @{
        'Execution Successful'                                                      = 0
        'Device not reachable'                                                      = 0 # Failures
        'No validation command defined'                                             = 0 # Failures
        'Operation timed out'                                                       = 0 # Failures
        'Invalid input or command'                                                  = 0 # Failures
        'Remote server is not responding to commands, or synchronization was lost.' = 0 # Failures
    }
    $Findings         = @{}
    $CategoryFindings = @{}
    $Unreachable      = @{}
    $HostStatus       = @{}
    $NetIdStatus      = @{}
    $HostnameMap      = @{}
        
    # Count the results of the scan
    $UnreachableWidth = 0
    foreach ($record in $data) {

        # Host Status
        if (!$HostStatus.ContainsKey($record.Hostname)) {
            $HostStatus.Add($record.Hostname, @{})
            $HostnameMap.Add($record.Hostname, $record.Device)
        }

        # NetId Statistics
        if (!$NetIdStatus.ContainsKey($record.NetId)) {
            $NetIdStatus.Add($record.NetId, @{})
        }

        # Category Statistics
        if (!$CategoryFindings.ContainsKey($record.Category)) {
            $CategoryFindings.Add($record.Category, @{})
        }

        # Compliance Findings
        $Findings[$record.Findings]++
        $HostStatus[$record.Hostname][$record.Findings]++
        $NetIdStatus[$record.NetId][$record.Findings]++
        $CategoryFindings[$record.Category][$record.Findings]++
            
        # Access Rates, Command Execution Success
        if ($CommandState.ContainsKey($record.Results)) {
            $CommandState[$record.Results]++

            if ($record.Results -eq 'Device not reachable') {

                if (!$Unreachable.ContainsKey($record.Hostname)) {

                    $Unreachable.Add($record.Hostname, $record.Device)

                    if ($record.Hostname.Length -gt $UnreachableWidth) {
                        $UnreachableWidth = $record.Hostname.Length
                    }
                }
            }
        }
        else {
            $CommandState['Execution Successful']++
        }

        # Report Reliability Statistics
        if ($record.Results -eq 'Operation timed out') {
            $HostStatus[$record.Hostname]['Operation timed out']++
            $NetIdStatus[$record.NetId]['Operation timed out']++
        }

        if ($record.Results -eq 'Invalid input or command') {
            $HostStatus[$record.Hostname]['Invalid input or command']++
            $NetIdStatus[$record.NetId]['Invalid input or command']++
        }

        if ($record.Results -eq 'Remote server is not responding to commands, or synchronization was lost.') {
            $HostStatus[$record.Hostname]['Synchronization lost']++
            $NetIdStatus[$record.NetId]['Synchronization lost']++
        }
    }

    # Counter Name Widths
    $CommandStateWidth = 0
    foreach ($s in $CommandState.Keys) {
        if ($s.Length -gt $CommandStateWidth) {
            $CommandStateWidth = $s.Length
        }
    }
    $CommandStateWidth += 2

    $FindingsWidth = 0
    foreach ($s in $Findings.Keys) {
        if ($s.Length -gt $FindingsWidth) {
            $FindingsWidth = $s.Length
        }
    }
    $FindingsWidth += 2
        
    $HostnameWidth = 0
    foreach ($s in $HostnameMap.Keys) {
        if ($s.Length -gt $HostnameWidth) {
            $HostnameWidth = $s.Length
        }
    }
    $HostnameWidth += 2

    $NetIdWidth = 0
    foreach ($s in $NetIdStatus.Keys) {
        if ($s.Length -gt $NetIdWidth) {
            $NetIdWidth = $s.Length
        }
    }
    $NetIdWidth += 2

    $StatWidth = 24
    if ($FindingsWidth -gt $StatWidth) {
        $StatWidth = $FindingsWidth
    }
    $StatWidth += 2
    
    # Format Report
    $report = New-Object System.Text.StringBuilder

        [Void]$report.AppendLine("COMMAND SUCCESS RATE:")
    $Sorted = $CommandState.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $Sorted) {
        [Void]$report.AppendLine( ("`t{0}{1} {2}" -f $pair.Key, ('.' * ($CommandStateWidth - $pair.Key.Length)), $pair.Value))
    }

    [Void]$report.AppendLine("`r`n")
        
    [Void]$report.AppendLine("COMPLIANCE RATE:")
    $Sorted = $Findings.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $Sorted) {
        [Void]$report.AppendLine( ("`t{0}{1} {2}" -f $pair.Key, ('.' * ($FindingsWidth - $pair.Key.Length)), $pair.Value))
    }

    [Void]$report.AppendLine("`r`n")
        
    ###############################################################################
    # # NOTE: Below code creates a table based on the following layout:
    #  
    # CATEGORY COMPLIANCE STATUS:
    # ............51.....................................Non-Compliant....9....Manual
    # ............21.......Compliant....Non-Compliant........POA&M.........Check Required
    # ........Category 1...7...x......14......x.......16.......x.......17........x
    #                   .......8..............23...............40................58
    ###############################################################################
    [Void]$report.AppendLine("CATEGORY COMPLIANCE STATUS:")
    [Void]$report.AppendLine( (" " * 51 + "Non-Compliant" + " " * 9 + "Manual") )
    [Void]$report.AppendLine( (" " * 21 + "Compliant" + " " * 4 + "Non-Compliant" + " " * 8 + "POA&M" + " " * 9 + "Check Required") )
    $Sorted = $CategoryFindings.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $Sorted) {

        [String]$Comply    = $pair.Value['Compliant']
        [String]$NonComply = $pair.Value['Non-Compliant']
        [String]$POAM      = $pair.Value['Non-Compliant with POAM']
        [String]$Manual    = $pair.Value['Manual check required']

        Write-Debug "Comply: $Comply  NonComply: $NonComply  Manual: $Manual"

        $len0 = $Comply.Length
        $offset0 = [System.Math]::Round($len0 / 2, [System.MidpointRounding]::AwayFromZero)
        $remain0 = $len0 - $offset0

        $len1 = $NonComply.Length
        $offset1 = [System.Math]::Round($len1 / 2, [System.MidpointRounding]::AwayFromZero)
        $remain1 = $len1 - $offset1

        $len2 = $POAM.Length
        $offset2 = [System.Math]::Round($len2 / 2, [System.MidpointRounding]::AwayFromZero)
        $remain2 = $len2 - $offset1

        $len3 = $Manual.Length
        $offset3 = [System.Math]::Round($len3 / 2, [System.MidpointRounding]::AwayFromZero)

        # Adjust remainder for empty values
        switch (0) {
            $len0 { $remain0++ }
            $len1 { $remain1++ }
            $len2 { $remain2++ }
        }

        [Void]$report.AppendLine( ("`tCategory {0}{1}{2}{3}{4}{5}{6}{7}{8}" -f 
            $pair.Key,                          # {0}
            (" " * (8 - $offset0)),             # {1} Offset..Default No. of spaces to center (8)
            $Comply,                            # {2} Compliant Count

            (" " * (15 - $remain0 - $offset1)), # {3} Offset..Default No. of spaces to center (15)
            $NonComply,                         # {4} Non-Compliant Count

            (" " * (17 - $remain1 - $offset2)), # {5} Offset..Default No. of spaces to center (17)
            $POAM,                              # {6} Non-Compliant with POA&M Count

            (" " * (18 - $remain2 - $offset3)), # {7} Offset..Default No. of spaces to center (18)
            $Manual)                            # {8} Manual Check Count
        )
    }

    [Void]$report.AppendLine("`r`n")

    [Void]$report.AppendLine("HOST STATISTICS:")
        [Void]$report.AppendLine( ("`tTotal Hosts: {0}" -f $HostStatus.Count) )

    [Void]$report.AppendLine("`r`n")

    [Void]$report.AppendLine("UNREACHABLE HOSTS:")
    $Sorted = $Unreachable.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $Sorted) {
        [Void]$report.AppendLine( ("`t{0}{1} {2}" -f $pair.Key, ('.' * ($UnreachableWidth - $pair.Key.Length)), $pair.Value))
    }

    [Void]$report.AppendLine("`r`n")

    [Void]$report.AppendLine("HOST COMPLIANCE:")
    $Sorted = $HostStatus.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $Sorted) {
        [Void]$report.AppendLine( ("`t{0}{1} {2}" -f $pair.Key, ('.' * ($HostnameWidth - $pair.Key.Length)), $HostnameMap[$pair.Key]))

        $SortedStatus = $pair.Value.GetEnumerator() | Sort-Object -Property Key
        foreach ($stat in $SortedStatus) {
            [Void]$report.AppendLine( ("`t`t{0}{1} {2}" -f $stat.Key, ('.' * ($StatWidth - $stat.Key.Length)), $stat.Value))
        }

        [Void]$report.AppendLine('')
    }

    [Void]$report.AppendLine("")

    [Void]$report.AppendLine("NETID COMPLIANCE:")
    $Sorted = $NetIdStatus.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $Sorted) {
        [Void]$report.AppendLine( ("`t{0}" -f $pair.Key) )

        $SortedStatus = $pair.Value.GetEnumerator() | Sort-Object -Property Key
        foreach ($stat in $SortedStatus) {
            [Void]$report.AppendLine( ("`t`t{0}{1} {2}" -f $stat.Key, ('.' * ($StatWidth - $stat.Key.Length)), $stat.Value))
        }

        [Void]$report.AppendLine('')
    }

    return $report.ToString()
}