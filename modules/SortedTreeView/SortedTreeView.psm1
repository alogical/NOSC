<#
.SYNOPSIS
    Custom TreeView control with display and filter settings.

.DESCRIPTION


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
            [AllowNull()]
            [System.Windows.Forms.Form]
            $Window,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Control]
            $Parent,

        [Parameter(Mandatory = $true)]
            [AllowNull()]
            [System.Windows.Forms.MenuStrip]
            $MenuStrip,

        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $OnLoad,

        [Parameter(Mandatory = $false)]
            [String]
            $Title = "TreeView",

        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $Source,

        [Parameter()]
            [System.Windows.Forms.ImageList]
            $ImageList,

        [Parameter()]
            [PSCustomObject]
            $TreeDefinition,

        [Parameter()]
            [PSCustomObject]
            $GroupDefinition,

        [Parameter()]
            [PSCustomObject]
            $NodeDefinition
    )

    $Container = New-Object System.Windows.Forms.TabControl
    $Container.Dock = [System.Windows.Forms.DockStyle]::Fill

    ### TreeView Container ----------------------------------------------------
    $TreeParams = @{
        Source         = $Source
        Title          = $Title
        ImageList      = $ImageList
        Static         = $Static
        DefaultHandler = $Default
        Definition     = $TreeDefinition
    }
    $TreeViewTab = New-TreeViewTab @TreeParams

    $Container.Controls.Add($TreeViewTab)

    # Settings Tab Parameter Sets
    $DockSettings = @{
        Window    = $Window
        Component = $Container
        Target    = $Parent
    }

    $SettingParams = @{
        Component       = $Container
        TreeView        = $TreeViewTab.Controls["TreeView"]
        GroupDefinition = $GroupDefinition
        NodeDefinition  = $NodeDefinition
    }
    $SettingsManager = New-SettingsManager @SettingParams

    $SettingsTab = New-SettingsTab $SettingsManager $DockSettings
    $Container.Controls.Add($SettingsTab)

    Add-Member -InputObject $Container -MemberType NoteProperty -Name TreeView -Value $TreeViewTab.Controls['TreeView']
    Add-Member -InputObject $Container -MemberType NoteProperty -Name Settings -Value $SettingsManager

    ### Return Component Control ----------------------------------------------
    return $Container
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
# Static Objects and Scriptblocks used for the creation of an indeterminate num
# of objects.

$Static = @{}
$Static.ProcessDefinition = {
    param([System.Windows.Forms.TreeNode]$Node, [Object]$Record, [Object]$Definition)

    # CUSTOM PRE-PROCESSORS
    foreach ($processor in $Definition.Processors.Values) {
        & $processor $Node $Record | Out-Null
    }

    # CUSTOM PROPERTIES
    foreach ($property in $Definition.NoteProperties.GetEnumerator()) {
        Add-Member -InputObject $Node -MemberType NoteProperty -Name $property.Key -Value $property.Value
    }

    # BUILT-IN PROPERTIES - late binding (dynamic)
    foreach ($property in $Definition.Properties.GetEnumerator()) {
        $Node.($property.Key) = $property.Value
    }

    # CUSTOM METHODS
    foreach ($method in $Definition.Methods.GetEnumerator()) {
        Add-Member -InputObject $Node -MemberType ScriptMethod -Name $method.Key -Value $method.Value
    }

    # EVENT HANDLERS - late binding (dynamic)
    foreach ($handler in $Definition.Handlers.GetEnumerator()) {
        $Node.("Add_$($handler.Key)")($handler.Value)
    }
}
$Static.TreeNodeChecked = {
    param($State)

    $this.Checked = $State
    ForEach ($child in $this.Nodes) {
        $child.SetChecked($State)
    }
}

# Object Sorting
$Static.NewSortBucket = {
    param($Rule, $Factory)

    Write-Debug ("Creating Sort [{0}] Bucket" -f $Rule.Name)

    $bucket = [PSCustomObject]@{
        Rule    = $Rule
        Factory = $Factory
        Content = @{}
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Add -Value {
        param($Record)

        $value = $Record.($this.Rule.Name)

        if (!$this.Content.ContainsKey($value)) {

            Write-Debug "Creating Sort Bucket For ($value)"

            [void]$this.Content.Add($value, $this.Factory.New())
        }

        [void]$this.Content[$value].Add($Record)
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Sort -Value {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
                [System.Collections.ArrayList]
                $Records
        )

        if ($Records.Count -eq 0) {
            return
        }

        foreach ($record in $Records) {
            [void]$this.Add($record)
        }

        return $this.Finish()
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Finish -Value {

        # Sort Buckets
        if ($this.Rule.SortDirection -eq 'Ascending') {
            $sorted = $this.Content.GetEnumerator() | Sort-Object -Property Key
        }
        else {
            $sorted = $this.Content.GetEnumerator() | Sort-Object -Property Key -Descending
        }

        ForEach ($pair in $sorted) {
            Write-Output $pair.Value.Finish()
        }

        # Reset the sorting buckets
        $this.Content = @{}
    }

    return $bucket
}
$static.NewFinalSortBucket = {
    param($Rule)

    Write-Debug ("Creating Sort [{0}] Bucket" -f $Rule.Name)

    $bucket = [PSCustomObject]@{
        Rule    = $Rule
        Content = New-Object System.Collections.ArrayList
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Add -Value {
        param($Record)

        [void]$this.Content.Add($Record)
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Sort -Value {
        param(
            [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
                [System.Collections.ArrayList]
                $Records
        )

        if ($Records.Count -eq 0) {
            return
        }

        $this.Content = $Records

        return $this.Finish()
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Finish -Value {

        # Sort Records
        if ($this.Rule.SortDirection -eq 'Ascending') {
            $sorted = $this.Content.ToArray() | Sort-Object -Property $this.Rule.Name
        }
        else {
            $sorted = $this.Content.ToArray() | Sort-Object -Property $this.Rule.Name -Descending
        }

        return $sorted
    }

    return $bucket
}
$Static.NewSortBucketFactory = {
    param($Rule, $Next, [Bool]$Final)

    Write-Debug ("Factory Sort [{0}] Bucket" -f $Rule.Name)

    $factory = [PSCustomObject]@{
        Rule  = $Rule
        Next  = $Next
        Final = $Final
    }

    Add-Member -InputObject $factory -MemberType ScriptMethod -Name New -Value {
        if ($this.Final) {
            return (& $Static.NewFinalSortBucket $this.Rule)
        }
        else {
            return (& $Static.NewSortBucket $this.Rule $this.Next)
        }
    }

    return $factory
}

# Object Grouping
$Static.NewDataBucket = {
    param($Field, [System.Collections.ArrayList]$Buffer, [Object]$Definition, [Object]$Sorter)

    Write-Debug "Creating new data bucket"

    $bucket = [PSCustomObject]@{
        Field      = $Field
        Content    = New-Object System.Collections.ArrayList
        Buffer     = $Buffer
        Definition = $Definition
        Sorter     = $Sorter
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Add -Value {
        param($Record)
        [void] $this.Content.Add($Record)
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Build -Value {

        # Sort Records if Applicable
        if ($this.Sorter) {
            $build = $this.Sorter.Sort($this.Content)
        }
        else {
            $build = $this.Content.ToArray()
        }

        # Process Node Definition for Each Data Record
        ForEach ($record in $build) {
            $node = New-Object System.Windows.Forms.TreeNode($record.($this.Field))
            $node.Tag = $record

            # DEFAULT STATIC METHODS
            Add-Member -InputObject $node -MemberType ScriptMethod -Name SetChecked -Value $Static.TreeNodeChecked

            # CUSTOM PRE-PROCESSORS
            foreach ($processor in $this.Definition.Processors.Values) {
                & $processor $node $record | Out-Null
            }

            # CUSTOM PROPERTIES
            foreach ($property in $this.Definition.NoteProperties.GetEnumerator()) {
                Add-Member -InputObject $node -MemberType NoteProperty -Name $property.Key -Value $property.Value
            }

            # STANDARD PROPERTIES - late binding (dynamic)
            foreach ($property in $this.Definition.Properties.GetEnumerator()) {
                $node.($property.Key) = $property.Value
            }

            # CUSTOM METHODS
            foreach ($method in $this.Definition.Methods.GetEnumerator()) {
                Add-Member -InputObject $node -MemberType ScriptMethod -Name $method.Key -Value $method.Value
            }

            # SHARED BUFFER - Add to quick access ArrayList for all nodes
            [void]$this.Buffer.Add($node)

            Write-Output $node
        }
    }

    return $bucket
}
$Static.NewDataBucketFactory = {
    param($DataLabel, [System.Collections.ArrayList]$Buffer, [Object]$Definition, [Object]$Sorter)

    Write-Debug "Creating a new data bucket factory"

    $factory = [PSCustomObject]@{
        DataLabel  = $DataLabel
        Buffer     = $Buffer
        Definition = $Definition
        Sorter     = $Sorter
    }

    Add-Member -InputObject $factory -MemberType ScriptMethod -Name New -Value {
        Write-Debug "Calling New Data Bucket"
        return & $Static.NewDataBucket $this.DataLabel $this.Buffer $this.Definition $this.Sorter
    }

    return $factory
}
$Static.NewGroupBucket = {
    param($Rule, $Factory, [Object]$Definition)
                
    Write-Debug ("Factory Create [{0}] Bucket" -f $Rule.Name)

    $bucket = [PSCustomObject]@{
        Rule    = $Rule
        Factory = $Factory
        Content = @{}
        Definition = $Definition
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Add -Value {
        param($Record)

        $value = $Record.($this.Rule.Name)

        if (!$this.Content.ContainsKey($value)) {
                    
            Write-Debug "Creating Bucket For ($value)"

            $this.Content.Add($value, $this.Factory.New())
        }

        $this.Content[$value].Add($Record)
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Build -Value {
        
        $nodes = New-Object System.Collections.ArrayList
        
        # Sort Grouping Nodes
        if ($this.Rule.SortDirection -eq 'Ascending') {
            $sorted = $this.Content.GetEnumerator() | Sort-Object -Property Key
        }
        else {
            $sorted = $this.Content.GetEnumerator() | Sort-Object -Property Key -Descending
        }

        # Build the Child Nodes in Sorted Order (Hashtable Key[GroupName]:Value[ChildBucket] Pairs)
        ForEach ($pair in $sorted) {
            $node = New-Object System.Windows.Forms.TreeNode($pair.Key)

            # CUSTOMIZE OBJECT
            & $Static.ProcessDefinition $node $pair $this.Definition

            # DEFAULT STATIC METHODS
            Add-Member -InputObject $node -MemberType ScriptMethod -Name SetChecked -Value $Static.TreeNodeChecked

            $node.Nodes.AddRange( $pair.Value.Build() )
            [void] $nodes.Add($node)
        }

        return $nodes
    }

    return $bucket
}
$Static.NewGroupFactory = {
    param($Rule, $Next, [Object]$Definition)

    Write-Debug ("Creating new bucket factory [{0}]" -f $Rule.Name)

    $factory = [PSCustomObject]@{
        Rule = $Rule
        Next = $Next
        Definition = $Definition
    }

    Add-Member -InputObject $factory -MemberType ScriptMethod -Name New -Value {
        return (& $Static.NewGroupBucket $this.Rule $this.Next $this.Definition)
    }

    return $factory
}
$Static.NewConstructor = {
    param(
        [Parameter(Mandatory = $true)]
            [String]
            $DataLabel,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $GroupBy,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $SortBy,

        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $Buffer,

        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $GroupDefinition,

        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $NodeDefinition
        )

    Write-Debug ("Creating new TreeView Group Constructor {0}" -f ($GroupBy | Select-Object -Property Name | Out-String))
    Write-Debug "Data Labels Using field [$DataLabel]"

    $sort = $null

    if ($SortBy.Count -gt 1) {
        $max = $SortBy.Count - 1

        # Final sorting level
        $sort = & $Static.NewSortBucketFactory $SortBy[$max] $null $true

        # Intermediate bucket factories
        for ($i = $max - 1; $i -ge 1; $i--) {
            $sort = & $Static.NewSortBucketFactory $SortBy[$i] $sort $false
        }

        # Root level sort bucket
        $sort = & $Static.NewSortBucket $SortBy[$i] $sort
    }
    elseif ($SortBy.Count -eq 1) {
        $sort = & $Static.NewFinalSortBucket $SortBy[0]
    }

    # Final grouping level
    $factory = & $Static.NewDataBucketFactory $DataLabel $Buffer $NodeDefinition $sort

    if ($GroupBy.Count -gt 1) {
        $max = $GroupBy.Count - 1

        # Intermediate bucket factories
        for ($i = $max; $i -ge 1; $i--) {
            $factory = & $Static.NewGroupFactory $GroupBy[$i] $factory $GroupDefinition
        }

        # Root level group bucket
        $factory = & $Static.NewGroupBucket $GroupBy[$i] $factory $GroupDefinition
    }
    elseif ($GroupBy.Count -eq 1) {
        # Root level group bucket
        $factory = & $Static.NewGroupBucket $GroupBy[0] $factory $GroupDefinition
    }
    else {
        # No grouping level; generate a data bucket as the root factory
        $factory = $factory.New()
    }

    # Build the Constructor Object
    $constructor = [PSCustomObject]@{
        Tree = $factory
    }

    Add-Member -InputObject $constructor -MemberType ScriptMethod -Name AddRange -Value {
        param([System.Collections.ArrayList]$Range)
        $tree = $this.Tree
        ForEach ($record in $Range) {
            $tree.Add($record)
        }
    }

    Add-Member -InputObject $constructor -MemberType ScriptMethod -Name Add -Value {
        param($Record)
        $tree.Add($Record)
    }

    Add-Member -InputObject $constructor -MemberType ScriptMethod -Name Build -Value {
        $this.Tree.Build()
    }

    return $constructor
}

###############################################################################
# Default Handlers

$Default = @{}
$Default.AfterCheck = {
    param($sender, $e)

    if($e.Action -eq [System.Windows.Forms.TreeViewAction]::Unknown) {
        return
    }

    ForEach ($child in $e.Node.Nodes) {
        $child.SetChecked($e.Node.Checked)
    }
}
$Default.Click = {
    Param(
        # sender: the control initiating the event.
        [Parameter(Mandatory = $true, Position = 0)]
            [System.Windows.Forms.TreeView]
            $sender,

        # e: event arguments passed by the sender.
        [Parameter(Mandatory = $true, Position = 1)]
            [system.EventArgs]
            $e
    )

    # Ignore $e.Location as the coordinates are clipped to the client area of the treeview,
    # but treeview.GetNodeAt() expects full screen area coordinates.  Seems like an unusual
    # way to implement that functionality...

    # Get the TreeViewNode that was clicked (Right or Left)
    $target = $sender.GetNodeAt($sender.PointToClient([System.Windows.Forms.Control]::MousePosition))

    if ($target -ne $null) {
        $sender.SelectedNode = $target
    }
}

###############################################################################
# Window Component Constructors

function New-TreeViewTab {
    param(
        # Title of the TreeView tab.
        [Parameter(Mandatory = $true)]
            [String]
            $Title,

        # TreeView data source used to create the TreeNodes.
        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $Source,
        
        # Collection of images used by TreeNodes.
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.ImageList]
            $ImageList,

        # Static method resources.
        [Parameter(Mandatory = $true)]
            [Hashtable]
            $Static,

        # Default event handler resources.
        [Parameter(Mandatory = $true)]
            [Hashtable]
            $DefaultHandler,

        # Object containing the property overrides, event handlers, and custom properties/methods for the TreeView layout container.
        [Parameter(Mandatory = $false)]
            [PSCustomObject]
            $Definition
    )

    $Container = New-Object System.Windows.Forms.TabPage
    $Container.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Container.Name = "TreeVeiwTab"
    $Container.Text = $Title

    $TreeView = New-Object System.Windows.Forms.TreeView
    $TreeView.Name = "TreeView"
    $TreeView.Dock = [System.Windows.Forms.DockStyle]::Fill

    $TreeView.CheckBoxes = $true
    $TreeView.ImageList  = $ImageList

    [void]$Container.Controls.Add($TreeView)

    ### ARCHITECTURE PROPERTIES -----------------------------------------------
    Add-Member -InputObject $TreeView -MemberType NoteProperty -Name Static -Value $Static

    Add-Member -InputObject $TreeView -MemberType NoteProperty -Name Source -Value $Source

    Add-Member -InputObject $TreeView -MemberType NoteProperty -Name DataNodes -Value $null

    ### PROPERTIES ------------------------------------------------------------
    # Built-In
    # Late binding (dynamic)
    foreach ($property in $Definition.Properties.GetEnumerator()) {
        $TreeView.($property.Key) = $property.Value
    }

    # Custom
    foreach ($property in $Definition.NoteProperties.GetEnumerator()) {
        Add-Member -InputObject $TreeView -MemberType NoteProperty -Name $property.Key -Value $property.Value
    }

    ### EVENT HANDLERS --------------------------------------------------------
    # Defaults
    # Late binding (dynamic)
    foreach ($handler in $DefaultHandler.GetEnumerator()) {
        $TreeView."Add_$($handler.Key)"($handler.Value)
    }

    # Custom - can override defaults
    # Late binding (dynamic)
    foreach ($handler in $Definition.Handlers.GetEnumerator()) {
        $TreeView."Add_$($handler.Key)"($handler.Value)
    }

    ### CUSTOM METHODS --------------------------------------------------------
    foreach ($method in $Definition.Methods.GetEnumerator()) {
        Add-Member -InputObject $TreeView -MemberType ScriptMethod -Name $method.Key -Value $method.Value
    }

    ### Return Component Control ----------------------------------------------
    return $Container
}

function New-SettingsTab {
    param(
        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $SettingsManager,

        [Parameter(Mandatory = $true)]
            [Hashtable]
            $DockSettings
    )

    $SettingsTab = New-Object System.Windows.Forms.TabPage

    $SettingsTab.Dock = [System.Windows.Forms.DockStyle]::Fill
    $SettingsTab.Name = "SettingsTab"
    $SettingsTab.Text = "View Settings"

    ### Settings Container ----------------------------------------------------
    $SettingsContainer = New-Object System.Windows.Forms.FlowLayoutPanel
    [void]$SettingsTab.Controls.Add($SettingsContainer)

    $SettingsContainer.Dock          = [System.Windows.Forms.DockStyle]::Fill
    $SettingsContainer.BackColor     = [System.Drawing.Color]::White
    $SettingsContainer.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $SettingsContainer.WrapContents  = $false
    $SettingsContainer.AutoScroll    = $true

    ### Static Data Configuration Panel ---------------------------------------
    $DataPanel = New-DataStaticPanel $SettingsManager $DockSettings

    [void]$SettingsContainer.Controls.Add($DataPanel)

    ### Sort By Options Flow Panel -------------------------------------------
    $SortOptionsPanel = New-Object System.Windows.Forms.FlowLayoutPanel

    $SortOptionsPanel.Name          = 'SortByOptions'
    $SortOptionsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $SortOptionsPanel.WrapContents  = $false
    $SortOptionsPanel.BackColor     = [System.Drawing.Color]::White
    $SortOptionsPanel.AutoSize      = $true
    $SortOptionsPanel.AutoSizeMode  = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

    [void]$SettingsContainer.Controls.Add($SortOptionsPanel)

    # Sort By Options Static Panel --------------------------------------------
    $SortPanel = New-SortStaticPanel $SettingsManager $SortOptionsPanel

    [void]$SortOptionsPanel.Controls.Add($SortPanel)

    ### Group By Options Flow Panel -------------------------------------------
    $GroupOptionsPanel = New-Object System.Windows.Forms.FlowLayoutPanel

    $GroupOptionsPanel.Name          = 'GroupByOptions'
    $GroupOptionsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $GroupOptionsPanel.WrapContents  = $false
    $GroupOptionsPanel.BackColor     = [System.Drawing.Color]::White
    $GroupOptionsPanel.AutoSize      = $true
    $GroupOptionsPanel.AutoSizeMode  = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

    [void]$SettingsContainer.Controls.Add($GroupOptionsPanel)

    # Group By Options Static Panel -------------------------------------------
    $GroupPanel = New-GroupStaticPanel $SettingsManager $GroupOptionsPanel

    [void]$GroupOptionsPanel.Controls.Add($GroupPanel)

    ### Return Component Control ----------------------------------------------
    return $SettingsTab
}

### Data Static Panel Components ----------------------------------------------

function New-DataStaticPanel {
    param(
        # The settings collection used to manage registered settings between controls.
        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $SettingsManager,

        # The settings for the Dock/Undock button.
        [Parameter(Mandatory = $true)]
            [Hashtable]
            $DockSettings
    )

    $DataNodePanel = New-Object System.Windows.Forms.Panel

    $DataNodePanel.BackColor = [System.Drawing.Color]::White

    $registration = [PSCustomObject]@{
        Name = [String]::Empty
        Setting = $DataNodePanel
    }

    # Static property for the sort level settings to check when removing registrations
    Add-Member -InputObject $DataNodePanel -MemberType NoteProperty -Name SettingType -Value 'DataNode'

    Add-Member -InputObject $DataNodePanel -MemberType NoteProperty -Name SettingsCollection -Value $SettingsManager.GroupBy

    Add-Member -InputObject $DataNodePanel -MemberType NoteProperty -Name Registration -Value $registration

    Add-Member -InputObject $DataNodePanel -MemberType NoteProperty -Name Registered -Value $false

    Add-Member -InputObject $DataNodePanel -MemberType ScriptMethod -Name Unregister -Value {
        if(!$this.Registered) {
            return
        }
        Write-Debug ("Unregistering: {0}`t {1}" -f $this.Registration.Name, $this.GetHashCode())

        $this.Registered = $false

        [void]$this.SettingsCollection.Remove($this.Registration)

        $this.Controls['DisplayFieldSelector'].SelectedIndex = 0
    }

    ### Undock Button ---------------------------------------------------------
    $UndockButton = New-UndockButton @DockSettings
    [void]$DataNodePanel.Controls.Add($UndockButton)

    ### Apply Button (SettingsManager) ----------------------------------------
    $ApplyButton = New-Object System.Windows.Forms.Button
    $ApplyButton.Name = "ApplySettingsButton"
    $ApplyButton.Text = "Apply"

    $ApplyButton.Dock = [System.Windows.Forms.DockStyle]::Left

    Add-Member -InputObject $ApplyButton -MemberType NoteProperty -Name Settings -Value $SettingsManager

    $ApplyButton.Add_Click({$this.Settings.Apply()})

    [void]$DataNodePanel.Controls.Add($ApplyButton)

    ### Field Selector --------------------------------------------------------
    $FieldSelector = New-Object System.Windows.Forms.ComboBox

    $FieldSelector.Name = "DisplayFieldSelector"
    $FieldSelector.Width = 85
    $FieldSelector.Dock = [System.Windows.Forms.DockStyle]::Left

    # Settings Referenced used by Registration Handler
    Add-Member -InputObject $FieldSelector -MemberType NoteProperty -Name SettingsCollection -Value $SettingsManager.GroupBy

    # Data Node Label Registration Handler
    $FieldSelector.Add_SelectedValueChanged({
        $current = $this.Parent # Settings Panel

        if ($this.SelectedValue -eq [String]::Empty) {
            $current.Unregister()
            return
        }

        # Unregister conflicting Group registrations
        $registered = $this.SettingsCollection.ToArray()
        foreach ($field in $registered) {
            if (!$field.Setting.Equals($current) -and $field.Name -eq $this.SelectedValue) {
                if ($field.Setting.SettingType -eq 'Group') {
                    $field.Setting.Unregister()
                }
            }
        }

        # Set registration field name
        $current.Registration.Name = $this.SelectedValue

        # Add registration
        Write-Debug ("Field Registered: {0}`t{1}" -f $current.Registration.Name, $current.GetHashCode())
        if (!$current.Registered) {
            [void]$this.SettingsCollection.Add($current.Registration)
            $current.Registered = $true
        }
    })

    # Set leaf data node label field selector reference for use by other controls
    $SettingsManager.LeafSelector = $FieldSelector

    [void]$DataNodePanel.Controls.Add($FieldSelector)

    ### Panel Label -----------------------------------------------------------
    $Label = New-Object System.Windows.Forms.Label
    $Label.Dock = [System.Windows.Forms.DockStyle]::Left
    $Label.Text = "Data Node Label:"
    $Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    [void]$DataNodePanel.Controls.Add($Label)

    ### Resize Panel ----------------------------------------------------------
    $width = 0
    foreach ($ctrl in $DataNodePanel.Controls) {
        $width += $ctrl.width
    }
    $DataNodePanel.Width = $width + 10
    $DataNodePanel.Height = 22

    ### Return Component Control ----------------------------------------------
    return $DataNodePanel
}

function New-UndockButton {
    param(
        # Reference to the parent window to bring the application back into view after undocking.
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Form]
            $Window,

        # SortedTreeView control container. This is the package that is docked/undocked.
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Control]
            $Component,

        # Parent control that contains the DockPackage at initialization.
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Control]
            $Target
    )

    $Button = New-Object System.Windows.Forms.Button
    $Button.Name = "UndockButton"
    $Button.Text = "Undock"

    $Button.Dock = [System.Windows.Forms.DockStyle]::Left

    Add-Member -InputObject $Button -MemberType NoteProperty -Name Window -Value $Window

    Add-Member -InputObject $Button -MemberType NoteProperty -Name DockPackage -Value $Component

    Add-Member -InputObject $Button -MemberType NoteProperty -Name DockTarget -Value $Target

    $Button.Add_Click({$this.Undock()})
    Add-Member -InputObject $Button -MemberType ScriptMethod -Name Undock -Value {
        $form = New-Object System.Windows.Forms.Form
        $form.Text          = "Baseline Security Scan Viewer"
        $form.Size          = New-Object System.Drawing.Size(300, 600)
        $form.StartPosition = [System.Windows.Forms.FormStartPosition]::CenterScreen

        $form.Add_Closing({
            param($sender, $e)
            $this.Redock()
        })

        Add-Member -InputObject $form -MemberType NoteProperty -Name DockPackage -Value $this.DockPackage
        Add-Member -InputObject $form -MemberType NoteProperty -Name DockTarget -Value $this.DockTarget
        Add-Member -InputObject $form -MemberType NoteProperty -Name DockButton -Value $this
        Add-Member -InputObject $form -MemberType ScriptMethod -Name Redock -Value {
            $this.SuspendLayout()
            $this.DockPackage.SuspendLayout()
            $this.DockTarget.SuspendLayout()

            $this.Controls.Clear()
            $this.DockTarget.Controls.Add($this.DockPackage)
            $this.DockTarget.Parent.Panel1Collapsed = $false
            $this.DockButton.Enabled = $true

            $this.DockTarget.ResumeLayout()
            $this.DockPackage.ResumeLayout()
            $this.DockTarget.PerformLayout()
        }

        $this.DockPackage.SuspendLayout()
        $this.DockTarget.SuspendLayout()

        $this.DockTarget.Controls.Clear()
        $this.DockTarget.Parent.Panel1Collapsed = $true
        $this.Enabled = $false

        $form.Controls.Add($this.DockPackage)

        $this.DockTarget.ResumeLayout()
        $this.DockPackage.ResumeLayout()
        [void]$form.Show($this.Window)
    }

    ### Return Component Control ----------------------------------------------
    return $Button
}

### Group Static Panel Components ---------------------------------------------

function New-GroupStaticPanel {
    param(
        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $SettingsManager,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.FlowLayoutPanel]
            $OptionsPanel
    )

    $Panel = New-Object System.Windows.Forms.Panel

    $Panel.Name   = "GroupStaticPanel"
    $Panel.Height = 22

    ### Label -----------------------------------------------------------------
    $Label = New-Object System.Windows.Forms.Label
    $Label.Dock      = [System.Windows.Forms.DockStyle]::Left
    $Label.Text      = "Group Level"
    $Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

    [void]$Panel.Controls.Add($Label)

    ### Add Group Button ------------------------------------------------------
    $ButtonParams = @{
        FieldNames        = $SettingsManager.Fields
        SettingCollection = $SettingsManager.GroupBy
        OptionsPanel      = $OptionsPanel
        Type              = "Group"
    }
    $Button = New-SettingStaticButton @ButtonParams

    [void]$Panel.Controls.Add($Button)

    ### Return Component Control ----------------------------------------------
    return $Panel
}

### Sort Static Panel Components ----------------------------------------------

function New-SortStaticPanel {
    param(
        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $SettingsManager,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.FlowLayoutPanel]
            $OptionsPanel
    )

    $Panel = New-Object System.Windows.Forms.Panel

    $Panel.Name   = "SortStaticPanel"
    $Panel.Height = 22

    ### Label -----------------------------------------------------------------
    $Label = New-Object System.Windows.Forms.Label
    $Label.Dock      = [System.Windows.Forms.DockStyle]::Left
    $Label.Text      = "Sort Level"
    $Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

    [void]$Panel.Controls.Add($Label)

    ### Add Group Button ------------------------------------------------------
    $ButtonParams = @{
        FieldNames        = $SettingsManager.Fields
        SettingCollection = $SettingsManager.SortBy
        OptionsPanel      = $OptionsPanel
        Type              = "Sort"
    }
    $Button = New-SettingStaticButton @ButtonParams

    [void]$Panel.Controls.Add($Button)

    ### Return Component Control ----------------------------------------------
    return $Panel
}

### Common Components ---------------------------------------------------------

function New-SettingStaticButton {
    param(
        # The list of available data fields.
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $FieldNames,

        # The collection of fields already registered for grouping data by.
        [Parameter(Mandatory = $true)]
        [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $SettingCollection,

        # The layout control that new group settings are displayed within.
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.FlowLayoutPanel]
            $OptionsPanel,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Group","Sort")]
            [String]
            $Type
    )

    $Button = New-Object System.Windows.Forms.Button

    $Button.Text   = "Add"
    $Button.Dock   = [System.Windows.Forms.DockStyle]::Left
    $Button.Height = 21
    $Button.Width  = 50

    # Attach references for use by the objects handlers.
    Add-Member -InputObject $Button -MemberType NoteProperty -Name FieldNames -Value $FieldNames
    Add-Member -InputObject $Button -MemberType NoteProperty -Name Settings -Value $SettingCollection
    Add-Member -InputObject $Button -MemberType NoteProperty -Name OptionsPanel -Value $OptionsPanel
    Add-Member -InputObject $Button -MemberType NoteProperty -Name Type -Value $Type

    # Handler for adding new settings panels to the OptionsPanel
    $Button.Add_Click({
        if ($this.Settings.Count -eq $this.FieldNames.Count -1) {
            [System.Windows.Forms.MessageBox]::Show(
                "Maximum number of field settings reached!",
                "View Settings",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Exclamation
            )
            return
        }

        Write-Debug ("Registered Fields:`r`n{0}" -f ($this.Settings | Format-Table | Out-String))

        # Find first unregistered field name
        $filtered = New-Object System.Collections.ArrayList
        [void]$filtered.AddRange($this.FieldNames)
        foreach ($registration in $this.Settings) {
            [void]$filtered.Remove($registration.Name)
        }
        $available = $filtered[0]

        Write-Debug ("Avaliable Field:`r`n{0}" -f $available)

        switch -Regex ($this.Type) {
            '^Sort$' {
                $LabelText = "Sort By:"
            }
            '^Group$' {
                $LabelText = "Group By:"
            }
        }

        $PanelParams = @{
            LabelText         = $LabelText
            FieldNames        = $this.FieldNames
            Type              = $this.Type
            SettingCollection = $this.Settings
            InitialValue      = $available
        }
        $Panel = New-SettingPanel @PanelParams

        [void]$this.OptionsPanel.Controls.Add($Panel)
    })

    ### Return Component Control ----------------------------------------------
    return $Button
}

function New-SettingPanel {
    param(
        [Parameter(Mandatory = $true)]
            [String]
            $LabelText,

        [Parameter(Mandatory = $true)]
            [System.Collections.ArrayList]
            $FieldNames,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Group","Sort")]
            [String]
            $Type,

        [Parameter(Mandatory = $true)]
            [System.Collections.ArrayList]
            [AllowEmptyCollection()]
            $SettingCollection,

        [Parameter(Mandatory = $true)]
            [String]
            $InitialValue
    )

    $Remove = New-Object System.Windows.Forms.Button
    $Remove.Dock = [System.Windows.Forms.DockStyle]::Left
    $Remove.Text = "Remove"
    $Remove.Height = 21
    $Remove.Width = 75
    [void]$Remove.Add_Click({
        $this.Parent.Unregister()
    })

    $Label = New-Object System.Windows.Forms.Label
    $Label.Dock = [System.Windows.Forms.DockStyle]::Left
    $Label.Width = 60
    $Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $Label.Text = $LabelText

    $FieldSelector = New-Object System.Windows.Forms.ComboBox
    $FieldSelector.Dock = [System.Windows.Forms.DockStyle]::Left
    $FieldSelector.DataSource = $FieldNames.ToArray()
    $FieldSelector.Width = 85

    Add-Member -InputObject $FieldSelector -MemberType NoteProperty -Name SettingCollection -Value $SettingCollection

    $SortSelector = New-Object System.Windows.Forms.ComboBox
    $SortSelector.Dock = [System.Windows.Forms.DockStyle]::Left
    $SortSelector.DataSource = @("Ascending", "Descending")
    $SortSelector.Width = 80
    $SortSelector.Add_SelectedValueChanged({
        $this.Parent.Registration.SortDirection = $this.SelectedValue
    })

    $Panel = New-Object System.Windows.Forms.Panel
    $Panel.Height = 22
    $Panel.Width = $Remove.Width + $SortSelector.Width + $Label.Width + $FieldSelector.Width

    [void]$Panel.Controls.Add($SortSelector)
    [void]$Panel.Controls.Add($FieldSelector)
    [void]$Panel.Controls.Add($Label)
    [void]$Panel.Controls.Add($Remove)

    $registration = [PSCustomObject]@{
        Name          = $InitialValue
        SortDirection = "Ascending"
        Setting       = $Panel
    }

    Add-Member -InputObject $Panel -MemberType NoteProperty -Name SettingCollection -Value $SettingCollection

    Add-Member -InputObject $Panel -MemberType NoteProperty -Name Registration -Value $registration

    Add-Member -InputObject $Panel -MemberType NoteProperty -Name SettingType -Value $Type

    Add-Member -InputObject $Panel -MemberType NoteProperty -Name Initialized -Value $false

    Add-Member -InputObject $Panel -MemberType ScriptMethod -Name Unregister -Value {
        [void]$this.Parent.Controls.Remove($this)
        $this.SettingCollection.Remove($this.Registration)
        Write-Debug ("Unregistered: {0}`t {1}" -f $this.Registration.Name, $this.GetHashCode())
    }

    # Set SelectedItem and the SelectedValueChanged last to prevent race conditions/issues with the
    # initialization of the controls and event handlers.
    [void]$SettingCollection.Add($registration)

    $FieldSelector.Add_SelectedValueChanged({
        $current = $this.Parent # Setting Panel

        if (!$current.Initialized) {
            $this.SelectedItem = $current.Registration.Name
            $current.Initialized = $true
            return
        }

        $registered = $this.SettingCollection.ToArray()
        foreach ($field in $registered) {
            if (!$field.Setting.Equals($current) -and $field.Name -eq $this.SelectedValue) {
                $field.Setting.Unregister()
            }
        }

        $current.Registration.Name = $this.SelectedValue
        Write-Debug ("Field Registered: {0}`t{1}" -f $current.Registration.Name, $current.GetHashCode())
    })

    ### Return Component Control ----------------------------------------------
    return $Panel
}

###############################################################################
# Module Class Objects

<#
.SYNOPSIS
    Provides single source for managing view setting collections, field names
    and state management.
#>
function New-SettingsManager {
    param(
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.TabControl]
            $Component,

        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.TreeView]
            $TreeView,

        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $GroupDefinition,

        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $NodeDefinition
    )

    ### Properties ------------------------------------------------------------
    $SettingsManager = [PSCustomObject]@{
        # Top level container (TabControl)
        Component       = $Component

        # TreeView for which this object manages the view settings
        TreeView        = $TreeView

        # Data field names
        Fields          = New-Object System.Collections.ArrayList

        # TreeNode sorting and grouping settings
        SortBy          = New-Object System.Collections.ArrayList
        GroupBy         = New-Object System.Collections.ArrayList

        # Leaf TreeNode label source field
        LeafSelector    = $null

        # TreeNode object definitions
        GroupDefinition = $GroupDefinition
        NodeDefinition  = $NodeDefinition

        # State flag
        Valid           = $false
    }

    ### Methods ---------------------------------------------------------------
    Add-Member -InputObject $SettingsManager -MemberType ScriptMethod -Name RegisterFields -Value {
        param(
            [Parameter(Mandatory = $true)]
                [System.Array]
                $fields
        )

        if ($this.Fields.Count -gt 0) {
            $this.Fields.Clear()
        }
        $this.Fields.AddRange($fields)

        # Prompt Flag if the View Settings needs to be updated by the user
        $RequireUpdate = $false

        # Verify DataSource is set for the DataLabel Selector
        if (!$this.LeafSelector.DataSource) {
            $this.LeafSelector.DataSource = @([String]::Empty) + @($fields)
            $RequireUpdate = $true
        }

        # Validate grouped fields exist on data objects
        foreach ($field in $this.GroupBy) {
            if ($fields -notcontains $field.Name) {
                $field.Setting.Unregister()
                $this.LeafSelector.DataSource = @([String]::Empty) + @($fields)
                $RequireUpdate = $true
            }
        }

        if ($RequireUpdate) {
            $this.Valid = $false
        }
    }

    Add-Member -InputObject $SettingsManager -MemberType ScriptMethod -Name Apply -Value {
        Write-Debug "Applying View Settings..."

        # Data Node Label Field
        $DataLabel = $this.LeafSelector.SelectedValue

        if ([String]::IsNullOrEmpty($DataLabel)) {
            [System.Windows.Forms.MessageBox]::Show(
                "You must select a [Data Node Label] field!",
                "Compliance View Settings",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Exclamation
            )
            return
        }

        $this.Valid = $true
        $this.GroupBy.TrimToSize()

        # Filter the LeafSelector registration from the group fields
        $GroupFields = New-Object System.Collections.ArrayList
        $GroupFields.AddRange($this.GroupBy)
        $GroupFields.Remove($this.LeafSelector.Parent.Registration)

        Write-Debug "Building Group Buckets: $($this.GroupBy)"

        # Quick Access ArrayList for all of the data nodes
        $DataNodes = New-Object System.Collections.ArrayList

        $constructor = & $this.TreeView.Static.NewConstructor $DataLabel $GroupFields $this.SortBy $DataNodes $this.GroupDefinition $this.NodeDefinition
        $constructor.AddRange($this.TreeView.Source)

        $this.TreeView.SuspendLayout()
        $this.TreeView.Nodes.Clear()
        $this.TreeView.Nodes.AddRange( $constructor.Build() )
        $this.TreeView.ResumeLayout()

        # Append Quick Access Data Node List
        $this.TreeView.DataNodes = $DataNodes

        $this.Component.SelectedIndex = 0
    }

    Add-Member -InputObject $SettingsManager -MemberType ScriptMethod -Name PromptUser -Value {
        [System.Windows.Forms.MessageBox]::Show(
            "Update View Settings",
            "Data fields or format changed.`r`nUpdate View Settings.",
            [System.Windows.Forms.MessageBoxButtons]::OK,
            [System.Windows.Forms.MessageBoxIcon]::Exclamation
        )

        $this.Component.SelectedIndex = 1
    }

    return $SettingsManager
}