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

enum DeviceSource {
    Csv = 0
    Orion = 1
}

enum OrionAuthType {
    WindowsCredential = 0
    OrionCredential = 1
}

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
    $Menu.File.OpenCsv.Component    = $Parent
    $Menu.File.OpenCsv.View         = $View
    $Menu.File.OpenOrion.Component  = $Parent
    $Menu.File.OpenOrion.View       = $View

    [Void]$MenuStrip.Items.Add($Menu.File.Root)
    [Void]$MenuStrip.Items.Add($Menu.Fields)
    [Void]$MenuStrip.Items.Add($Menu.Settings)

    $Loader = [PSCustomObject]@{
        Settings = $Menu.Settings.Settings
        View     = $View
        Parent   = $Parent
    }
    Add-Member -InputObject $Loader -MemberType ScriptMethod -Name Load -Value {
        param($sender, $e)
        if ($this.Settings -eq $null)
        {
            return
        }

        if ($this.Settings.DatabaseOptions.PrimarySource -eq [DeviceSource]::Csv)
        {
            if ([String]::IsNullOrEmpty($this.Settings.DatabaseOptions.Csv.RemotePath)) {
                return
            }
            if (Test-Path -LiteralPath $this.Settings.DatabaseOptions.Csv.RemotePath -PathType Leaf) {
                $this.LoadCsv($this.Settings.DatabaseOptions.Csv.RemotePath, $this.View, $this.Parent)
            }
            else {
                [System.Windows.Forms.MessageBox]::Show(
                    ("The shared remote device list database csv file could not be found.`r`n{0}`r`nPlease check the settings to ensure you have set the correct location." -f $this.Settings.DatabaseOptions.Csv.RemotePath),
                    "Load Device List",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
        elseif ($this.Settings.DatabaseOptions.PrimarySource -eq [DeviceSource]::Orion)
        {
            if ([String]::IsNullOrEmpty($this.Settings.DatabaseOptions.Orion.Hostname))
            {
                return
            }

            if ($this.Setting.DatabaseOptions.Orion.AuthType -eq [OrionAuthType]::OrionCredential)
            {
                $credential = Get-Credential -Message "Enter Orion Credential"
                if (Open-OrionSwisConnection $this.Settings.DatabaseOptions.Orion.Hostname -Credential $credential)
                {
                    $this.LoadOrion($this.View, $this.Parent)
                }
                else
                {
                    [System.Windows.Forms.MessageBox]::Show(
                        ("Could not connect to the SolarWinds server: {0}." -f $this.Settings.DatabaseOptions.Orion.Hostname),
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                }
            }
            elseif ($this.Settings.DatabaseOptions.Orion.AuthType -eq [OrionAuthType]::WindowsCredential)
            {
                if (Open-OrionSwisConnection $this.Settings.DatabaseOptions.Orion.Hostname)
                {
                    $this.LoadOrion($this.View, $this.Parent)
                }
                else
                {
                    [System.Windows.Forms.MessageBox]::Show(
                        ("Could not connect to the SolarWinds server: {0}." -f $this.Settings.DatabaseOptions.Orion.Hostname),
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Error
                    )
                }
            }

            if (Test-OrionSwisConnection)
            {
                Close-OrionSwisConnection
            }
        }
    }
    Add-Member -InputObject $Loader -MemberType ScriptMethod -Name LoadCsv -Value ${Function:Load-CsvDeviceList}
    Add-Member -InputObject $Loader -MemberType ScriptMethod -Name LoadOrion -Value ${Function:Load-OrionDeviceList}
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
Import-Module "$ModuleInvocationPath\SolarWinds.psm1" -Prefix Orion
Import-Module "$ModuleInvocationPath\Settings.psm1"

$ImagePath = "$ModuleInvocationPath\..\..\resources"
$BinPath   = "$ModuleInvocationPath\..\..\bin"

###############################################################################
### Menu Definitions - Registered to parent menu strip
$Menu = @{}

## Settings Menu --------------------------------------------------------------
$Menu.Settings = New-Object System.Windows.Forms.ToolStripMenuItem("Settings", $null, {
    # Currently only launches the settings dialog window, configuration settings are
    # only used during loading.
    if ($this.Settings -eq $null)
    {
        $dialog = New-SettingsDialog -Settings (New-SettingsObject)
    }
    else
    {
        $dialog = New-SettingsDialog $this.Settings
    }

    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
    {
        $this.Settings = $dialog.Settings
        foreach ($object in $this.Subscribers)
        {
            $object.Settings = $dialog.Settings
        }
        $json = $dialog.Settings | ConvertTo-Json -Depth 5
        $json > $this.FilePath
    }
    $dialog.Dispose()
})
Add-Member -InputObject $Menu.Settings -MemberType NoteProperty -Name Settings -Value $null
Add-Member -InputObject $Menu.Settings -MemberType NoteProperty -Name Subscribers -Value (New-Object System.Collections.ArrayList)
Add-Member -InputObject $Menu.Settings -MemberType NoteProperty -Name FilePath -Value "$ModuleInvocationPath\settings.json"
## Load Settings
if (Test-Path -LiteralPath $Menu.Settings.FilePath -PathType Leaf) {
    $Menu.Settings.Settings = ConvertFrom-Json (Get-Content $Menu.Settings.FilePath -Raw)
}

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

$Menu.File.OpenCsv = New-Object System.Windows.Forms.ToolStripMenuItem("Open", $null, {
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
$Menu.File.OpenCsv.Name = 'OpenCsv'
Add-Member -InputObject $Menu.File.OpenCsv -MemberType NoteProperty -Name Settings -Value $Menu.Settings.Settings
Add-Member -InputObject $Menu.File.OpenCsv -MemberType NoteProperty -Name Component -Value $null
Add-Member -InputObject $Menu.File.OpenCsv -MemberType NoteProperty -Name View -Value $null
[void]$Menu.Settings.Subscribers.Add($Menu.File.OpenCsv)

$Menu.File.OpenOrion = New-Object System.Windows.Forms.ToolStripMenuItem("OpenOrion", $null, {
    param($sender, $e)
    if ([String]::IsNullOrEmpty($this.Settings.DatabaseOptions.Orion.Hostname))
    {
        ### TODO ### Put a message box here to inform the user that no SolarWinds Orion server info has been configured in the settings.
        Write-Error "No SolarWinds Orion hostname configured in settings."
        return
    }

    if (!(Test-OrionSwisConnection))
    {
        if (!(Open-OrionSwisConnection $this.Settings.DatabaseOptions.Orion.Hostname))
        {
            ### TODO ### Put a message box here to inform the user that the connection couldn't be opened.
            Write-Error "Swis connection could not be established to SolarWinds Orion server."
            return
        }

        if ([String]::IsNullOrEmpty($this.Settings.DatabaseOptions.Orion.Hostname))
        {
            return
        }

        if ($this.Setting.DatabaseOptions.Orion.AuthType -eq [OrionAuthType]::OrionCredential)
        {
            $credential = Get-Credential -Message "Enter Orion Credential"
            if (!(Open-OrionSwisConnection $this.Settings.DatabaseOptions.Orion.Hostname -Credential $credential))
            {
                Write-Error "Swis connection could not be established to SolarWinds Orion server."
                [System.Windows.Forms.MessageBox]::Show(
                    ("Could not connect to the SolarWinds server: {0}." -f $this.Settings.DatabaseOptions.Orion.Hostname),
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
                return
            }
        }
        elseif ($this.Settings.DatabaseOptions.Orion.AuthType -eq [OrionAuthType]::WindowsCredential)
        {
            if (!(Open-OrionSwisConnection $this.Settings.DatabaseOptions.Orion.Hostname))
            {
                Write-Error "Swis connection could not be established to SolarWinds Orion server."
                [System.Windows.Forms.MessageBox]::Show(
                    ("Could not connect to the SolarWinds server: {0}." -f $this.Settings.DatabaseOptions.Orion.Hostname),
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Error
                )
            }
        }
    }
    Load-OrionDeviceList -View $this.View -Component $this.Component
    Close-OrionSwisConnection
})
$Menu.File.OpenOrion.Name = 'OpenOrion'
Add-Member -InputObject $Menu.File.OpenOrion -MemberType NoteProperty -Name Settings -Value $Menu.Settings.Settings
Add-Member -InputObject $Menu.File.OpenOrion -MemberType NoteProperty -Name Component -Value $null
Add-Member -InputObject $Menu.File.OpenOrion -MemberType NoteProperty -Name View -Value $null
[void]$Menu.Settings.Subscribers.Add($Menu.File.OpenOrion)

$Menu.File.Root = New-Object System.Windows.Forms.ToolStripMenuItem("File", $null, @($Menu.File.SaveAs.Root, $Menu.File.OpenCsv, $Menu.File.OpenOrion))
$Menu.File.Root.Name = 'File'

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
        # File path to CSV device list, or SolarWinds Orion server hostname.
        [Parameter(Mandatory = $true)]
            [String]
            $Path,

        # View container for the interface.
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.SplitContainer]
            $View,

        # The devices component container control.
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Control]
            $Component,

        # Switch to load device list from SolarWinds Orion server host.
        [Parameter(Mandatory = $false)]
            [Switch]
            $Orion
    )

    if ($Orion)
    {
        Load-OrionDeviceList -View $View -Component $Component
    }
    else
    {
        Load-CsvDeviceList -Path $Path -View $View -Component $Component
    }
}

function Load-CsvDeviceList {
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
    Set-DeviceList -Data $Data -View $View -Component $Component
}

function Load-OrionDeviceList {
    param(
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.SplitContainer]
            $View,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Control]
            $Component
    )

    $Data = Get-OrionNodes
    Set-DeviceList -Data $Data -View $View -Component $Component
}

function Set-DeviceList {
    param(
        [Parameter(Mandatory = $true)]
            [System.Array]
            $Data,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.SplitContainer]
            $View,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Control]
            $Component
    )

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

        switch ($Node.Tag.RemoteManagement)
        {
            'URL' {
                # Default browser.
                Start-Process -FilePath $Node.Tag.URL
            }

            'SSH' {
                # Open PuTTY session for node
                $target = [PSCustomObject]@{
                    Hostname = $Node.Tag.Hostname
                    IP       = $Node.Tag.ip
                }
                Open-PuttySSH $target

            }

            'RDP' {
                # Attempt to resolve hostname.
                $resolved = $null
                try
                {
                    $resolved = [System.Net.Dns]::Resolve($Node.Tag.DNS)
                }
                finally
                {
                    if ($resolved -ne $null)
                    {
                        # Microsoft Terminal Services Client
                        Start-Process "mstsc.exe" -ArgumentList "/v:$($Node.Tag.IP)"
                    }
                    else
                    {
                        # Microsoft Terminal Services Client
                        Start-Process "mstsc.exe" -ArgumentList "/v:$($Node.Tag.DNS)"
                    }
                }
            }
        }

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
            Hostname = $node.Tag.Hostname
            IP       = $node.Tag.IP
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
                Hostname = $record.Hostname
                IP       = $record.IP
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

        if ($TreeNode.Type -ne 'Data' -or $TreeNode.Tag.SSH -eq $null) {
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
            Hostname = $TreeNode.Tag.Hostname
            IP       = $TreeNode.Tag.IP
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

        # Attempt to resolve hostname.
        $resolved = $null
        try
        {
            $resolved = [System.Net.Dns]::Resolve($Node.Tag.DNS)
        }
        finally
        {
            if ($resolved -ne $null)
            {
                # Microsoft Terminal Services Client
                Start-Process "mstsc.exe" -ArgumentList "/v:$($Node.Tag.IP)"
            }
            else
            {
                # Microsoft Terminal Services Client
                Start-Process "mstsc.exe" -ArgumentList "/v:$($Node.Tag.DNS)"
            }
        }
    })))

    ## HTTP -------------------------------------------------------------------
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripSeparator) )
    [Void]$context.Items.Add( (New-Object System.Windows.Forms.ToolStripMenuItem("HTTP", $null, {
        param ($sender, $e)
        $Menu = $sender.GetCurrentParent()
        [System.Windows.Forms.TreeView] $TreeView = $Menu.SourceControl
        [System.Windows.Forms.TreeNode] $Node = $TreeView.SelectedNode

        # Default browser.
        Start-Process -FilePath $Node.Tag.URL
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
