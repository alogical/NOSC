<#
.SYNOPSIS
    Baseline security compliance viewer and reporting.

.DESCRIPTION
    Windows components for displaying security basline compliance statistics.

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
            [System.Windows.Forms.Control]
            $Source,

        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $OnLoad
    )
    
    [Void]$Parent.TabPages.Add($BaseContainer)
    Add-Member -InputObject $BuildReport -MemberType NoteProperty -Name Source -Value $Source
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

###############################################################################
### Compliance Report Tab Window Components
$BaseContainer = New-Object System.Windows.Forms.TabPage
    $BaseContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $BaseContainer.Text = "Report"

    # Registered With Parent TabContainer by Register-Components

## Layout ---------------------------------------------------------------------
$ContainerLayout = New-Object System.Windows.Forms.TableLayoutPanel
    $ContainerLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ContainerLayout.AutoSize = $true
    $ContainerLayout.RowCount = 2

    # Button Section
    [Void]$ContainerLayout.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $ContainerLayout.RowStyles[0].SizeType = [System.Windows.Forms.SizeType]::Absolute
    $ContainerLayout.RowStyles[0].Height = 30

    # Rule Detailed Description Span Row
    [Void]$ContainerLayout.RowStyles.Add( (New-Object System.Windows.Forms.RowStyle) )
    $ContainerLayout.RowStyles[1].SizeType = [System.Windows.Forms.SizeType]::Percent
    $ContainerLayout.RowStyles[1].Height = 100

    [void]$BaseContainer.Controls.Add( $ContainerLayout )

## Report Output Display ------------------------------------------------------
$Report = New-Object System.Windows.Forms.TextBox
    $Report.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Report.ScrollBars = [System.Windows.Forms.ScrollBars]::Both
    $Report.Multiline = $true
    $Report.WordWrap = $false
    $Report.ReadOnly = $true
    $Report.Font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericMonospace.Name, 12)
    
    [void]$ContainerLayout.Controls.Add($Report, 0, 1)

## Build Report Button --------------------------------------------------------
$BuildReport = New-Object System.Windows.Forms.Button
    $BuildReport.Dock = [System.Windows.Forms.DockStyle]::Left
    $BuildReport.Text = "Build Report"
    $BuildReport.Height = 22

    [void]$BuildReport.Add_Click({
        # Source reference set by Initialize-Components [Compliance.BaseContainer]
        if ($this.Source.Tree.Display.DataNodes -eq $null) {
            $this.DisplayBox.Text = New-Report $this.Source.Data
        }
        else {
            $this.DisplayBox.Text = New-Report $this.Source.Tree.Display.GetChecked()
        }
    })

    Add-Member -InputObject $BuildReport -MemberType NoteProperty -Name DisplayBox -Value $Report

## Button Layout Container ----------------------------------------------------
$ButtonPanel = New-Object System.Windows.Forms.Panel
    $ButtonPanel.Dock = [System.Windows.Forms.DockStyle]::Fill
    $ButtonPanel.BackColor = [System.Drawing.Color]::White

    [void]$ButtonPanel.Controls.Add($BuildReport)

    [void]$ContainerLayout.Controls.Add($ButtonPanel, 0, 0)

###############################################################################
### Report Processing and Formatting
function New-Report ($Data) {
    $commandState = @{
        'Execution Successful'                                                      = 0
        'Device not reachable'                                                      = 0 # Failures
        'No validation command defined'                                             = 0 # Failures
        'Operation timed out'                                                       = 0 # Failures
        'Invalid input or command'                                                  = 0 # Failures
        'Remote server is not responding to commands, or synchronization was lost.' = 0 # Failures
    }
    $findings    = @{}
    $catagories  = @{}
    $unreachable = @{}
    $hosts       = @{}
    $netids      = @{}
    $hostmap     = @{}

    # Counter Name Widths
    $unreachableWidth  = 0
    $commandStateWidth = 0
    $findingsWidth     = 0
    $hostnameWidth     = 0
    $netidWidth        = 0

    # Process the data for the report
    foreach ($record in $Data) {
        # Quick references for frequently used properties
        $f = $record.Findings
        $h = $record.Hostname
        $i = $record.NetId
        $c = $record.Category
        $r = $record.Results

        # Measuring string widths
        if ($h.Length -gt $hostnameWidth) {
            $hostnameWidth = $h.Length
        }

        if ($f.Length -gt $findingsWidth) {
            $findingsWidth = $f.Length
        }

        if ($i.Length -gt $netidWidth) {
            $netidWidth = $i.Length
        }

        # Host Status
        if (!$hosts.ContainsKey($h)) {
            $hosts.Add($h, @{})
            $hostmap.Add($h, $record.Device)
        }

        # NetId Statistics
        if (!$netids.ContainsKey($i)) {
            $netids.Add($i, @{})
        }

        # Category Statistics
        if (!$catagories.ContainsKey($c)) {
            $catagories.Add($c, @{})
        }

        # Compliance Findings by Topic
        $findings[$f]++
        $hosts[$h][$f]++
        $netids[$i][$f]++
        $catagories[$c][$f]++

        # Access Rates, Command Execution Success
        if ($commandState.ContainsKey($r)) {
            $commandState[$r]++

            if ($r -eq 'Device not reachable') {

                if (!$unreachable.ContainsKey($h)) {

                    $unreachable.Add($h, $record.Device)

                    if ($h.Length -gt $unreachableWidth) {
                        $unreachableWidth = $h.Length
                    }
                }
            }
        }
        else {
            $commandState['Execution Successful']++
        }

        # Report Reliability Statistics
        if ($r -eq 'Operation timed out') {
            $hosts[$h]['Operation timed out']++
            $netids[$i]['Operation timed out']++
        }

        if ($r -eq 'Invalid input or command') {
            $hosts[$h]['Invalid input or command']++
            $netids[$i]['Invalid input or command']++
        }

        if ($r -eq 'Remote server is not responding to commands, or synchronization was lost.') {
            $hosts[$h]['Synchronization lost']++
            $netids[$i]['Synchronization lost']++
        }
    }

    # Counter Name Width Adjustments
    foreach ($s in $commandState.Keys) {
        if ($s.Length -gt $commandStateWidth) {
            $commandStateWidth = $s.Length
        }
    }
    $commandStateWidth += 2
    $findingsWidth     += 2
    $hostnameWidth     += 2
    $netidWidth        += 2

    $statisticWidth = 24
    if ($findingsWidth -gt $statisticWidth) {
        $statisticWidth = $findingsWidth
    }
    $statisticWidth += 2
    
    ### Format Report ---------------------------------------------------------
    $report = New-Object System.Text.StringBuilder

    [Void]$report.AppendLine("COMMAND SUCCESS RATE:")
    $sorted = $commandState.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $sorted) {
        [Void]$report.AppendLine( ("`t{0}{1} {2}" -f $pair.Key, ('.' * ($commandStateWidth - $pair.Key.Length)), $pair.Value))
    }

    [Void]$report.AppendLine("`r`n")
        
    [Void]$report.AppendLine("COMPLIANCE RATE:")
    $sorted = $findings.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $sorted) {
        [Void]$report.AppendLine( ("`t{0}{1} {2}" -f $pair.Key, ('.' * ($findingsWidth - $pair.Key.Length)), $pair.Value))
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
    $sorted = $catagories.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $sorted) {

        [String]$comply    = $pair.Value['Compliant']
        [String]$nonComply = $pair.Value['Non-Compliant']
        [String]$poam      = $pair.Value['Non-Compliant with POAM']
        [String]$manual    = $pair.Value['Manual check required']

        Write-Debug "Comply: $comply  Non-Comply: $nonComply  Manual: $manual"

        $len0 = $comply.Length
        $offset0 = [System.Math]::Round($len0 / 2, [System.MidpointRounding]::AwayFromZero)
        $remain0 = $len0 - $offset0

        $len1 = $nonComply.Length
        $offset1 = [System.Math]::Round($len1 / 2, [System.MidpointRounding]::AwayFromZero)
        $remain1 = $len1 - $offset1

        $len2 = $poam.Length
        $offset2 = [System.Math]::Round($len2 / 2, [System.MidpointRounding]::AwayFromZero)
        $remain2 = $len2 - $offset1

        $len3 = $manual.Length
        $offset3 = [System.Math]::Round($len3 / 2, [System.MidpointRounding]::AwayFromZero)

        # Adjust remainder for empty values
        switch (0) {
            $len0 { $remain0++ }
            $len1 { $remain1++ }
            $len2 { $remain2++ }
        }

        [Void]$report.AppendLine( ("`tCategory {0}{1}{2}{3}{4}{5}{6}{7}{8}" -f 
            $pair.Key,                          # {0} Category Name
            (" " * (8 - $offset0)),             # {1} Offset..Default No. of spaces to center (8)
            $comply,                            # {2} Compliant Count

            (" " * (15 - $remain0 - $offset1)), # {3} Offset..Default No. of spaces to center (15)
            $nonComply,                         # {4} Non-Compliant Count

            (" " * (17 - $remain1 - $offset2)), # {5} Offset..Default No. of spaces to center (17)
            $poam,                              # {6} Non-Compliant with POA&M Count

            (" " * (18 - $remain2 - $offset3)), # {7} Offset..Default No. of spaces to center (18)
            $manual)                            # {8} Manual Check Count
        )
    }

    [Void]$report.AppendLine("`r`n")

    [Void]$report.AppendLine("HOST STATISTICS:")
        [Void]$report.AppendLine( ("`tTotal Hosts........ {0}" -f $hosts.Count) )
        [Void]$report.AppendLine( ("`tUnreachable Hosts.. {0}" -f $unreachable.Count) )

    [Void]$report.AppendLine("`r`n")

    [Void]$report.AppendLine("UNREACHABLE HOSTS:")
    $sorted = $unreachable.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $sorted) {
        [Void]$report.AppendLine( ("`t{0}{1} {2}" -f $pair.Key, ('.' * ($unreachableWidth - $pair.Key.Length)), $pair.Value))
    }

    [Void]$report.AppendLine("`r`n")

    [Void]$report.AppendLine("HOST COMPLIANCE:")
    $sorted = $hosts.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $sorted) {
        [Void]$report.AppendLine( ("`t{0}{1} {2}" -f $pair.Key, ('.' * ($hostnameWidth - $pair.Key.Length)), $hostmap[$pair.Key]))

        $sortedStatus = $pair.Value.GetEnumerator() | Sort-Object -Property Key
        foreach ($stat in $sortedStatus) {
            [Void]$report.AppendLine( ("`t`t{0}{1} {2}" -f $stat.Key, ('.' * ($statisticWidth - $stat.Key.Length)), $stat.Value))
        }

        [Void]$report.AppendLine('')
    }

    [Void]$report.AppendLine("")

    [Void]$report.AppendLine("NETID COMPLIANCE:")
    $sorted = $netids.GetEnumerator() | Sort-Object -Property Key
    foreach ($pair in $sorted) {
        [Void]$report.AppendLine( ("`t{0}" -f $pair.Key) )

        $sortedStatus = $pair.Value.GetEnumerator() | Sort-Object -Property Key
        foreach ($stat in $sortedStatus) {
            [Void]$report.AppendLine( ("`t`t{0}{1} {2}" -f $stat.Key, ('.' * ($statisticWidth - $stat.Key.Length)), $stat.Value))
        }

        [Void]$report.AppendLine('')
    }

    return $report.ToString()
}