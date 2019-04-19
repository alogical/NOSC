<#
.SYNOPSIS
    Custom TreeView control with display and filter settings.

.DESCRIPTION
    A TreeView control wrapped in a TabContainer that provides data grouping
    and sorting functionality built in.

.NOTES
    #
    # Displaying Data
    #
    A new SortedTreeView control is instantiated through a call to the
    Intialize-Components function.
    
    The TreeView can be populated by setting the $container.Tree.Source
    property.  Data is expected to be supplied in a flat data table format
    of record objects, eg. no nested data structures (think .csv file type
    data).  The Source property is a System.Collections.ArrayList, and can
    accept a large array of data using the Source.AddRange([array]) method.
    
    After the TreeView's Source collection has been populated with data, it
    can be displayed by prompting the user to configure the view settings with
    $container.Settings.PromptUser().  If view settings have already been
    configured or loaded than data can be displayed directly by calling the
    $container.Settings.Apply() method.

    The default parameter set 'UserSettings' wraps the TreeView inside of a
    TabControl container with two tabs; the first being the TreeView and the
    second being a settings management tab.  If you wish to manage the TreeView
    display settings programmatically, you can use the settings method:
    $container.Settings.Load().

    The 'ManagedSettings' parameter set removes the TabControl wrapper and
    settings user interface tab.  If you use this method of constructing the
    TreeView, than you must call $container.Settings.Load() to set the rules
    for grouping, sorting, and leaf label view settings.
    
    #
    # Customization
    #
    Functionality of the TreeView control can be further extended by passing
    Definition objects for TreeView, TreeNode(Group), and TreeNode(Data).
    
    The definition objects must contain all of the hashtable collections
    specified in the format, even if the collection is empty.  Otherwise, an
    error will be thrown during the construction of the objects.
    
    The 'Properties' collection of the definition may only contain property
    names for properties that exist by default on the object as defined by the
    System.Windows.Forms class of the object.  Similiarly, any value specified
    for a property must meet the expectations and requirements for the property
    as defined by the objects .Net class.
    
    The 'NoteProperties' collection of the definition cannot contain the same
    name of an object member that is already defined for the object by it's .Net
    class.  NoteProperties are *attached* to the object after it's creation by
    Powershell, and can contain any value.
    
    The 'Methods' collection of the definition cannot have the same name as any
    object members defined by the object's .Net class or any of the previoulsy
    defined NoteProperties.  The Methods collection expects scriptblocks for
    values, and will throw an error otherwise.
    
    The 'Handlers' collection of the definition may only contain names of event
    defined by the objects .Net class.  The values for each entry must be a
    scriptblock.
    
    The only difference between the definition of a TreeView and a TreeNode is
    the 'Processors' collection.  Node processors are scriptblocks called against
    each node during it's creation, allowing the node to be further customized
    at runtime based on the data used to create the node.  The key name of the
    processor is only locally significant to the collection itself, and may only
    contain scriptblocks as values.
    
    The NoteProperty names 'Static', 'Source', and 'DataNodes' are part of the
    SortedTreeView Architecture and may not be used in the NoteProperties
    collection of a TreeView definition.
    
        The TreeView Definition object is constructed by the caller and passed
        to Initialize-Components -TreeDefinition property.
        -- Format:
            [PSCustomObject]@{
                # [System.Windows.Forms.TreeView] Built-In Properties
                Properties     = @{}
                
                # Powershell Custom NoteProperties
                NoteProperties = @{}
                
                # --- SCRIPTBLOCK VALUES --- #
                # Powershell ScriptMethod Definitions
                Methods        = @{}
                
                # [System.Windows.Forms.TreeView] Event Handlers
                Handlers       = @{}
            }
            
        The TreeNode Definition objects for Group nodes and Data nodes use
        the same definition format.  These definition objects are passed to
        the -GroupDefinition and -NodeDefinition parameters respectfully.
         -- Format:
            [PSCustomObject]@{
                # [System.Windows.Forms.TreeNode] Built-In Properties
                Properties     = @{}
                
                # Powershell Custom NoteProperties
                NoteProperties = @{}

                # --- SCRIPTBLOCK VALUES --- #
                # Powershell ScriptMethod Definitions
                Methods        = @{}

                # [System.Windows.Forms.TreeNode] Event Handlers
                Handlers       = @{}

                # Processing Methods. Used to customize a TreeNode during creation.
                Processors     = @{}
            }

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
    [CmdletBinding(DefaultParameterSetName = 'UserSettings')]
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
        
        # Collection of function callbacks executed by the application at runtime.
        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $OnLoad,

        # The data to be displayed by the TreeView.
        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $Source,

        # Collection of images to be used for TreeNodes.
        [Parameter(Mandatory = $false)]
            [System.Windows.Forms.ImageList]
            $ImageList,

        # TreeView customization definition.
        [Parameter(Mandatory = $false)]
            [PSCustomObject]
            $TreeDefinition,

        # Group TreeNode customization definition.
        [Parameter(Mandatory = $false)]
            [PSCustomObject]
            $GroupDefinition,

        # Data TreeNode customization definition.
        [Parameter(Mandatory = $false)]
            [PSCustomObject]
            $NodeDefinition,

        # Title of the TabPage containing the TreeView.
        [Parameter(Mandatory = $false, ParameterSetName = 'UserSettings')]
            [String]
            $Title = "TreeView",

        # Adds undock button to tool bar allowing the control to be undocked into a separate window.
        [Parameter(Mandatory = $false, ParameterSetName = 'UserSettings')]
            [Switch]
            $Undockable,

        # Removes the view settings tab from.
        [Parameter(Mandatory = $true, ParameterSetName = 'ManagedSettings')]
            [Switch]
            $NoSettingPanel
    )
    $TreeParams = @{
        Source         = $Source
        ImageList      = $ImageList
        Static         = $Static
        DefaultHandler = $Default
        Definition     = $TreeDefinition
    }

    switch ($PSCmdlet.ParameterSetName)
    {
        'UserSettings' {
            $Container = New-Object System.Windows.Forms.TabControl
            $Container.Dock = [System.Windows.Forms.DockStyle]::Fill

            ### TreeView Container --------------------------------------------
            $TreeParams.Title = $Title
            $TreeViewTab = New-TreeViewTab @TreeParams

            $Container.Controls.Add($TreeViewTab)
            Add-Member -InputObject $Container -MemberType NoteProperty -Name TreeView -Value $TreeViewTab.Controls['TreeView']

            # SettingsManager Parameter Set
            $SettingParams = @{
                Component       = $Container
                TreeView        = $TreeViewTab.Controls["TreeView"]
                GroupDefinition = $GroupDefinition
                NodeDefinition  = $NodeDefinition
            }
            $SettingsManager = New-SettingsManager @SettingParams

            $SettingsTabParams = @{
                SettingsManager = $SettingsManager
            }

            if ($Undockable)
            {
                $SettingsTabParams.DockSettings = @{
                    Window    = $Window
                    Component = $Container
                    Target    = $Parent
                }
            }

            $SettingsTab = New-SettingsTab @SettingsTabParams

            $Container.Controls.Add($SettingsTab)

        }
        'ManagedSettings' {
            $Container = New-Object System.Windows.Forms.Panel
            $Container.Dock = [System.Windows.Forms.DockStyle]::Fill

            $TreeView = New-TreeView @TreeParams

            # SettingsManager Parameter Set
            $SettingParams = @{
                Component       = $Container
                TreeView        = $TreeView
                GroupDefinition = $GroupDefinition
                NodeDefinition  = $NodeDefinition
            }
            $SettingsManager = New-SettingsManager @SettingParams

            $Container.Controls.Add( $TreeView )
            Add-Member -InputObject $Container -MemberType NoteProperty -Name TreeView -Value $TreeView
        }
    }

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

    if ($Definition) {
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

            # DEFINITION PROCESSING
            if ($this.Definition) {
                # CUSTOM PRE-PROCESSORS
                foreach ($processor in $this.Definition.Processors.Values) {
                    & $processor $node $record | Out-Null
                }

                # CUSTOM PROPERTIES
                foreach ($property in $this.Definition.NoteProperties.GetEnumerator()) {
                    Add-Member -InputObject $node -MemberType NoteProperty -Name $property.Key -Value $property.Value
                }

                # BUILT-IN PROPERTIES - late binding (dynamic)
                foreach ($property in $this.Definition.Properties.GetEnumerator()) {
                    $node.($property.Key) = $property.Value
                }

                # CUSTOM METHODS
                foreach ($method in $this.Definition.Methods.GetEnumerator()) {
                    Add-Member -InputObject $node -MemberType ScriptMethod -Name $method.Key -Value $method.Value
                }
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
        if ([String]::IsNullOrEmpty($value))
        {
            $value = [String]::Empty
        }

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

        # Second level nodes (group name is null for this level)
        $bottom = New-Object System.Collections.ArrayList

        # Build the Child Nodes in Sorted Order (Hashtable Key[GroupName]:Value[ChildBucket] Pairs)
        ForEach ($pair in $sorted) {
            if ([String]::IsNullOrEmpty($pair.Key))
            {
                [void]$bottom.AddRange( $pair.Value.Build() )
                continue
            }
            $node = New-Object System.Windows.Forms.TreeNode($pair.Key)
            $node.ForeColor = [System.Drawing.Color]::FromArgb($this.Rule.Color)

            # CUSTOMIZE OBJECT
            & $Static.ProcessDefinition $node $pair $this.Definition

            # DEFAULT STATIC METHODS
            Add-Member -InputObject $node -MemberType ScriptMethod -Name SetChecked -Value $Static.TreeNodeChecked

            $node.Nodes.AddRange( $pair.Value.Build() )
            [void] $nodes.Add($node)
        }

        if ($bottom.Count -gt 0)
        {
            [void]$nodes.AddRange($bottom.ToArray())
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

function New-TreeView {
    param(
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
            $Definition = $null
    )

    $TreeView = New-Object System.Windows.Forms.TreeView
    $TreeView.Name = "TreeView"
    $TreeView.Dock = [System.Windows.Forms.DockStyle]::Fill

    $TreeView.CheckBoxes = $true
    $TreeView.ImageList  = $ImageList

    ### ARCHITECTURE PROPERTIES -----------------------------------------------
    Add-Member -InputObject $TreeView -MemberType NoteProperty -Name Static -Value $Static

    Add-Member -InputObject $TreeView -MemberType NoteProperty -Name Source -Value $Source

    Add-Member -InputObject $TreeView -MemberType NoteProperty -Name DataNodes -Value $null

    if ($Definition) {
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
    }

    return $TreeView
}

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
            $Definition = $null
    )

    $Container = New-Object System.Windows.Forms.TabPage
    $Container.Dock = [System.Windows.Forms.DockStyle]::Fill
    $Container.Name = "TreeVeiwTab"
    $Container.Text = $Title

    $TreeParams = @{
        Source = $Source
        ImageList = $ImageList
        Static = $Static
        DefaultHandler = $DefaultHandler
        Definition = $Definition
    }
    [void]$Container.Controls.Add( (New-TreeView @TreeParams) )

    ### Return Component Control ----------------------------------------------
    return $Container
}

function New-SettingsTab {
    param(
        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $SettingsManager,

        [Parameter(Mandatory = $false)]
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

    ### Menus -----------------------------------------------------------------
    if ($DockSettings)
    {
        $MenuStrip = New-SettingMenus $SettingsManager $DockSettings
    }
    else
    {
        $MenuStrip = New-SettingMenus $SettingsManager
    }
    [void]$SettingsTab.Controls.Add($MenuStrip)

    ### Static Data Configuration Panel ---------------------------------------
    $DataPanel = New-DataStaticPanel $SettingsManager

    [void]$SettingsContainer.Controls.Add($DataPanel)

    ### Sort By Options Flow Panel -------------------------------------------
    $OptionsPanel = New-Object System.Windows.Forms.FlowLayoutPanel

    $OptionsPanel.Name          = 'SortByOptions'
    $OptionsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $OptionsPanel.WrapContents  = $false
    $OptionsPanel.BackColor     = [System.Drawing.Color]::White
    $OptionsPanel.AutoSize      = $true
    $OptionsPanel.AutoSizeMode  = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

    [void]$SettingsContainer.Controls.Add($OptionsPanel)
    $SettingsManager.SortLayout = $OptionsPanel

    # Sort By Options Static Panel --------------------------------------------
    $SortPanel = New-SortStaticPanel $SettingsManager $OptionsPanel

    [void]$OptionsPanel.Controls.Add($SortPanel)

    ### Group By Options Flow Panel -------------------------------------------
    $OptionsPanel = New-Object System.Windows.Forms.FlowLayoutPanel

    $OptionsPanel.Name          = 'GroupByOptions'
    $OptionsPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    $OptionsPanel.WrapContents  = $false
    $OptionsPanel.BackColor     = [System.Drawing.Color]::White
    $OptionsPanel.AutoSize      = $true
    $OptionsPanel.AutoSizeMode  = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

    [void]$SettingsContainer.Controls.Add($OptionsPanel)
    $SettingsManager.GroupLayout = $OptionsPanel

    # Group By Options Static Panel -------------------------------------------
    $GroupPanel = New-GroupStaticPanel $SettingsManager $OptionsPanel

    [void]$OptionsPanel.Controls.Add($GroupPanel)

    ### Return Component Control ----------------------------------------------
    return $SettingsTab
}

### Data Static Panel Components ----------------------------------------------

function New-DataStaticPanel {
    param(
        # The settings collection used to manage registered settings between controls.
        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $SettingsManager
    )

    $Panel = New-Object System.Windows.Forms.Panel
    $Panel.BackColor = [System.Drawing.Color]::White

    ### Field Selector --------------------------------------------------------
    $LeafSelector = New-Object System.Windows.Forms.ComboBox
    $LeafSelector.Name = "DisplayFieldSelector"
    $LeafSelector.Width = 85
    $LeafSelector.Dock = [System.Windows.Forms.DockStyle]::Left
    $LeafSelector.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList

    # Settings Referenced used by Registration Handler
    Add-Member -InputObject $LeafSelector -MemberType NoteProperty -Name SettingsManager -Value $SettingsManager

    Add-Member -InputObject $LeafSelector -MemberType NoteProperty -Name Registered -Value $false

    # Data Node Label Registration Handler
    $LeafSelector.Add_SelectedValueChanged({
        $SelectedValue = $this.Items[$this.SelectedIndex]
        if ($SelectedValue -eq [String]::Empty) {
            $this.Unregister()
            return
        }

        # Unregister conflicting Group registrations
        $registered = $this.SettingsManager.GroupBy.ToArray()
        foreach ($field in $registered) {
            if ($field.Name -eq $SelectedValue) {
                $field.Setting.Unregister()
            }
        }

        # Register field name
        $this.SettingsManager.LeafLabel = $SelectedValue
        $this.Registered = $true
        Write-Debug ("Leaf Label Registered: {0}" -f $SelectedValue)
    })

    Add-Member -InputObject $LeafSelector -MemberType ScriptMethod -Name Unregister -Value {
        if(!$this.Registered) {
            return
        }
        $this.SettingsManager.LeafLabel = [String]::Empty
        $this.Registered = $false
        $this.SelectedIndex = 0
        Write-Debug ("Unregistering Leaf Label: {0}" -f $this.Items[$this.SelectedIndex])
    }

    # Set leaf data node label field selector reference for use by other controls
    $SettingsManager.LeafSelector = $LeafSelector

    [void]$Panel.Controls.Add($LeafSelector)

    ### Panel Label -----------------------------------------------------------
    $Label = New-Object System.Windows.Forms.Label
    $Label.Dock = [System.Windows.Forms.DockStyle]::Left
    $Label.Text = "Data Node Label:"
    $Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    [void]$Panel.Controls.Add($Label)

    ### Resize Panel ----------------------------------------------------------
    $width = 0
    foreach ($ctrl in $Panel.Controls) {
        $width += $ctrl.width
    }
    $Panel.Width = $width + 10
    $Panel.Height = 22

    ### Return Component Control ----------------------------------------------
    return $Panel
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
        SettingsManager   = $SettingsManager
        OptionsPanel      = $OptionsPanel
        Type              = "Group"
    }
    $Button = New-AddOptionButton @ButtonParams

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
        SettingsManager   = $SettingsManager
        OptionsPanel      = $OptionsPanel
        Type              = "Sort"
    }
    $Button = New-AddOptionButton @ButtonParams

    [void]$Panel.Controls.Add($Button)

    ### Return Component Control ----------------------------------------------
    return $Panel
}

### Common Components ---------------------------------------------------------

function New-AddOptionButton {
    param(
        # The SettingsManager object.
        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $SettingsManager,

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
    Add-Member -InputObject $Button -MemberType NoteProperty -Name SettingsManager -Value $SettingsManager

    switch ($Type)
    {
        'Group' {
            Add-Member -InputObject $Button -MemberType NoteProperty -Name Settings -Value $SettingsManager.GroupBy
        }
        'Sort' {
            Add-Member -InputObject $Button -MemberType NoteProperty -Name Settings -Value $SettingsManager.SortBy
        }
    }

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
        [void]$filtered.AddRange($this.SettingsManager.Fields.ToArray())
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
            Type              = $this.Type
            InitialValue      = $available
            SettingsManager   = $this.SettingsManager
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
            [PSCustomOBject]
            $SettingsManager,

        [Parameter(Mandatory = $true)]
            [String]
            $LabelText,

        [Parameter(Mandatory = $true)]
        [ValidateSet("Group","Sort")]
            [String]
            $Type,

        [Parameter(Mandatory = $true)]
            [String]
            $InitialValue,

        [Parameter(Mandatory = $false)]
        [ValidateSet("Ascending","Descending")]
            [String]
            $SortDirection,

        [Parameter(Mandatory = $false)]
            [Int32]
            $Color = 0
    )

    $Remove = New-Object System.Windows.Forms.Button
    $Remove.Dock = [System.Windows.Forms.DockStyle]::Left
    $Remove.Text = "Remove"
    $Remove.Height = 21
    $Remove.Width = 75
    $Remove.Add_Click({
        # Call the setting panel method.
        $this.Parent.Unregister()
    })

    $Label = New-Object System.Windows.Forms.Label
    $Label.Dock = [System.Windows.Forms.DockStyle]::Left
    $Label.Width = 60
    $Label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    $Label.Text = $LabelText

    $FieldSelector = New-Object System.Windows.Forms.ComboBox
    $FieldSelector.Dock = [System.Windows.Forms.DockStyle]::Left
    $FieldSelector.DataSource = $SettingsManager.Fields.ToArray()
    $FieldSelector.Width = 85

    $SortSelector = New-Object System.Windows.Forms.ComboBox
    $SortSelector.Dock = [System.Windows.Forms.DockStyle]::Left
    $SortSelector.Width = 80
    $SortSelector.DropDownStyle = [System.Windows.Forms.ComboBoxStyle]::DropDownList
    [void]$SortSelector.Items.Add("Ascending")
    [void]$SortSelector.Items.Add("Descending")

    switch ($SortDirection)
    {
        "Ascending" {
            $SortSelector.SelectedIndex = 0
        }
        "Descending" {
            $SortSelector.SelectedIndex = 1
        }
        default {
            $SortSelector.SelectedIndex = 0
        }
    }

    $SortSelector.Add_SelectedValueChanged({
        $this.Parent.Registration.SortDirection = $this.Items[$this.SelectedIndex]
    })

    # Color Picker
    $ColorPicker = New-Object System.Windows.Forms.Button
    $ColorPicker.Dock = [System.Windows.Forms.DockStyle]::Left
    $ColorPicker.Width = 21
    $ColorPicker.Height = 21
    $ColorPicker.Add_Click({
        $ColorDialog = New-Object System.Windows.Forms.ColorDialog
        $ColorDialog.AllowFullOpen = $true
        $ColorDialog.Color = $this.BackColor

        if ($ColorDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
        {
            $this.BackColor = $ColorDialog.Color
            $this.Parent.Registration.Color = $ColorDialog.Color.ToArgb()
        }
    })

    if ($Color -eq 0)
    {
        $ColorPicker.BackColor = $ColorPicker.ForeColor
    }
    else
    {
        $ColorPicker.BackColor = [System.Drawing.Color]::FromArgb($Color)
    }

    # The setting panel manages the state of this setting option.
    $Panel = New-Object System.Windows.Forms.Panel
    $Panel.Height = 22

    $settings = @{
        Name          = $InitialValue
        SortDirection = $SortSelector.Items[$SortSelector.SelectedIndex]
        Setting       = $Panel
    }

    # The GroupBy or SortBy customization.
    switch ($Type)
    {
        'Group' {
            $Panel.Width = $Remove.Width + $SortSelector.Width + $Label.Width + $FieldSelector.Width + $ColorPicker.Width
            Add-Member -InputObject $Panel -MemberType NoteProperty -Name SettingCollection -Value $SettingsManager.GroupBy

            $settings.Color = $ColorPicker.BackColor.ToArgb()
            [void]$Panel.Controls.Add($ColorPicker)
        }
        'Sort' {
            $Panel.Width = $Remove.Width + $SortSelector.Width + $Label.Width + $FieldSelector.Width
            Add-Member -InputObject $Panel -MemberType NoteProperty -Name SettingCollection -Value $SettingsManager.SortBy
        }
    }

    [void]$Panel.Controls.Add($SortSelector)
    [void]$Panel.Controls.Add($FieldSelector)
    [void]$Panel.Controls.Add($Label)
    [void]$Panel.Controls.Add($Remove)

    $registration = [PSCustomObject]$settings

    # Reference to the SettingsManager to give access to LeafLabel.
    Add-Member -InputObject $Panel -MemberType NoteProperty -Name SettingsManager -Value $SettingsManager

    # Reference object that is registered with the SettingsManager.
    Add-Member -InputObject $Panel -MemberType NoteProperty -Name Registration -Value $registration

    # String value specifying this as a GroupBy or SortBy setting.
    Add-Member -InputObject $Panel -MemberType NoteProperty -Name SettingType -Value $Type

    # Used to prevent event race conditions during control creation.
    Add-Member -InputObject $Panel -MemberType NoteProperty -Name Initialized -Value $false

    Add-Member -InputObject $Panel -MemberType ScriptMethod -Name Unregister -Value {
        [void]$this.Parent.Controls.Remove($this)
        $this.SettingCollection.Remove($this.Registration)
        Write-Debug ("Unregistered: {0}`t {1}" -f $this.Registration.Name, $this.GetHashCode())
    }

    # Set SelectedItem and the SelectedValueChanged last to prevent race conditions/issues with the
    # initialization of the controls and event handlers.
    [void]$Panel.SettingCollection.Add($registration)

    $FieldSelector.Add_SelectedValueChanged({
        $current = $this.Parent # Setting Panel

        if (!$current.Initialized) {
            $this.SelectedItem = $current.Registration.Name
            $current.Initialized = $true
            return
        }

        # GroupBy options may not use the same field as the leaf label.
        if ($current.SettingType -eq 'Group' -and $current.SettingsManager.LeafLabel -eq $this.SelectedValue)
        {
            $current.SettingsManager.LeafSelector.Unregister()
        }

        # Create a separate reference array since SettingCollection may be modified within the loop.
        $registered = $current.SettingCollection.ToArray()
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

function New-SettingMenus {
    [CmdletBinding()]
    Param (
        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $SettingsManager,

        [Parameter(Mandatory = $false)]
            [PSCustomObject]
            $DockParams
    )
    $MenuStrip = New-Object System.Windows.Forms.MenuStrip

    $menus = @{}

    $menus.Apply = New-Object System.Windows.Forms.ToolStripMenuItem("Apply", $null, {
        param ($sender, $e)
        $this.Settings.Apply()
    })

    Add-Member -InputObject $menus.Apply -MemberType NoteProperty -Name Settings -Value $SettingsManager

    [Void]$MenuStrip.Items.Add($menus.Apply)

    $menus.Settings = @{}

    $menus.Settings.Load = New-Object System.Windows.Forms.ToolStripMenuItem("Load", $null, {
            param ($sender, $e)

            # OpenFileBrowser to find the view settings file.
            $fdialog = New-Object System.Windows.Forms.OpenFileDialog
            $fdialog.ShowHelp = $false
            $fdialog.Multiselect = $false
            $fdialog.Filter = "View Settings|*.view"

            if ($fdialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
            {
                try
                {
                    $settings = ConvertFrom-Json (Get-Content $fdialog.FileName -Raw)
                }
                catch
                {
                    [System.Windows.Forms.MessageBox]::Show(
                        "$($_.Exception)",
                        "Load View Settings",
                        [System.Windows.Forms.MessageBoxButtons]::OK,
                        [System.Windows.Forms.MessageBoxIcon]::Exclamation
                    )
                    $settings = $null
                }
                finally {}
            }
            else
            {
                return
            }

            if ($settings -and !$this.SettingsManager.Load($settings))
            {
                [System.Windows.Forms.MessageBox]::Show(
                    "View settings are not valid for dataset!",
                    "Load View Settings",
                    [System.Windows.Forms.MessageBoxButtons]::OK,
                    [System.Windows.Forms.MessageBoxIcon]::Exclamation
                )
            }
        })
    Add-Member -InputObject $menus.Settings.Load -MemberType NoteProperty -Name SettingsManager -Value $SettingsManager

    $menus.Settings.Save = New-Object System.Windows.Forms.ToolStripMenuItem("Save", $null, {
            param ($sender, $e)

            # Convert View Settings into a json object and save to file path.
            $settings = @{
                Fields    = $this.SettingsManager.Fields
                LeafLabel = $this.SettingsManager.LeafLabel
                SortBy    = New-Object System.Collections.ArrayList
                GroupBy   = New-Object System.Collections.ArrayList
            }

            foreach ($registration in $this.SettingsManager.SortBy)
            {
                $setting = @{
                    Name          = $registration.Name
                    SortDirection = $registration.SortDirection
                }
                [void]$settings.SortBy.Add($setting)
            }

            foreach ($registration in $this.SettingsManager.GroupBy)
            {
                $setting = @{
                    Name          = $registration.Name
                    SortDirection = $registration.SortDirection
                    Color         = $registration.Color
                }
                [void]$settings.GroupBy.Add($setting)
            }

            # SaveFileBrowser to get the name to save the view settings as.
            $fdialog = New-Object System.Windows.Forms.SaveFileDialog
            $fdialog.ShowHelp = $false
            $fdialog.AddExtension = $true
            $fdialog.DefaultExt = 'view'
            $fdialog.Filter = "View Settings|*.view"
            $fdialog.Title = "Save View Settings"

            if ($fdialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK)
            {
                ConvertTo-Json $settings -Depth 3 > $fdialog.FileName
            }
        })
    Add-Member -InputObject $menus.Settings.Save -MemberType NoteProperty -Name SettingsManager -Value $SettingsManager

    $menus.Settings.Root = New-Object System.Windows.Forms.ToolStripMenuItem("Settings", $null, @($menus.Settings.Save, $menus.Settings.Load))
    [Void]$MenuStrip.Items.Add($menus.Settings.Root)

    if ($DockParams)
    {
        $menus.Undock = New-Object System.Windows.Forms.ToolStripMenuItem("Undock", $null, {
            param ($sender, $e)
            $this.Undock()
        })

        Add-Member -InputObject $menus.Undock -MemberType NoteProperty -Name Window -Value $Window

        Add-Member -InputObject $menus.Undock -MemberType NoteProperty -Name DockPackage -Value $Component

        Add-Member -InputObject $menus.Undock -MemberType NoteProperty -Name DockTarget -Value $Target

        Add-Member -InputObject $menus.Undock -MemberType ScriptMethod -Name Undock -Value {
            $form = New-Object System.Windows.Forms.Form
            #$form.Text          = ""
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

        [Void]$MenuStrip.Items.Add($menus.Undock)
    }

    return $MenuStrip
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

        # User view settings interface static flow layout panels.
        SortLayout      = $null
        GroupLayout     = $null

        # Leaf TreeNode label source field
        LeafSelector    = $null
        LeafLabel       = [String]::Empty

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

        function Add-Fields ($LeafSelector, $Fields)
        {
            [void]$LeafSelector.Items.Add([String]::Empty)
            foreach ($field in $fields)
            {
                [void]$LeafSelector.Items.Add($field)
            }
        }

        if ($this.Fields.Count -gt 0) {
            $this.Fields.Clear()
        }
        $this.Fields.AddRange($fields)

        # Prompt Flag if the View Settings needs to be updated by the user
        $RequireUpdate = $false

        # Verify DataSource is set for the DataLabel Selector
        if ($this.LeafSelector -and $this.LeafSelector.Items.Count -eq 0) {
            Add-Fields $this.LeafSelector $fields
            $RequireUpdate = $true
        }
        # Verify DataSource contains the new field names.
        elseif ($this.LeafSelector)
        {
            foreach ($field in $this.LeafSelector.Items)
            {
                if (!([String]::IsNullOrEmpty($field)) -and $fields -notcontains $field)
                {
                    $this.LeafSelector.Items.Clear()
                    Add-Fields $this.LeafSelector $fields
                    $RequireUpdate = $true
                    break
                }

            }
        }
        # Validate grouped fields exist on data objects
        foreach ($registration in $this.GroupBy) {
            if ($fields -notcontains $registration.Name) {
                $registration.Setting.Unregister()
                $RequireUpdate = $true
            }
        }

        if ($RequireUpdate) {
            $this.Valid = $false
        }
    }

    Add-Member -InputObject $SettingsManager -MemberType ScriptMethod -Name Apply -Value {
        Write-Debug "Applying View Settings..."

        if ([String]::IsNullOrEmpty($this.LeafLabel)) {
            [System.Windows.Forms.MessageBox]::Show(
                "You must select a [Data Node Label] field!",
                "Compliance View Settings",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Exclamation
            )
            return
        }

        # The settings are valid for the provided data.
        $this.Valid = $true
        $this.GroupBy.TrimToSize()

        Write-Debug "Building Group Buckets: $($this.GroupBy)"

        # Quick Access ArrayList for all of the data nodes
        $DataNodes = New-Object System.Collections.ArrayList

        $constructor = & $this.TreeView.Static.NewConstructor $this.LeafLabel $this.GroupBy $this.SortBy $DataNodes $this.GroupDefinition $this.NodeDefinition
        $constructor.AddRange($this.TreeView.Source)

        $this.TreeView.SuspendLayout()
        $this.TreeView.Nodes.Clear()
        $this.TreeView.Nodes.AddRange( $constructor.Build() )
        $this.TreeView.ResumeLayout()

        # Append DataNodes array that allows processing of the leaf nodes without using recursive function calls.
        $this.TreeView.DataNodes = $DataNodes

        # Reset the active tab of the parent TabLayout container to display the TreeView.
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

    Add-Member -InputObject $SettingsManager -MemberType ScriptMethod -Name Load -Value {
        param (
            [Parameter(Mandatory = $true)]
                [Object]
                $Settings,

            [Parameter(Mandatory = $false)]
                [Bool]
                $NoSettingsTab
        )
        # Sanity check the view fields to ensure they match currently loaded data.
        if ($this.Fields.Count -gt 0)
        {
            foreach ($field in $Settings.Fields)
            {
                if ($this.Fields -notcontains $field)
                {
                    return $false
                }
            }
        }
        else
        {
            $this.RegisterFields($Settings.Fields)
        }

        $this.LeafSelector.SelectedIndex = $this.LeafSelector.Items.IndexOf($Settings.LeafLabel)

        # No SettingsTab UI updates.
        if ($NoSettingsTab)
        {
            $this.GroupBy.Clear()
            $this.SortBy.Clear()
            [void]$this.GroupBy.AddRange($Settings.GroupBy)
            [void]$this.SortBy.AddRange($Settings.SortBy)
            return $true
        }

        # Unregister any current settings. Use a temporary array due to collection modification.
        $registrations = $this.GroupBy.ToArray()
        foreach ($registration in $registrations)
        {
            $registration.Setting.Unregister()
        }
        # Unregister any current settings. Use a temporary array due to collection modification.
        $registrations = $this.SortBy.ToArray()
        foreach ($registration in $registrations)
        {
            $registration.Setting.Unregister()
        }

        # Create setting panels.
        foreach ($field in $Settings.SortBy)
        {
            $SettingParams = @{
                LabelText       = 'Sort by:'
                Type            = 'Sort'
                InitialValue    = $field.Name
                SettingsManager = $this
            }
            $panel = New-SettingPanel @SettingParams
            [void]$this.SortLayout.Controls.Add($panel)
        }
        foreach ($field in $Settings.GroupBy)
        {
            $SettingParams = @{
                LabelText       = 'Group by:'
                Type            = 'Group'
                InitialValue    = $field.Name
                SettingsManager = $this
                Color           = $field.Color
            }
            $panel = New-SettingPanel @SettingParams
            [void]$this.GroupLayout.Controls.Add($panel)
        }

        $this.Valid = $true
        return $true
    }

    return $SettingsManager
}
