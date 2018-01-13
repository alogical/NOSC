<#
.SYNOPSIS
    STIG rule viewer.

.DESCRIPTION
    Generates window with STIG rule data for viewing.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>

Add-Type -AssemblyName System.IO.Compression.FileSystem
Add-Type -AssemblyName System.Windows.Forms

###############################################################################
###############################################################################
## SECTION 01 ## PUBILC FUNCTIONS AND VARIABLES
##
## Pass-thru Export-ModuleMember calls export all functions and variables
## to the global session that were passed to this modules session from nested
## modules.
###############################################################################
###############################################################################
function Get-Viewer {
    param(
        # STIG Rule ID
        [Parameter(Mandatory = $true)]
            [String]$id,
    
        [Parameter(Mandatory = $true)]
            [ValidateSet(
                'L2',
                'Standard L3',
                'Router',
                'Perimeter L3',
                'Perimeter/Router',
                'VPN/Router'
            )]
            [String]$STIG
    )

    # STIG ZIP ARCHIVES
    $L3_PERIMETER_ARCHIVE      = "U_Network_Perimeter_Router_L3_Switch_V8R24_STIG.zip"
    $L3_INFRASTRUCTURE_ARCHIVE = "U_Network_Infrastructure_Router_L3_Switch_V8R21_STIG.zip"
    $L3_IPSEC_VPN_ARCHIVE      = "U_Network_IPSec_VPN_Gateway_V1R11_STIG.zip"
    $L2_INFRASTRUCTURE_ARCHIVE = "U_Network_L2_Switch_V8R20_STIG.zip"

    # STIG FOLDERS
    $L3_PERIMETER_ROUTER     = "U_Network_Perimeter_Router_Cisco_V8R24_Manual_STIG"
    $L3_PERIMETER_SWITCH     = "U_Network_Perimeter_L3_Switch_Cisco_V8R24_Manual_STIG"
    $L3_INFRASTRUCURE_ROUTER = "U_Network_Infrastructure_Router_Cisco_V821_Manual_STIG"
    $L3_INFRASTRUCURE_SWITCH = "U_Network_Infrastructure_L3_Switch_Cisco_V8R21_Manual_STIG"
    $L3_IPSEC_VPN_GATEWAY    = "U_Network_IPSec_VPN_Gateway_V1R11_Manual_STIG"
    $L2_INFRASTRUCURE_SWITCH = "U_Network_L2_Switch_Cisco_V8R20_Manual_STIG"

    # SWITCH STIG PARAMETER FOR AN ARCHIVE STRING
    #// SWITCH STATEMENT HERE //
    switch -Regex ($STIG) {
        'L2' {
            $archive = "$Path\$L2_INFRASTRUCTURE_ARCHIVE"
            $entry = Resolve-ArchivePath $L2_INFRASTRUCURE_SWITCH
        }

        'Standard L3' {
            $archive = "$Path\$L3_INFRASTRUCTURE_ARCHIVE"
            $entry = Resolve-ArchivePath $L3_INFRASTRUCURE_SWITCH
        }

        'Router' {
            $archive = "$Path\$L3_INFRASTRUCTURE_ARCHIVE"
            $entry = Resolve-ArchivePath $L3_INFRASTRUCURE_ROUTER
        }

        'Perimeter L3' {
            $archive = "$Path\$L3_PERIMETER_ARCHIVE"
            $entry = Resolve-ArchivePath $L3_PERIMETER_SWITCH
        }

        'Perimeter/Router' {
            $archive = "$Path\$L3_PERIMETER_ARCHIVE"
            $entry = Resolve-ArchivePath $L3_PERIMETER_ROUTER
        }

        'VPN/Router' {
            $archive = "$Path\$L3_IPSEC_VPN_ARCHIVE"
            $entry = Resolve-ArchivePath $L3_IPSEC_VPN_GATEWAY
        }
    }

    $doc = Open-XmlArchive $archive $entry
    return (New-Viewer $doc $id)
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
$Path  = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

# BUILD XML DOCUMENT NAME PATH
function Resolve-ArchivePath ([string]$STIG) {
    # Truncate _STIG
    $base = $STIG.SubString(0, $STIG.Length - 5)
    return ("{0}/{1}{2}" -f $STIG, $base, "-xccdf.xml")
}

# SEARCH FOR XML STIG ENTRY AND RETURN XML DOCUMENT
function Open-XmlArchive([string]$archive, [string]$path) {
    
    # Open Zip Archive For Reading
    [System.IO.Compression.ZipArchive]$zip = [System.IO.Compression.ZipFile]::OpenRead($archive)

    # Locate Requested Entry and Open Stream for Reading
    Write-Debug "Scanning archive... $path"
    ForEach ($entry in $zip.Entries) {
        Write-Debug $entry.FullName
        if ($entry.FullName -eq $path) {
            Write-Debug "Found entry..."
            $stream = $entry.Open()
            break
        }
    }

    # FILE CONTENT BUFFER <-- FILE STREAM READ()
    $buffer = New-Object Byte[] 512
    $sb     = New-Object System.Text.StringBuilder
    $bytes  = 1

    # READ ENTRY STREAM
    while ($stream.CanRead -and $bytes -gt 0) {
        $bytes = $stream.Read($buffer, 0, $buffer.Length - 1)
        [void]$sb.Append([System.Text.UnicodeEncoding]::UTF8.GetChars($buffer, 0, $bytes))
    }

    # Cleanup
    $stream.Close()
    $zip.Dispose()

    # Parse Data With XMLDOM
    [xml]$xml = $sb.ToString()

    $nsm = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $nsm.AddNamespace('ns', 'http://checklists.nist.gov/xccdf/1.1')
    Add-Member -InputObject $xml -MemberType NoteProperty -Name NamespaceManager -Value $nsm

    return $xml
}

# BUILD NEW WINDOW FOR DISPLAYING THE STIG INFORMATION
function New-Viewer ([object]$doc, [string]$netid) {
    $group = $doc.SelectSingleNode("//ns:Group[ns:Rule/ns:version[text()='$netid']]", $doc.NamespaceManager)
    $rule = $group.SelectSingleNode("ns:Rule", $doc.NamespaceManager)
    $form = New-Object System.Windows.Forms.Form
    $form.Width = 900
    $form.Height = 600

    $form.Text = ("{0} - {1}" -f $netid, $group.SelectSingleNode("ns:title", $doc.NamespaceManager).InnerText)

    $base_container = New-Object System.Windows.Forms.TableLayoutPanel
        $base_container.Dock = [System.Windows.Forms.DockStyle]::Fill

        $base_container.AutoSize = $true
        $base_container.RowCount = 2

        $top_row_style = New-Object System.Windows.Forms.RowStyle
        $top_row_style.SizeType = [System.Windows.Forms.SizeType]::Absolute
        $top_row_style.Height = 30

        $bottom_row_style = New-Object System.Windows.Forms.RowStyle
        $bottom_row_style.SizeType = [System.Windows.Forms.SizeType]::Percent
        $bottom_row_style.Height = 100

        [void]$base_container.RowStyles.Add($top_row_style)
        [void]$base_container.RowStyles.Add($bottom_row_style)

        [void]$form.Controls.Add($base_container)

    $synopsis_text_block = New-Object System.Windows.Forms.TextBox
        $synopsis_text_block.Dock = [System.Windows.Forms.DockStyle]::Top
        $synopsis_text_block.Font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericSansSerif, 12)
        $synopsis_text_block.Text = $rule.SelectSingleNode('ns:title', $doc.NamespaceManager).InnerText
        $synopsis_text_block.ReadOnly = $true

        [void]$base_container.Controls.Add($synopsis_text_block, 0, 0)

    $content_container = New-Object System.Windows.Forms.SplitContainer
        $content_container.Dock = [System.Windows.Forms.DockStyle]::Fill
        $content_container.Orientation = [System.Windows.Forms.Orientation]::Horizontal
        $content_container.SplitterWidth = 5
        $content_container.BackColor = [System.Drawing.Color]::Green

        [void]$base_container.Controls.Add($content_container, 0, 1)

    $content_subcontainer_top = New-Object System.Windows.Forms.SplitContainer
        $content_subcontainer_top.Dock = [System.Windows.Forms.DockStyle]::Fill
        $content_subcontainer_top.Orientation = [System.Windows.Forms.Orientation]::Horizontal
        $content_subcontainer_top.SplitterWidth = 5
        $content_subcontainer_top.BackColor = [System.Drawing.Color]::Green

        [void]$content_container.Panel1.Controls.Add($content_subcontainer_top)
    
    $discussion_text_block = New-Object System.Windows.Forms.TextBox
        $discussion_text_block.Dock = [System.Windows.Forms.DockStyle]::Fill
        $discussion_text_block.Font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericMonospace, 12)
        $discussion_text_block.Multiline = $true
        $discussion_text_block.WordWrap = $true
        $discussion_text_block.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
        $discussion_text_block.ReadOnly = $true
        $discussion_text_block.Text = $rule.SelectSingleNode('ns:description', $doc.NamespaceManager).InnerText
        $discussion_text_block.Text = $discussion_text_block.Text -replace ("`n","`r`n")

        # Open Tag replace regex
        $pattern = '<([^/>]+)>'
        $replace = "`$1`r`n"
        $discussion_text_block.Text = [System.Text.RegularExpressions.Regex]::Replace($discussion_text_block.Text, $pattern, $replace)

        # End Tag replace regex
        $pattern = '</[^>]+>'
        $replace = "`r`n`r`n"
        $discussion_text_block.Text = [System.Text.RegularExpressions.Regex]::Replace($discussion_text_block.Text, $pattern, $replace)

        # End Tag replace regex
        $pattern = 'VulnDiscussion'
        $replace = ""
        $discussion_text_block.Text = [System.Text.RegularExpressions.Regex]::Replace($discussion_text_block.Text, $pattern, $replace)

        [void]$content_subcontainer_top.Panel1.Controls.Add($discussion_text_block)

        $discussion_label = New-Object System.Windows.Forms.Label
            $discussion_label.Text = "Discussion"
            $discussion_label.Dock = [System.Windows.Forms.DockStyle]::Top
            $discussion_label.BackColor = [System.Drawing.Color]::AliceBlue
            $discussion_label.Font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericSansSerif, 16)

        [void]$content_subcontainer_top.Panel1.Controls.Add($discussion_label)

    $check_text_block = New-Object System.Windows.Forms.TextBox
        $check_text_block.Dock = [System.Windows.Forms.DockStyle]::Fill
        $check_text_block.Font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericMonospace, 12)
        $check_text_block.Multiline = $true
        $check_text_block.WordWrap = $true
        $check_text_block.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
        $check_text_block.ReadOnly = $true
        $check_text_block.Text = $rule.SelectSingleNode('ns:check/ns:check-content', $doc.NamespaceManager).InnerText
        $check_text_block.Text = $check_text_block.Text -replace ("`n","`r`n")

        [void]$content_subcontainer_top.Panel2.Controls.Add($check_text_block)

        $check_label = New-Object System.Windows.Forms.Label
            $check_label.Text = "Check Content"
            $check_label.Dock = [System.Windows.Forms.DockStyle]::Top
            $check_label.BackColor = [System.Drawing.Color]::AliceBlue
            $check_label.Font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericSansSerif, 16)

        [void]$content_subcontainer_top.Panel2.Controls.Add($check_label)

    $fix_text_block = New-Object System.Windows.Forms.TextBox
        $fix_text_block.Dock = [System.Windows.Forms.DockStyle]::Fill
        $fix_text_block.Font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericMonospace, 12)
        $fix_text_block.Multiline = $true
        $fix_text_block.WordWrap = $true
        $fix_text_block.ScrollBars = [System.Windows.Forms.ScrollBars]::Vertical
        $fix_text_block.ReadOnly = $true
        $fix_text_block.Text = $rule.SelectSingleNode('ns:fixtext', $doc.NamespaceManager).InnerText
        $fix_text_block.Text = $fix_text_block.Text -replace ("`n","`r`n")

        [void]$content_container.Panel2.Controls.Add($fix_text_block)

        $fix_label = New-Object System.Windows.Forms.Label
            $fix_label.Text = "Fix Text"
            $fix_label.Dock = [System.Windows.Forms.DockStyle]::Top
            $fix_label.BackColor = [System.Drawing.Color]::AliceBlue
            $fix_label.Font = New-Object System.Drawing.Font([System.Drawing.FontFamily]::GenericSansSerif, 16)

        [void]$content_container.Panel2.Controls.Add($fix_label)

    return $form
}