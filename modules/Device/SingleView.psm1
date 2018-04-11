<#
.SYNOPSIS
    Baseline network host device information management.

.DESCRIPTION
    Windows GUI components for managing the list of devices that make up the
    network baseline.

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
            [System.Windows.Forms.Control]
            $Parent,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.MenuStrip]
            $MenuStrip,

        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $OnLoad
    )

    # Initialize
    $View = New-ViewControl -Window $Window -Container $Parent -OnLoad $OnLoad

    # Menu Configuration
    $Menu.File.SaveAs.Csv.Component = $Parent
    $Menu.File.SaveAs.Csv.View      = $View
    $Menu.File.Open.Component       = $Parent
    $Menu.File.Open.View            = $View

    [Void]$MenuStrip.Items.Add($Menu.File.Root)
    [Void]$MenuStrip.Items.Add($Menu.Fields)
    [Void]$MenuStrip.Items.Add($Menu.Settings)

    $Loader = [PSCustomObject]@{
        Settings = $Settings
        View     = $View
        Parent   = $Parent
    }
    Add-Member -InputObject $Loader -MemberType ScriptMethod -Name Load -Value {
        param($sender, $e)
        if ($this.Settings) {
            if ($this.Settings.remotedb -eq [string]::Empty) {
                return
            }
            if (Test-Path -LiteralPath $this.Settings.remotedb -PathType Leaf) {
                $this.Load_DeviceList($this.Settings.remotedb, $this.View, $this.Parent)
            }
            else {
                [System.Windows.Forms.MessageBox]::Show(
                    ("The shared remote device list database csv file could not be found.`r`n{0}`r`nPlease check the settings to ensure you have set the correct location." -f $this.Settings.remotedb),
                    "Load Device List",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    }
    Add-Member -InputObject $Loader -MemberType ScriptMethod -Name Load_DeviceList -Value ${Function:Load-DeviceList}
    [Void]$OnLoad.Add($Loader)

    # Register Component (TableLayout Parent)
    return $View
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
Import-Module "$ModuleInvocationPath\..\SortedTreeView\SortedTreeView.psm1" -Prefix Nav

$ImagePath = "$ModuleInvocationPath\..\..\resources"
$BinPath   = "$ModuleInvocationPath\..\..\bin"

###############################################################################
### Settings Management -------------------------------------------------------
$Settings = $null
$SettingsPath = "$ModuleInvocationPath\settings.json"
$SettingsDialog = "$ModuleInvocationPath\settings.ps1"

## Load Settings
if (Test-Path -LiteralPath $SettingsPath -PathType Leaf) {
    $Settings = ConvertFrom-Json ((Get-Content $SettingsPath) -join '')
}

###############################################################################
### Menu Definitions - Registered to parent menu strip
$Menu = @{}

## File Menu ------------------------------------------------------------------
$Menu.File = @{}

$Menu.File.SaveAs = @{}
$Menu.File.SaveAs.Csv = New-Object System.Windows.Forms.ToolStripMenuItem("CSV", $null, {
    param($sender, $e)

    $Dialog = New-Object System.Windows.Forms.SaveFileDialog
    $Dialog.ShowHelp = $false

    $data = $this.Component.Data
    foreach ($record in $data) {
        [void]$record.PSObject.Properties.Remove('Dirty')
    }

    $Dialog.Filter = "Csv File (*.csv)|*.csv"
    if($Dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK){
        if (Test-Path -LiteralPath $Dialog.FileName) {
            try {
                Move-Item $Dialog.FileName ("{0}.bak" -f $Dialog.FileName)
            }
            catch {
                [System.Windows.Forms.MessageBox]::Show(
                    "Failed to create back up of existing file before saving to prevent data loss.  Please try again.",
                    "Save Device List",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return
            }
        }
        $data | Export-Csv $Dialog.FileName -NoTypeInformation
    }
})
$Menu.File.SaveAs.Csv.Name = 'CSV'
Add-Member -InputObject $Menu.File.SaveAs.Csv -MemberType NoteProperty -Name Component -Value $null
Add-Member -InputObject $Menu.File.SaveAs.Csv -MemberType NoteProperty -Name View -Value $null

$Menu.File.SaveAs.Root = New-Object System.Windows.Forms.ToolStripMenuItem("Save As", $null, @($Menu.File.SaveAs.Csv))
$Menu.File.SaveAs.Root.Name = 'SaveAs'

$Menu.File.Open = New-Object System.Windows.Forms.ToolStripMenuItem("Open", $null, {
    param($sender, $e)
    
    $Dialog = New-Object System.Windows.Forms.OpenFileDialog
    
    <# Fix for dialog script hang bug #>
    $Dialog.ShowHelp = $false
        
    # Dialog Configuration
    $Dialog.Filter = "Device Csv File (*.csv)|*.csv"
    $Dialog.Multiselect = $false
        
    # Run Selection Dialog
    if($($Dialog.ShowDialog()) -eq "OK") {
        Load-DeviceList -Path $Dialog.FileName -View $this.View -Component $this.Component
    }
})
$Menu.File.Open.Name = 'Open'
Add-Member -InputObject $Menu.File.Open -MemberType NoteProperty -Name Component -Value $null
Add-Member -InputObject $Menu.File.Open -MemberType NoteProperty -Name View -Value $null

$Menu.File.Root = New-Object System.Windows.Forms.ToolStripMenuItem("File", $null, @($Menu.File.SaveAs.Root, $Menu.File.Open))
$Menu.File.Root.Name = 'File'

## Settings Menu --------------------------------------------------------------
$Menu.Settings = New-Object System.Windows.Forms.ToolStripMenuItem("Settings", $null, {
    # Currently only launches the settings dialog window, configuration settings are
    # only used during loading.
    $Settings = & "$SettingsDialog" $Settings
})

## Dynamic Fields Menu --------------------------------------------------------
$Menu.Fields = New-Object System.Windows.Forms.ToolStripMenuItem("Fields")
$Menu.Fields.Name = 'Fields'
$Menu.Fields.DropDown.Add_Closing({
    param($sender, $e)
    if ($e.CloseReason -eq [System.Windows.Forms.ToolStripDropDownCloseReason]::ItemClicked -or
        $e.CloseReason -eq [System.Windows.Forms.ToolStripDropDownCloseReason]::AppFocusChange) {
        $e.Cancel = $true
    }
})

###############################################################################
### Device Data Management

function Load-DeviceList {
    param(
        [Parameter(Mandatory = $true)]
            [String]
            $Path,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.SplitContainer]
            $View,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Control]
            $Component
    )

    $Data = Import-Csv $Path

    if ($View.NavPanel.TreeView.Nodes.Count -gt 0) {
        $View.NavPanel.TreeView.Nodes.Clear()
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

        $View.Display.Fields.Clear()
        $View.Display.Fields.AddRange($FieldNames)

        # Update Fields Filter Menu Items
        if ($Menu.Fields.HasDropDownItems) {
            $Menu.Fields.DropDownItems.Clear()
        }

        # Top Level Check All | Uncheck All
        $toggle = New-Object System.Windows.Forms.ToolStripMenuItem('Toggle All', $null, {
            $this.Display.Fields.Clear()

            foreach ($item in $this.Items) {
                $item.Checked = $this.Checked
                if ($this.Checked) {
                    $this.Display.Fields.Add($item.Text)
                }
            }

            $this.Display.Redisplay()
        })
        $toggle.CheckOnClick = $true
        $toggle.Checked = $true
        Add-Member -InputObject $toggle -MemberType NoteProperty -Name Items -Value (New-Object System.Collections.ArrayList)
        Add-Member -InputObject $toggle -MemberType NoteProperty -Name Display -Value $View.Display
        [Void]$Menu.Fields.DropDownItems.Add($toggle)
        [Void]$Menu.Fields.DropDownItems.Add((New-Object System.Windows.Forms.ToolStripSeparator))

        foreach ($field in $FieldNames) {
            $item = New-Object System.Windows.Forms.ToolStripMenuItem($field, $null, {
                if ($this.Checked) {
                    if (!$this.Display.Fields.Contains($this.Text)) {
                        [void]$this.Display.Fields.Add($this.Text)
                    }
                }
                else {
                    if ($this.Display.Fields.Contains($this.Text)) {
                        [void]$this.Display.Fields.Remove($this.Text)
                    }
                }
                $this.Display.Redisplay()
            })
            $item.CheckOnClick = $true
            $item.Checked = $true
            Add-Member -InputObject $item -MemberType NoteProperty -Name Display -Value $View.Display
            [Void]$Menu.Fields.DropDownItems.Add($item)
            [Void]$toggle.Items.Add($item)
        }
        
        # Add state fields
        foreach ($record in $data) {
            Add-Member -InputObject $record -MemberType NoteProperty -Name Dirty -Value $false
        }

        # Saved reference to the data for later export
        [Void]$Component.Data.Clear()
        [Void]$Component.Data.AddRange($Data)

        # Set TreeView Object Data Source Fields
        $View.NavPanel.Settings.RegisterFields($FieldNames)
    }

    if ($View.NavPanel.Settings.Valid) {
        $View.NavPanel.Settings.Apply()
    }
    else {
        $View.NavPanel.Settings.PromptUser()
    }
}

###############################################################################
### Object Factories - Dynamic Window Components

function New-ViewControl {
    param(
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Form]
            $Window,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Control]
            $Container,

        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $OnLoad
    )

    # Component Layout
    $View = New-Object System.Windows.Forms.SplitContainer
        $View.Dock = [System.Windows.Forms.DockStyle]::Fill
        $View.Orientation = [System.Windows.Forms.Orientation]::Vertical

        # Attached to Parent Control by Module Component Registration Function
        Add-Member -InputObject $View -MemberType NoteProperty -Name FieldList -Value (New-Object System.Collections.ArrayList)
        

    # Device Data Layout Panel
    $DataView = New-DataLayout

        [void]$View.Panel2.Controls.Add( $DataView )
        $DataNodeDefinition.NoteProperties.DataView = $DataView

        Add-Member -InputObject $View -MemberType NoteProperty -Name Display -Value $DataView

    # Device Navigation Panel
        # SortedTreeView component created by intialize function (dependecy on runtime object references)
    $NavControl = Initialize-NavComponents    `
        -Window          $Window              `
        -Parent          $View.Panel1         `
        -MenuStrip       $null                `
        -OnLoad          $OnLoad              `
        -Title           'Device Explorer'    `
        -Source          $Container.Data      `
        -ImageList       $ImageList           `
        -TreeDefinition  $TreeViewDefinition  `
        -GroupDefinition $GroupNodeDefinition `
        -NodeDefinition  $DataNodeDefinition

        Add-Member -InputObject $View -MemberType NoteProperty -Name NavPanel -Value $NavControl

    [void]$view.Panel1.Controls.Add($NavControl)

    return $View
}

function New-DataLayout {
    # Device Data Layout Panel
    $DataLayout = New-Object System.Windows.Forms.FlowLayoutPanel
        $DataLayout.Dock = [System.Windows.Forms.DockStyle]::Fill
        $DataLayout.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
        $DataLayout.BackColor     = [System.Drawing.Color]::AliceBlue
        #$DataLayout.WrapContents  = $false
        $DataLayout.AutoSize      = $true
        $DataLayout.AutoSizeMode  = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $DataLayout.AutoScroll    = $true

    Add-Member -InputObject $DataLayout -MemberType NoteProperty -Name Fields -Value (New-Object System.Collections.ArrayList)

    Add-Member -InputObject $DataLayout -MemberType NoteProperty -Name Record -Value $null

    Add-Member -InputObject $DataLayout -MemberType ScriptMethod -Name SetContent -Value {
        param(
            [Parameter(Mandatory = $true)]
                [PSCustomObject]$record
        )

        $this.SuspendLayout()
        if ($this.Controls.Count -gt 0) {
            $this.Controls.Clear()
        }

        $this.Record = $record

        # Extract field names
        $fields =  @( 
            ($record |
                Get-Member -MemberType NoteProperty |
                    Select-Object -Property Name -Unique |
                        % {Write-Output $_.Name}))

        foreach ($field in $fields) {
            Write-Debug "Generating panel for field ($field)"
            if ($this.Fields.Contains($field)) {
                $panel = New-DataPanel -Title $field -Data $record.($field) -Record $record -MaxWidth $this.Width
            
                [Void]$this.Controls.Add($panel)
            }
        }
        $this.ResumeLayout()
    }

    Add-Member -InputObject $DataLayout -MemberType ScriptMethod -Name Redisplay -Value {
        if ($this.Record -ne $null) {
            $this.SetContent($this.Record)
        }
    }

    return $DataLayout
}

function New-DataPanel {
    param(
        [Parameter(Mandatory = $true)]
            [String]
            $Title,

        [Parameter(Mandatory = $true)]
            [AllowEmptyString()]
            [String]
            $Data,

        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $Record,

        [Parameter()]
            [Int]
            $MaxWidth
    )

    $Panel = New-Object System.Windows.Forms.Panel
        #$Panel.AutoSize = $true
        #$Panel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $Panel.Height = 40
        #$Panel.Width  = $MaxWidth
        $Panel.Width = 200

    $TitleLabel = New-Object System.Windows.Forms.Label
        $TitleLabel.Text = $Title
        $TitleLabel.Dock = [System.Windows.Forms.DockStyle]::Top
        $TitleLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
        #$TitleLabel.AutoSize = $true
        #$TitleLabel.Width = $MaxWidth
        $TitleLabel.Width = 200

    $DataBox = New-Object System.Windows.Forms.TextBox
        if (![String]::IsNullOrEmpty($Data)) {
            $DataBox.Text = $Data
        }
        $DataBox.Dock = [System.Windows.Forms.DockStyle]::Top
        #$DataBox.AutoSize = $true
        #$DataBox.Width = $MaxWidth
        $DataBox.Width = 200

    [Void]$Panel.Controls.Add($DataBox)
    [Void]$Panel.Controls.Add($TitleLabel)

    Add-Member -InputObject $DataBox -MemberType NoteProperty -Name Record -Value $Record
    Add-Member -InputObject $DataBox -MemberType NoteProperty -Name Field -Value $Title

    $DataBox.Add_TextChanged({
        $this.Record.($this.Field) = $this.Text
        $this.Record.Dirty = $true
    })

    return $Panel
}

###############################################################################
### TreeView Component Static Resources
$ImageList = New-Object System.Windows.Forms.ImageList
$ImageList.ColorDepth = [System.Windows.Forms.ColorDepth]::Depth32Bit
$ImageList.ImageSize  = New-Object System.Drawing.Size(16,16)
$ImageList.Images.Add('group',
    [System.Drawing.Icon]::new("$ImagePath\group.ico"))
$ImageList.Images.Add('monitored',
    [System.Drawing.Icon]::new("$ImagePath\tag-blue-add.ico"))
$ImageList.Images.Add('not-monitored',
    [System.Drawing.Icon]::new("$ImagePath\tag-blue-delete.ico"))

## Parameter Encapsulation Object ---------------------------------------------
$TreeViewDefinition = [PSCustomObject]@{
    # [System.Windows.Forms.TreeView] Properties
    Properties     = @{}

    # Customized Properties
    NoteProperties = @{}

    # ScriptMethod Definitions
    Methods        = @{}

    # [System.Windows.Forms.TreeView] Event Handlers
    Handlers       = @{}
}

$TreeViewDefinition.Methods.GetChecked = {
    $checked = New-Object System.Collections.ArrayList

    if ($this.DataNodes -eq $null) {
        return $checked
    }

    foreach ($node in $this.DataNodes) {
        if ($node.Checked -and $node.Type -eq 'Data' -and $node.Tag.Access_Method.ToUpper() -match 'SSH') {
            [Void] $checked.Add( $node.Tag )
        }
    }

    return $checked
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

    # SINGLE KEYPRESS SECTION
    if($e.KeyCode -eq [System.Windows.Forms.Keys]::F1)
    {
        [System.Windows.Forms.TreeNode] $Node = $sender.SelectedNode

        if ($Node.Type -ne 'Data' -or $Node.Tag.Access_Method.ToUpper() -notmatch 'SSH') {
            [System.Windows.Forms.MessageBox]::Show(
                ("[{0}] SSH not supported!" -f $Node.Text),
                'PuTTY Secure Shell',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Exclamation)
            return
        }

        # Open PuTTY session for node
        $target = [PSCustomObject]@{
            Hostname = $Node.Tag.Device_Hostname
            IP       = $Node.Tag.ip
        }
        Open-PuttySSH $target

        # Prevent other controls from receiving this event
        $e.SuppressKeyPress = $true
        return
    }
}

## Parameter Encapsulation Object ---------------------------------------------
$DataNodeDefinition = [PSCustomObject]@{
    # Custom NoteProperties
    NoteProperties = @{}

    # [System.Windows.Forms.TreeViewNode] Properties
    Properties     = @{}

    # ScriptMethod Definitions
    Methods        = @{}

    # [System.Windows.Forms.TreeViewNode] Event Handlers
    Handlers       = @{}

    # SortedTreeView Module TreeNode Processing Methods. Used to customize a TreeNode during creation.
    Processors     = @{}
}

# Reference for setting the data view content container
$DataNodeDefinition.NoteProperties.DataView = $null

$DataNodeDefinition.NoteProperties.Type = 'Data'

$DataNodeDefinition.Methods.ShowDetail = {
    $this.DataView.SetContent( $this.Tag )
}

$DataNodeDefinition.Processors.Images = {
    param($Node, $Record)

    if (![String]::IsNullOrEmpty($Record.Orion_Hostname)) {
        $Node.ImageKey = "monitored"
        $Node.SelectedImageKey = "monitored"
    }
    else {
        $Node.ImageKey = "not-monitored"
        $Node.SelectedImageKey = "not-monitored"
    }
}

$DataNodeDefinition.Properties.ContextMenuStrip = &{
    $context = New-Object System.Windows.Forms.ContextMenuStrip

    ## PING -------------------------------------------------------------------
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Ping", $null, {
        param ($sender, $e)
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode

        # Options Dialog
        # TODO

        # Invoke Ping in new Powershell Console
        $command = '$Host.UI.RawUI.WindowTitle =' + "'Ping $($Node.Text)';" + "ping -t -a $($Node.Tag.IP)"

        Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-NoLogo -NoExit -NoProfile -Command $command"
    })))

    ## TRACEROUTE -------------------------------------------------------------
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Trace Route", $null, {
        param ($sender, $e)
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode

        # Options Dialog
        # TODO

        # Invoke Ping in new Powershell Console
        $command = '$Host.UI.RawUI.WindowTitle =' + "'Traceroute $($Node.Text)';" + "tracert -d $($Node.Tag.IP)"

        Start-Process -FilePath "$PSHOME\powershell.exe" -ArgumentList "-NoLogo -NoExit -NoProfile -Command $command"
    })))

    ## PUTTY ------------------------------------------------------------------
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripSeparator) )
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("PuTTY", $null, {
        param ($sender, $e)
        $menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $treeview = $menu.SourceControl
        [System.Windows.Forms.TreeNode] $node = $treeview.SelectedNode

        $target = [PSCustomObject]@{
            Hostname = $node.Tag.Device_Hostname
            IP       = $node.Tag.ip
        }

        # Dependency... Putty.psm1; imported globally by initialization script nosc.ps1
        Open-PuttySSH $target
    })))

    ## PUTTY MULTISELECT ------------------------------------------------------
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Multi-PuTTY", $null, {
        param ($sender, $e)
        $menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $treeview = $menu.SourceControl
        [System.Windows.Forms.TreeNode] $node = $treeview.SelectedNode

        # Multi-select (checked) support.  GetChecked returns a System.Array
        $records = New-Object System.Collections.ArrayList
        $checked = $treeview.GetChecked()

        if ($checked) {
            $records.AddRange($checked)
        }

        if (!$node.Checked) {
            [Void]$records.Add($node.Tag)
        }

        # Dependency... Putty.psm1; imported globally by initialization script nosc.ps1
        foreach ($record in $records) {
            $target = [PSCustomObject]@{
                Hostname = $record.Device_Hostname
                IP       = $record.ip
            }

            Open-PuttySSH $target
        }
    })))

    ## PSCP -------------------------------------------------------------------
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("pSCP", $null, {
        param ($sender, $e)
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $TreeNode = $TreeView.SelectedNode

        if ($TreeNode.Type -ne 'Data' -or $TreeNode.Tag.Access_Method.ToUpper() -notmatch 'SSH') {
            [System.Windows.Forms.MessageBox]::Show(
                ("[{0}] pSCP not supported!" -f $TreeNode.Text),
                'pSCP Secure Copy',
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Exclamation)
            return
        }

        $Dialog = New-Object System.Windows.Forms.OpenFileDialog

        <# Fix for dialog script hang bug #>
        $Dialog.ShowHelp = $false

        # Dialog Configuration
        $Dialog.Filter = "Text Files (*.txt)|*.txt|IOS Bins (*.bin)|*.bin"
        $Dialog.Multiselect = $false

        # Run Selection Dialog
        if($($Dialog.ShowDialog()) -eq "OK") {
            $target = [PSCustomObject]@{
            Hostname = $TreeNode.Tag.Device_Hostname
            IP       = $TreeNode.Tag.ip
            }

            $file = Get-Item $Dialog.FileName

            Send-PuttyFile $target $file
        }
    })))

    ## REMOTE DESKTOP ---------------------------------------------------------
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripSeparator) )
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("Remote Desktop", $null, {
        param ($sender, $e)
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode

        # Microsoft Terminal Services Client
        Start-Process "mstsc.exe" -ArgumentList "/v:$($Node.Tag.IP)"
    })))

    ## HTTP -------------------------------------------------------------------
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripSeparator) )
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("HTTP", $null, {
        param ($sender, $e)
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode

        # Microsoft Terminal Services Client
        Start-Process -FilePath "http://$($Node.Tag.IP)"
    })))

    ## HTTPS ------------------------------------------------------------------
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("HTTPS", $null, {
        param ($sender, $e)
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode

        # Microsoft Terminal Services Client
        Start-Process -FilePath "https://$($Node.Tag.IP)"
    })))

    return $context
}

## Parameter Encapsulation Object ---------------------------------------------
$GroupNodeDefinition = [PSCustomObject]@{
    # Custom Properties
    NoteProperties = @{}

    # [System.Windows.Forms.TreeViewNode] Properties
    Properties     = @{}

    # ScriptMethod Definitions
    Methods        = @{}

    # [System.Windows.Forms.TreeViewNode] Event Handlers
    Handlers       = @{}

    # SortedTreeView Module TreeNode Processing Methods. Used to customize a TreeNode during creation.
    Processors     = @{}
}

$GroupNodeDefinition.NoteProperties.Type = 'Group'

$GroupNodeDefinition.Processors.Images = {
    param($node, $data)

    $node.ImageKey         = 'group'
    $node.SelectedImageKey = 'group'
}
