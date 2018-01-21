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

    $Explorer = Initialize-TreeComponents `
         -Window          $Window              `
         -Parent          $Split.Panel1        `
         -MenuStrip       $null                `
         -OnLoad          $OnLoad              `
         -Title           'Explorer'           `
         -Source          $BaseContainer.Data  `
         -ImageList       $ImageList           `
         -TreeDefinition  $TreeViewDefinition  `
         -GroupDefinition $GroupNodeDefinition `
         -NodeDefinition  $DataNodeDefinition

    [Void]$Split.Panel1.Controls.Add($Explorer)

    # Attach reference to the navigation tree object for easy access by child components
    Add-Member -InputObject $BaseContainer -MemberType NoteProperty -Name Explorer -Value $Explorer

    # Register Component Container
    [Void]$Parent.TabPages.Add($BaseContainer)

    # Register Child Components
    Initialize-ReportComponents -Window $Window -Parent $TabContainer -MenuStrip $MenuStrip -Source $BaseContainer -OnLoad $OnLoad
    Initialize-DetailComponents -Window $Window -Parent $TabContainer -MenuStrip $MenuStrip -OnLoad $OnLoad
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
Import-Module "$ModuleInvocationPath\..\SortedTreeView\SortedTreeView.psm1" -Prefix Tree
Import-Module "$ModuleInvocationPath\DetailViewer.psm1" -Prefix Detail
Import-Module "$ModuleInvocationPath\ReportViewer.psm1" -Prefix Report

$ImagePath  = "$ModuleInvocationPath\..\..\resources"

###############################################################################
# Menu Definitions - Registered to component menu strip
$Menu = @{}

### File Menu -------------------------------------------------------------
$Menu.File = @{}
$Menu.File.SaveAsCSV = New-Object System.Windows.Forms.ToolStripMenuItem("CSV", $null, {
    param($sender, $e)

    $Dialog = New-Object System.Windows.Forms.SaveFileDialog
    $Dialog.ShowHelp = $false

    $Dialog.Filter = "Csv File (*.csv)|*.csv"
    if($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        if (Test-Path -LiteralPath $Dialog.FileName) {
            try {
                Move-Item $Dialog.FileName ("{0}.bak" -f $Dialog.FileName)
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to create back up of existing file before saving to prevent data loss.  Please try again.",
                    "Save Compliance Report",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return
            }
        }
        $BaseContainer.Data | Export-Csv $Dialog.FileName -NoTypeInformation
    }
})
$Menu.File.SaveAsCSV.Name = 'CSV'

$Menu.File.SaveAs = New-Object System.Windows.Forms.ToolStripMenuItem("SaveAs", $null, @($Menu.File.SaveAsCSV))
$Menu.File.SaveAs.Name = 'SaveAs'

$Menu.File.Open = New-Object System.Windows.Forms.ToolStripMenuItem("Open", $null, {
    param($sender, $e)
    
    $Dialog = New-Object System.Windows.Forms.OpenFileDialog
    
    <# Fix for dialog script hang bug #>
    $Dialog.ShowHelp = $false
        
    # Dialog Configuration
    $Dialog.Filter = "Compliance Csv File (*.csv)|*.csv"
    $Dialog.Multiselect = $false
        
    # Run Selection Dialog
    if($($Dialog.ShowDialog()) -eq "OK") {
        $Data = Import-Csv $Dialog.FileName

        if ($BaseContainer.Explorer.TreeView.Nodes.Count -gt 0) {
            $BaseContainer.Explorer.TreeView.Nodes.Clear()
        }
    }
    else{
        return
    }

    if ($Data.Count -gt 0) {
        Write-Debug "Processing $($Data.Count) items:
            Data Variable is [$($Data.GetType())]"

        # Filter first data object field names
        $FieldNames = @( 
            ($Data[0] |
                Get-Member -MemberType NoteProperty |
                    Select-Object -Property Name -Unique |
                        % {Write-Output $_.Name})
        )

        $BaseContainer.Explorer.Settings.RegisterFields($FieldNames)

        # Saved reference to the data for later export
        [Void]$BaseContainer.Data.Clear()
        [Void]$BaseContainer.Data.AddRange($Data)
    }
    $BaseContainer.Explorer.Settings.PromptUser()
})
$Menu.File.Open.Name = 'Open'

$Menu.File.Root = New-Object System.Windows.Forms.ToolStripMenuItem("File", $null, @($Menu.File.Open, $Menu.File.SaveAs))
$Menu.File.Root.Name = 'File'

###############################################################################
# Compliance Report Tab Container Definitions
$BaseContainer = New-Object System.Windows.Forms.TabPage
    $BaseContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
    $BaseContainer.Text = "Compliance"

    # Data Source Reference for SortedTreeView Component
    Add-Member -InputObject $BaseContainer -MemberType NoteProperty -Name Data -Value (New-Object System.Collections.ArrayList)

    # Attached to Parent Control by Module Component Registration Function

# Component Layout Containers
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

# Register Menus
$MenuStrip = New-Object System.Windows.Forms.MenuStrip
$MenuStrip.Dock = [System.Windows.Forms.DockStyle]::Fill

    [Void]$MenuStrip.Items.Add($Menu.File.Root)
    [Void]$Layout.Controls.Add($MenuStrip, 0, 0)

$Split = New-Object System.Windows.Forms.SplitContainer
    $Split.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Split.Orientation = [System.Windows.Forms.Orientation]::Vertical

    [Void]$Layout.Controls.Add($Split, 0, 1)

# Compliance Sub Tab Control
$TabContainer = New-Object System.Windows.Forms.TabControl
    $TabContainer.Dock = [System.Windows.Forms.DockStyle]::Fill

    $Split.Panel2.Controls.Add($TabContainer)

$BaseContainer.Controls.Add($Layout)

###############################################################################
# Compliance Data TreeView Configuration

$ImageList = New-Object System.Windows.Forms.ImageList
$ImageList.ColorDepth = [System.Windows.Forms.ColorDepth]::Depth32Bit
$ImageList.ImageSize  = New-Object System.Drawing.Size(16,16)
$ImageList.Images.Add('group',
    [System.Drawing.Icon]::new("$ImagePath\group.ico"))
$ImageList.Images.Add('compliant-comments',
    [System.Drawing.Icon]::new("$ImagePath\compliant-comments.ico"))
$ImageList.Images.Add('compliant',
    [System.Drawing.Icon]::new("$ImagePath\compliant.ico"))
$ImageList.Images.Add('non-compliant',
    [System.Drawing.Icon]::new("$ImagePath\non-compliant.ico"))
$ImageList.Images.Add('non-compliant-poam',
    [System.Drawing.Icon]::new("$ImagePath\non-compliant-poam.ico"))
$ImageList.Images.Add('manual-check',
    [System.Drawing.Icon]::new("$ImagePath\manual-check.ico"))
$ImageList.Images.Add('not-applicable',
    [System.Drawing.Icon]::new("$ImagePath\not-applicable.ico"))
$ImageList.Images.Add('error',
    [System.Drawing.Icon]::new("$ImagePath\error.ico"))

# Parameter Encapsulation Object
$TreeViewDefinition = [PSCustomObject]@{
    # [System.Windows.Forms.TreeView] Properties
    Properties = @{}

    # ScriptMethod Definitions
    Methods    = @{}

    # [System.Windows.Forms.TreeView] Event Handlers
    Handlers   = @{}
}

$TreeViewDefinition.Handlers.AfterSelect = {
    param($sender, $e)

    $node = $sender.SelectedNode
    if ($node.Type -eq "Data") {
        $node.ShowDetail()
    }
}

$TreeViewDefinition.Handlers.KeyDown = {
    Param(
        # sender: The Windows Form object that generated the Load event.
        [Parameter()]
            [System.Windows.Forms.TreeView] $sender,

        # e: The EventArgs object generated by the sender of the event.
        [Parameter()]
            [System.Windows.Forms.KeyEventArgs] $e
    )

    # COMBO KEYPRESS SECTION
    if($e.Control -and $e.KeyCode -eq [System.Windows.Forms.Keys]::F1)
    {
        [System.Windows.Forms.TreeNode] $Node = $sender.SelectedNode
        $Node.Tag.Findings = "Not Applicable"
        $Node.ImageKey = "not-applicable"
        $Node.SelectedImageKey = "not-applicable"

        # Prevent other controls from receiving this event
        $e.SuppressKeyPress = $true
        return
    }

    # SINGLE KEYPRESS SECTION
    if($e.KeyCode -eq [System.Windows.Forms.Keys]::F1)
    {
        [System.Windows.Forms.TreeNode] $Node = $sender.SelectedNode
        $Node.Tag.Findings = "Compliant"
        $Node.ImageKey = "compliant"
        $Node.SelectedImageKey = "compliant"

        # Prevent other controls from receiving this event
        $e.SuppressKeyPress = $true
        return
    }
    if($e.KeyCode -eq [System.Windows.Forms.Keys]::F2)
    {
        [System.Windows.Forms.TreeNode] $Node = $sender.SelectedNode
        $Node.Tag.Findings = "Complies with comments"
        $Node.ImageKey = "compliant-comments"
        $Node.SelectedImageKey = "compliant-comments"

        # Prevent other controls from receiving this event
        $e.SuppressKeyPress = $true
        return
    }
    if($e.KeyCode -eq [System.Windows.Forms.Keys]::F3)
    {
        [System.Windows.Forms.TreeNode] $Node = $sender.SelectedNode
        $Node.Tag.Findings = "Non-Compliant with POAM"
        $Node.ImageKey = "non-compliant-poam"
        $Node.SelectedImageKey = "non-compliant-poam"

        # Prevent other controls from receiving this event
        $e.SuppressKeyPress = $true
        return
    }
    if($e.KeyCode -eq [System.Windows.Forms.Keys]::F4)
    {
        [System.Windows.Forms.TreeNode] $Node = $sender.SelectedNode
        $Node.Tag.Findings = "Non-Compliant"
        $Node.ImageKey = "non-compliant"
        $Node.SelectedImageKey = "non-compliant"

        # Prevent other controls from receiving this event
        $e.SuppressKeyPress = $true
        return
    }
    
}

$TreeViewDefinition.Methods.GetChecked = {
    $checked = New-Object System.Collections.ArrayList

    if ($this.DataNodes -eq $null) {
        return $checked
    }
        
    foreach ($node in $this.DataNodes) {
        if ($node.Checked) {
            [Void] $checked.Add( $node.Tag )
        }
    }

    return $checked
}

# Parameter Encapsulation Object
$DataNodeDefinition = [PSCustomObject]@{
    # Custom Properties
    NoteProperties = @{}

    # [System.Windows.Forms.TreeViewNode] Properties
    Properties     = @{}

    # ScriptMethod Definitions
    Methods        = @{}

    # [System.Windows.Forms.TreeViewNode] Event Handlers
    Handlers       = @{}

    # SortedTreeView Module TreeNode Processing Methods
    Processors     = @{}
}

$DataNodeDefinition.NoteProperties.Type = 'Data'

$DataNodeDefinition.Properties.ContextMenuStrip = &{
    $context = New-Object System.Windows.Forms.ContextMenuStrip
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Compliant", $null, {
        param ($sender, $e)
        # node = compliant
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode
        $Node.Tag.Findings = "Compliant"
        $Node.ImageKey = "compliant"
        $Node.SelectedImageKey = "compliant"
    })))
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Complies with comments", $null, {
        param ($sender, $e)
        # node = compliant with comments
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode
        $Node.Tag.Findings = "Complies with comments"
        $Node.ImageKey = "compliant-comments"
        $Node.SelectedImageKey = "compliant-comments"
    })))
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Non-Compliant with POAM", $null, {
        param ($sender, $e)
        # node = non-compliant poam
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode
        $Node.Tag.Findings = "Non-Compliant with POAM"
        $Node.ImageKey = "non-compliant-poam"
        $Node.SelectedImageKey = "non-compliant-poam"
    })))
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Non-Compliant", $null, {
        param ($sender, $e)
        # node = non-compliant
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode
        $Node.Tag.Findings = "Non-Compliant"
        $Node.ImageKey = "non-compliant"
        $Node.SelectedImageKey = "non-compliant"
    })))
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Not Applicable", $null, {
        param ($sender, $e)
        # node = Not Applicable
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode
        $Node.Tag.Findings = "Not Applicable"
        $Node.ImageKey = "not-applicable"
        $Node.SelectedImageKey = "not-applicable"
    })))
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripSeparator) )
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Putty", $null, {
        param ($sender, $e)
        $menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $treeview = $menu.SourceControl
        [System.Windows.Forms.TreeNode] $node = $treeview.SelectedNode

        # Dependency... Putty.psm1; imported by initialization script nosc.ps1
        $target = [PSCustomObject]@{
            Hostname = $node.Tag.Hostname
            IP       = $node.Tag.Device
        }
        Open-PTYPutty $target
    })))
    return $context
}

$DataNodeDefinition.Methods.ShowDetail = {
    # Module Level Reference
    $TabContainer.SelectedIndex = 1
    Set-DetailContent $this.Tag
}

$DataNodeDefinition.Processors.Images = {
    param($node, $record)

    # Images
    if ($record.Findings     -eq "Compliant") {
        $node.ImageKey = "compliant"
        $node.SelectedImageKey = "compliant"
    }
    elseif ($record.Findings -eq "Complies with comments") {
        $node.ImageKey = "compliant-comments"
        $node.SelectedImageKey = "compliant-comments"
    }
    elseif ($record.Findings -eq "Non-Compliant With POAM") {
        $node.ImageKey = "non-compliant-poam"
        $node.SelectedImageKey = "non-compliant-poam"
    }
    elseif ($record.Findings -eq "Non-Compliant") {
        $node.ImageKey = "non-compliant"
        $node.SelectedImageKey = "non-compliant"
    }
    elseif ($record.Findings -eq "Not Applicable") {
        $node.ImageKey = "not-applicable"
        $node.SelectedImageKey = "not-applicable"
    }
    elseif ($record.Findings -eq "Manual check required") {
        $node.ImageKey = "manual-check"
        $node.SelectedImageKey = "manual-check"
    }
    else {
        $node.ImageKey = "error"
        $node.SelectedImageKey = "error"
    }
}

# Parameter Encapsulation Object
$GroupNodeDefinition = [PSCustomObject]@{
    # Custom Properties
    NoteProperties = @{}

    # [System.Windows.Forms.TreeViewNode] Properties
    Properties     = @{}

    # ScriptMethod Definitions
    Methods        = @{}

    # [System.Windows.Forms.TreeViewNode] Event Handlers
    Handlers       = @{}

    # SortedTreeView Module TreeNode Processing Methods
    Processors     = @{}
}

$GroupNodeDefinition.Processors.Images = {
    param($node, $data)

    $node.ImageKey         = 'group'
    $node.SelectedImageKey = 'group'
}