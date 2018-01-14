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

    $Control = New-SortedTreeView $Window $Parent $Source $ImageList $TreeDefinition $GroupDefinition $NodeDefinition
    Add-Member -InputObject $Control -MemberType NoteProperty -Name Static -Value $Static

    # Register Control With Parent
    [void]$Parent.Controls.Add($Control)

    return $Control
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
# of objects as components of those objects.
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
$Static.NewDataBucket = {
    param($Field, [System.Collections.ArrayList]$Buffer, [Object]$Definition)

    Write-Debug "Creating new data bucket"

    $bucket = [PSCustomObject]@{
        Field      = $Field
        Content    = New-Object System.Collections.ArrayList
        Buffer     = $Buffer
        Definition = $Definition
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Add -Value {
        param($Record)
        [void] $this.Content.Add($Record)
    }

    Add-Member -InputObject $bucket -MemberType ScriptMethod -Name Build -Value {
        # Process Node Definition for Each Data Record
        ForEach ($record in $this.Content) {
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
    param($DataLabel, [System.Collections.ArrayList]$Buffer, [Object]$Definition)

    Write-Debug "Creating a new data bucket factory"

    $factory = [PSCustomObject]@{
        DataLabel  = $DataLabel
        Buffer     = $Buffer
        Definition = $Definition
    }

    Add-Member -InputObject $factory -MemberType ScriptMethod -Name New -Value {
        Write-Debug "Calling New Data Bucket"
        return & $Static.NewDataBucket $this.DataLabel $this.Buffer $this.Definition
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
$Static.NewGroupConstructor = {
    param($GroupBy, $DataLabel, [System.Collections.ArrayList]$Buffer, [Object]$GroupDefinition, [Object]$NodeDefinition)

    Write-Debug ("Creating new TreeView Group Constructor {0}" -f ($GroupBy | Select-Object -Property Name | Out-String))
    Write-Debug "Data Labels Using field [$DataLabel]"

    $factories = New-Object System.Collections.ArrayList

    # Build Initial Grouping Level Buckets
    if ($GroupBy.Count -gt 0) {
        $max = $GroupBy.Count - 1

        for ($i = 0; $i -le $max; $i++) {
                
            # MUST ONLY BE ONE TOP BUCKET /ROOT/
            if ($i -eq 0) {
                $root = & $Static.NewGroupBucket $GroupBy[$i] $null $GroupDefinition
            }
            else {
                [void] $factories.Add( (& $Static.NewGroupFactory $GroupBy[$i] $null $GroupDefinition) )
            }
        }

        # Factory Linking - Back Reference Factories
        $max = $factories.Count - 1
        for ($i = 1; $i -le $max; $i++) {
            $factories[$i - 1].Next = $factories[$i]
        }
    }

    # Handle View Settings with no Grouping Levels Defined
    else {
        Write-Debug "No Grouping Defined, Top Bucket is the Data Bucket"
        $root = & $Static.NewDataBucket $DataLabel $Buffer $NodeDefinition
    }
            
    # Handle Back References for Multiple Grouping Level Factories
    if ($GroupBy.Count -gt 1) {
        Write-Debug ("Data Bucket Factory Assigned to [{0}] Factory" -f $factories[$max].Rule.Name)
        $factories[$max].Next = & $Static.NewDataBucketFactory $DataLabel $Buffer $NodeDefinition

        # Top Bucket gets the next level bucket factory
        $root.Factory = $factories[0]
    }

    # Handle Single Grouping Level
    elseif ($GroupBy.Count -eq 1) {
        # If there is only one grouping level then root gets data buckets
        $root.Factory = & $Static.NewDataBucketFactory $DataLabel $Buffer $NodeDefinition
    }

    # Build the Constructor Object
    $constructor = [PSCustomObject]@{
        FactoryList = $factories
        Tree        = $root
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

function New-SortedTreeView {
    param (
        # Window reference for docking support (undock window parent).
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Form]
            $Window,

        # Parent layout control that hosts this SortedTreeView for docking support (dock target).
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.Control]
            $Parent,

        # TreeView data source used to create the TreeNodes.
        [Parameter(Mandatory = $true)]
            [AllowEmptyCollection()]
            [System.Collections.ArrayList]
            $Source,
        
        # Collection of images used by TreeNodes.
        [Parameter(Mandatory = $true)]
            [System.Windows.Forms.ImageList]
            $ImageList,

        # Object containing the property overrides, event handlers, and custom properties/methods for the TreeView layout container.
        [Parameter(Mandatory = $false)]
            [PSCustomObject]
            $TreeDefinition,

        # Object containing the property overrides, event handlers, and custom properties/methods for TreeNodes used for data grouping (branches).
        [Parameter(Mandatory = $false)]
            [PSCustomObject]
            $GroupDefinition,
        
        # Object containing the property overrides, event handlers, and custom properties/methods for TreeNodes used for data representation (leaves)
        [Parameter(Mandatory = $false)]
            [PSCustomObject]
            $NodeDefinition
    )

    # Top Level Container
    $BaseContainer = New-Object System.Windows.Forms.TabControl
        $BaseContainer.Dock = [System.Windows.Forms.DockStyle]::Fill
        
        # Attached to Parent Control by Module Component Registration Function

    $TreeViewTab = New-Object System.Windows.Forms.TabPage
        $TreeViewTab.Dock = [System.Windows.Forms.DockStyle]::Fill
        $TreeViewTab.Text = "Explorer"

        [void]$BaseContainer.TabPages.Add( $TreeViewTab )

    # TreeView Component
    #region
    $TreeViewControl = New-Object System.Windows.Forms.TreeView
    &{
        $TreeViewControl.Dock       = [System.Windows.Forms.DockStyle]::Fill
        $TreeViewControl.CheckBoxes = $true
        $TreeViewControl.ImageList  = $ImageList

        ### BUILT-IN PROPERTIES -----------------------------------------------
        # Late binding (dynamic)
        foreach ($property in $TreeDefinition.Properties.GetEnumerator()) {
            $TreeViewControl.($property.Key) = $property.Value
        }

        ### EVENT HANDLERS ----------------------------------------------------
        # Defaults
        if (!$TreeDefinition.Handlers.ContainsKey('AfterCheck')) {
            [void]$TreeViewControl.Add_AfterCheck($Default.AfterCheck)
        }
        if (!$TreeDefinition.Handlers.ContainsKey('Click')) {
            [void]$TreeViewControl.Add_Click($Default.Click)
        }

        # Late binding (dynamic) - can override defaults
        foreach ($handler in $TreeDefinition.Handlers.GetEnumerator()) {
            $TreeViewControl."Add_$($handler.Key)"($handler.Value)
        }

        Add-Member -InputObject $TreeViewControl -MemberType NoteProperty -Name Static -Value $Static

        Add-Member -InputObject $TreeViewControl -MemberType NoteProperty -Name Source -Value $Source

        Add-Member -InputObject $TreeViewControl -MemberType NoteProperty -Name DataNodes -Value $null

        Add-Member -InputObject $TreeViewControl -MemberType ScriptMethod -Name FindNode -Value {
            param([String]$NodeName, [System.Windows.Forms.TreeNode]$StartNode)

            # Top Level search using the TreeView as root
            if (!$StartNode) {
                foreach ($node in $this.Nodes) {
                    $seek = $this.FindNode($NodeName, $node)
                    if ($seek) {
                        return $seek
                    }
                }
            }

            # Recursive search start node
            foreach ($node in $StartNode.Nodes) {
                if ($node.Name -eq $NodeName) {
                    return $node
                }
                $seek = $this.FindNode($NodeName, $node)
                if ($seek) {
                    return $seek
                }
            }

            # Default output
            return $null
        }

        foreach ($method in $TreeDefinition.Methods.GetEnumerator()) {
            Add-Member -InputObject $TreeViewcontrol -MemberType ScriptMethod -Name $method.Key -Value $method.Value
        }

        [void]$TreeViewTab.Controls.Add( $TreeViewControl )
    }

    $SettingsTab = New-Object System.Windows.Forms.TabPage
    &{
        $SettingsTab.Dock = [System.Windows.Forms.DockStyle]::Fill
        $SettingsTab.Text = "View Settings"

        Add-Member -InputObject $SettingsTab -MemberType NoteProperty -Name Fields -Value $null

        Add-Member -InputObject $SettingsTab -MemberType NoteProperty -Name SortFields -Value (New-Object System.Collections.ArrayList)

        Add-Member -InputObject $SettingsTab -MemberType NoteProperty -Name GroupFields -Value (New-Object System.Collections.ArrayList)

        Add-Member -InputObject $SettingsTab -MemberType ScriptMethod -Name PromptUser -Value {
            [System.Windows.Forms.MessageBox]::Show(
                "Update View Settings",
                "Data fields or format changed.`r`nUpdate View Settings.",
                [System.Windows.Forms.MessageBoxButtons]::OK,
                [System.Windows.Forms.MessageBoxIcon]::Exclamation
            )

            $this.Parent.SelectedIndex = 1
        }

        Add-Member -InputObject $SettingsTab -MemberType ScriptMethod -Name RegisterFields -Value {
            param($fields)
            $this.Fields = $fields

            # Prompt Flag if the View Settings needs to be updated by the user
            $RequireUpdate = $false

            # Verify DataSource is set for the DataLabel Selector
            if (!$this.DataLabel.DataSource) {
                $this.DataLabel.DataSource = @([String]::Empty) + @($fields)
                $RequireUpdate = $true
            }

            # Validate grouped fields exist on data objects
            foreach ($field in $this.GroupFields) {
                if ($fields -notcontains $field.Name) {
                    $field.Setting.Unregister()
                    $this.DataLabel.DataSource = @([String]::Empty) + @($fields)
                    $RequireUpdate = $true
                }
            }

            if ($RequireUpdate) {
                $this.Handler.Valid = $false
            }
        }

        [void]$BaseContainer.TabPages.Add( $SettingsTab )
    }

    # View Settings Flow Panel
    $SettingsContainer = New-Object System.Windows.Forms.FlowLayoutPanel
    &{
        $SettingsContainer.Dock          = [System.Windows.Forms.DockStyle]::Fill
        $SettingsContainer.BackColor     = [System.Drawing.Color]::White
        $SettingsContainer.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
        $SettingsContainer.WrapContents  = $false
        $SettingsContainer.AutoScroll    = $true

        # Data Node Configuration (Apply and Undock Buttons)
        $DataNodePanel = New-Object System.Windows.Forms.Panel
        &{
            $DataNodePanel.BackColor = [System.Drawing.Color]::White

            $registration = [PSCustomObject]@{
                Name = [String]::Empty
                Setting = $DataNodePanel
            }

            # Static property for the sort level settings to check when removing registrations
            Add-Member -InputObject $DataNodePanel -MemberType NoteProperty -Name SettingType -Value 'DataNode'

            Add-Member -InputObject $DataNodePanel -MemberType NoteProperty -Name SettingsTab -Value $SettingsTab

            Add-Member -InputObject $DataNodePanel -MemberType NoteProperty -Name Registered -Value $false

            Add-Member -InputObject $DataNodePanel -MemberType ScriptMethod -Name Unregister -Value {
                if(!$this.Registered) {
                    return
                }
                $this.Registered = $false
                Write-Debug ("Unregistered: {0}`t {1}" -f $this.Registration.Name, $this.GetHashCode())
                [void]$this.SettingsTab.GroupFields.Remove($this.Registration)
                $this.Controls['DisplayFieldSelectionBox'].SelectedIndex = 0
            }

            Add-Member -InputObject $DataNodePanel -MemberType NoteProperty -Name Registration -Value $registration

            # Undock Navigation TreeView Button
            [void]$DataNodePanel.Controls.Add((&{
                $button = New-Object System.Windows.Forms.Button
                $button.Dock = [System.Windows.Forms.DockStyle]::Left
                $button.Text = "Undock"
                $button.Height = 21
                $button.Add_Click({
                    $this.Undock()
                })

                Add-Member -InputObject $button -MemberType NoteProperty -Name Window -Value $Window

                Add-Member -InputObject $button -MemberType NoteProperty -Name DockPackage -Value $BaseContainer

                Add-Member -InputObject $button -MemberType NoteProperty -Name DockTarget -Value $Parent

                Add-Member -InputObject $button -MemberType ScriptMethod -Name Undock -Value {
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

                # Add Button to Parent Control
                return $button
            }))

            # Apply Settings Button
            [void]$DataNodePanel.Controls.Add( 
            ( &{
                $button = New-Object System.Windows.Forms.Button

                $handler = {
                    Write-Debug "Applying View Settings..."

                    # Data Node Label Field
                    $dataLabel = $this.Parent.Controls['DisplayFieldSelectionBox'].SelectedValue

                    if ([String]::IsNullOrEmpty($dataLabel)) {
                        [System.Windows.Forms.MessageBox]::Show(
                            "You must select a [Data Node Label] field!",
                            "Compliance View Settings",
                            [System.Windows.Forms.MessageBoxButtons]::OK,
                            [System.Windows.Forms.MessageBoxIcon]::Exclamation
                        )
                        return
                    }

                    $this.Valid = $true

                    # Gather Sorting Data
                    #$SortBy = New-Object System.Collections.ArrayList
                    #$SortSettings = $this.SettingsContainer.Controls['SortByOptions']
                    #for ($i = 1; $i -lt $SortSettings.Controls.Count; $i++) {
                    #    [void]$SortBy.Add($SortSettings.Controls[$i].Registration.Name)
                    #}
                    #$SortBy.TrimToSize()
                    #
                    #Write-Debug "Building Sort Buckets: $SortBy"

                    # Gather Grouping Data
                    $groupBy = New-Object System.Collections.ArrayList
                    $groupSettings = $this.SettingsContainer.Controls['GroupByOptions']

                    for ($i = 1; $i -lt $groupSettings.Controls.Count; $i++) {
                        [void]$groupBy.Add($groupSettings.Controls[$i].Registration)
                    }

                    $groupBy.TrimToSize()

                    Write-Debug "Building Group Buckets: $groupBy"

                    # Quick Access ArrayList for all of the data nodes
                    $dataNodes = New-Object System.Collections.ArrayList

                    $constructor = & $this.Tree.Static.NewGroupConstructor $groupBy $dataLabel $dataNodes $this.GroupDefinition $this.NodeDefinition
                    $constructor.AddRange($this.Tree.Source)

                    $this.Tree.SuspendLayout()
                    $this.Tree.Nodes.Clear()
                    $this.Tree.Nodes.AddRange( $constructor.Build() )
                    $this.Tree.ResumeLayout()

                    # Append Quick Access Data Node List
                    $this.Tree.DataNodes = $dataNodes

                    $this.Component.SelectedIndex = 0
                }

                ### TREEVIEW SETTINGS -----------------------------------------
                Add-Member -InputObject $button -MemberType NoteProperty -Name SettingsContainer -Value $SettingsContainer

                ### PARENT AND DATA SOURCE CONTAINERS/OBJECTS -----------------
                Add-Member -InputObject $button -MemberType NoteProperty -Name Tree -Value $TreeViewControl
                Add-Member -InputObject $button -MemberType NoteProperty -Name Component -Value $BaseContainer

                ### TREEVIEW NODE CUSTOMIZATION DEFINITIONS -------------------
                Add-Member -InputObject $button -MemberType NoteProperty -Name GroupDefinition -Value $GroupDefinition
                Add-Member -InputObject $button -MemberType NoteProperty -Name NodeDefinition -Value $NodeDefinition

                ### REMOTE CALL HANDLE ----------------------------------------
                Add-Member -InputObject $button -MemberType ScriptMethod -Name Apply -Value $handler

                ### STATUS FLAGS ----------------------------------------------
                # Flag for remote callers set by Apply.Handler and SettingsTab.RegisterFields
                Add-Member -InputObject $button -MemberType NoteProperty -Name Valid -Value $false
                Add-Member -InputObject $SettingsTab -MemberType NoteProperty -Name Handler -Value $button

                $button.Dock   = [System.Windows.Forms.DockStyle]::Left
                $button.Height = 21
                $button.Width  = 85
                $button.Text   = "Apply Settings"
                $button.Add_Click($handler)

                return $button
        
                })
            )

            # Select Data Label Combo Box
            [void]$DataNodePanel.Controls.Add(
            (&{
                $dropdown = New-Object System.Windows.Forms.ComboBox
                $dropdown.Name = "DisplayFieldSelectionBox"
                $dropdown.Dock = [System.Windows.Forms.DockStyle]::Left
                $dropdown.Width = 85
                $dropdown.Add_SelectedValueChanged({
                    $current = $this.Parent # Settings Panel

                    if ($this.SelectedValue -eq [String]::Empty) {
                        $current.Unregister()
                        return
                    }

                    $registered = $this.SettingsTab.GroupFields.ToArray()
                    foreach ($field in $registered) {
                        if (!$field.Setting.Equals($current) -and $field.Name -eq $this.SelectedValue) {
                            if ($field.Setting.SettingType -eq 'Group') {
                                $field.Setting.Unregister()
                            }
                        }
                    }
        
                    Write-Debug ("Field Registered: {0}`t{1}" -f $current.Registration.Name, $current.GetHashCode())
                    $current.Registration.Name = $this.SelectedValue

                    if (!$current.Registered) {
                        [void]$this.SettingsTab.GroupFields.Add($current.Registration)
                        $current.Registered = $true
                    }
                })

                Add-Member -InputObject $SettingsTab -MemberType NoteProperty -Name DataLabel -Value $dropdown

                Add-Member -InputObject $dropdown -MemberType NoteProperty -Name SettingsTab -Value $SettingsTab

                return $dropdown
            }) )

            # Panel Setting Label
            [void]$DataNodePanel.Controls.Add(
            (&{
                $label= New-Object System.Windows.Forms.Label
                $label.Dock = [System.Windows.Forms.DockStyle]::Left
                $label.Text = "Data Node Label:"
                $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

                return $label
            }) )

            $width = 0
            foreach ($ctrl in $DataNodePanel.Controls) {
                $width += $ctrl.width
            }
            $DataNodePanel.Width = $width + 10
            $DataNodePanel.Height = 22

            [void]$SettingsContainer.Controls.Add( $DataNodePanel )
        }

        # Sort By Options Flow Panel
        #region
    #    $OptionsFlowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
    #    $OptionsFlowPanel.Name = 'SortByOptions'
    #    $OptionsFlowPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
    #    $OptionsFlowPanel.WrapContents = $false
    #    $OptionsFlowPanel.BackColor = [System.Drawing.Color]::White
    #    $OptionsFlowPanel.AutoSize = $true
    #    $OptionsFlowPanel.AutoSizeMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
    #
    #    $SettingsContainer.Controls.Add( $OptionsFlowPanel )
    #
    #    # Add Sort Level Static Panel
    #    #region
    #    $OptionsFlowPanel.Controls.Add( (New-Object System.Windows.Forms.Panel) )
    #    $OptionsFlowPanel.Controls[0].Height = 22
    #
    #    $OptionsFlowPanel.Controls[0].Controls.Add( (New-Object System.Windows.Forms.Label) )
    #    $OptionsFlowPanel.Controls[0].Controls[0].Dock = [System.Windows.Forms.DockStyle]::Left
    #    $OptionsFlowPanel.Controls[0].Controls[0].Text = "Sort Level"
    #    $OptionsFlowPanel.Controls[0].Controls[0].TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    #
    #    $OptionsFlowPanel.Controls[0].Controls.Add( (New-Object System.Windows.Forms.Button) )
    #    $OptionsFlowPanel.Controls[0].Controls[1].Text = "Add"
    #    $OptionsFlowPanel.Controls[0].Controls[1].Dock = [System.Windows.Forms.DockStyle]::Left
    #    $OptionsFlowPanel.Controls[0].Controls[1].Height = 21
    #    $OptionsFlowPanel.Controls[0].Controls[1].Width  = 50
    #    $OptionsFlowPanel.Controls[0].Controls[1].Add_Click({
    #        if ($SettingsTab.GroupFields.Count -eq $SettingsTab.Fields.Count -1) {
    #            [System.Windows.Forms.MessageBox]::Show(
    #                "Maximum number of group/sort levels reached!",
    #                "View Settings",
    #                [System.Windows.Forms.MessageBoxButtons]::OK,
    #                [System.Windows.Forms.MessageBoxIcon]::Exclamation
    #            )
    #            return
    #        }
    #
    #        Write-Debug ("Registered Fields:`r`n{0}" -f ($SettingsTab.GroupFields | Format-Table | Out-String))
    #        
    #        # Find first unregistered field name
    #        $filtered = New-Object System.Collections.ArrayList
    #        [void]$filtered.AddRange($SettingsTab.Fields)
    #        foreach ($registration in $SettingsTab.GroupFields) {
    #            [void]$filtered.Remove($registration.Name)
    #        }
    #        $available = $filtered[0]
    #        
    #        Write-Debug ("Available Field:`r`n{0}" -f $available)
    #
    #        $RemoveButton = New-Object System.Windows.Forms.Button
    #        $RemoveButton.Dock = [System.Windows.Forms.DockStyle]::Left
    #        $RemoveButton.Text = "Remove"
    #        $RemoveButton.Height = 21
    #        $RemoveButton.Width = 75
    #        [void]$RemoveButton.Add_Click({
    #            $this.Parent.Unregister()
    #        })
    #
    #        $SettingLabel = New-Object System.Windows.Forms.Label
    #        $SettingLabel.Dock = [System.Windows.Forms.DockStyle]::Left
    #        $SettingLabel.Width = 60
    #        $SettingLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
    #        $SettingLabel.Text = "Sort by:"
    #
    #        $FieldSelectBox = New-Object System.Windows.Forms.ComboBox
    #        $FieldSelectBox.Dock = [System.Windows.Forms.DockStyle]::Left
    #        $FieldSelectBox.DataSource = @($SettingsTab.Fields)
    #        $FieldSelectBox.Width = 85
    #        
    #
    #        $SortDirection = New-Object System.Windows.Forms.ComboBox
    #        $SortDirection.Dock = [System.Windows.Forms.DockStyle]::Left
    #        $SortDirection.DataSource = @("Ascending", "Descending")
    #        $SortDirection.Width = 80
    #        $SortDirection.Add_SelectedValueChanged({
    #            $this.Parent.Registration.SortDirection = $this.SelectedValue
    #        })
    #
    #        $SettingPanel = New-Object System.Windows.Forms.Panel
    #        $SettingPanel.Height = 22
    #        $SettingPanel.Width = $RemoveButton.Width + $SortDirection.Width + $SettingLabel.Width + $FieldSelectBox.Width
    #
    #        [void]$SettingPanel.Controls.Add($SortDirection)
    #        [void]$SettingPanel.Controls.Add($FieldSelectBox)
    #        [void]$SettingPanel.Controls.Add($SettingLabel)
    #        [void]$SettingPanel.Controls.Add($RemoveButton)
    #
    #        $registration = [PSCustomObject]@{
    #            Name = $available
    #            SortDirection = 'Ascending'
    #            Setting = $SettingPanel
    #        }
    #
    #        Add-Member -InputObject $SettingPanel -MemberType NoteProperty -Name Registration -Value $registration
    #
    #        Add-Member -InputObject $SettingPanel -MemberType NoteProperty -Name SettingType -Value "Sort"
    #
    #        Add-Member -InputObject $SettingPanel -MemberType ScriptMethod -Name Unregister -Value {
    #            [void]$this.Parent.Controls.Remove($this)
    #            $SettingsTab.GroupFields.Remove($this.Registration)
    #            Write-Debug ("Unregistered: {0}`t {1}" -f $this.Registration.Name, $this.GetHashCode())
    #        }
    #
    #        [void]$SettingsTab.GroupFields.Add($registration)
    #
    #        Write-Debug ("Field Registered: {0}`t{1}" -f $registration.Name, $registration.Setting.GetHashCode())
    #
    #        $GroupSortPanel = $this.Parent.Parent
    #        [void]$GroupSortPanel.Controls.Add($SettingPanel)
    #        
    #        # After registering the field set the combo box selected value
    #        $FieldSelectBox.SelectedItem = $available
    #
    #        # Adding the event handler last to prevent issues with the initial loading of the setting panel
    #        $FieldSelectBox.Add_SelectedValueChanged({
    #            $Current = $this.Parent
    #
    #            $registered = $SettingsTab.GroupFields.ToArray()
    #            foreach ($field in $registered) {
    #                if (!$field.Setting.Equals($Current) -and $field.Name -eq $this.SelectedValue) {
    #
    #                    # Sorting Levels do not unregister the data node display field
    #                    if ($field.Setting.SettingType -eq 'DataNode') {
    #                        continue
    #                    }
    #                    $field.Setting.Unregister()
    #                }
    #            }
    #
    #            $Current.Registration.Name = $this.SelectedValue
    #            Write-Debug ("Field Registered: {0}`t{1}" -f $Current.Registration.Name, $Current.GetHashCode())
    #        })
    #    })
    #    #endregion
        #endregion

        # Group By Options Flow Panel
        $OptionsFlowPanel = New-Object System.Windows.Forms.FlowLayoutPanel
        &{
            $OptionsFlowPanel.Name          = 'GroupByOptions'
            $OptionsFlowPanel.FlowDirection = [System.Windows.Forms.FlowDirection]::TopDown
            $OptionsFlowPanel.WrapContents  = $false
            $OptionsFlowPanel.BackColor     = [System.Drawing.Color]::White
            $OptionsFlowPanel.AutoSize      = $true
            $OptionsFlowPanel.AutoSizeMode  = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

            [void]$SettingsContainer.Controls.Add( $OptionsFlowPanel )
        }

        # Add Group Level Static Panel
        &{
            $GroupStaticPanel = New-Object System.Windows.Forms.Panel
            $GroupStaticPanel.Height = 22
                
                [void]$OptionsFlowPanel.Controls.Add( $GroupStaticPanel )

            $label = New-Object System.Windows.Forms.Label
                $label.Dock = [System.Windows.Forms.DockStyle]::Left
                $label.Text = "Group Level"
                $label.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft

                [void]$GroupStaticPanel.Controls.Add( $label )
            
            $groupButton = New-Object System.Windows.Forms.Button
                $groupButton.Text = "Add"
                $groupButton.Dock = [System.Windows.Forms.DockStyle]::Left
                $groupButton.Height = 21
                $groupButton.Width  = 50
                
                [void]$GroupStaticPanel.Controls.Add( $groupButton )

                Add-Member -InputObject $groupButton -MemberType NoteProperty -Name SettingsTab -Value $SettingsTab

                Add-Member -InputObject $groupButton -MemberType NoteProperty -Name OptionsPanel -Value $OptionsFlowPanel

                [void]$groupButton.Add_Click({
                    if ($this.SettingsTab.GroupFields.Count -eq $this.SettingsTab.Fields.Count -1) {
                        [System.Windows.Forms.MessageBox]::Show(
                            "Maximum number of group/sort levels reached!",
                            "View Settings",
                            [System.Windows.Forms.MessageBoxButtons]::OK,
                            [System.Windows.Forms.MessageBoxIcon]::Exclamation
                        )
                        return
                    }

                    Write-Debug ("Registered Fields:`r`n{0}" -f ($this.SettingsTab.GroupFields | Format-Table | Out-String))
        
                    # Find first unregistered field name
                    $filtered = New-Object System.Collections.ArrayList
                    [void]$filtered.AddRange($this.SettingsTab.Fields)
                    foreach ($registration in $this.SettingsTab.GroupFields) {
                        [void]$filtered.Remove($registration.Name)
                    }
                    $available = $filtered[0]
        
                    Write-Debug ("Avaliable Field:`r`n{0}" -f $available)

                    $removeButton = New-Object System.Windows.Forms.Button
                    $removeButton.Dock = [System.Windows.Forms.DockStyle]::Left
                    $removeButton.Text = "Remove"
                    $removeButton.Height = 21
                    $removeButton.Width = 75
                    [void]$removeButton.Add_Click({
                        $this.Parent.Unregister()
                    })

                    $settingLabel = New-Object System.Windows.Forms.Label
                    $settingLabel.Dock = [System.Windows.Forms.DockStyle]::Left
                    $settingLabel.Width = 60
                    $settingLabel.TextAlign = [System.Drawing.ContentAlignment]::MiddleLeft
                    $settingLabel.Text = "Group by:"

                    $fieldSelection = New-Object System.Windows.Forms.ComboBox
                    $fieldSelection.Dock = [System.Windows.Forms.DockStyle]::Left
                    $fieldSelection.DataSource = @($this.SettingsTab.Fields)
                    $fieldSelection.Width = 85

                    Add-Member -InputObject $fieldSelection -MemberType NoteProperty -Name SettingsTab -Value $this.SettingsTab

                    $sortDirection = New-Object System.Windows.Forms.ComboBox
                    $sortDirection.Dock = [System.Windows.Forms.DockStyle]::Left
                    $sortDirection.DataSource = @("Ascending", "Descending")
                    $sortDirection.Width = 80
                    $sortDirection.Add_SelectedValueChanged({
                        $this.Parent.Registration.SortDirection = $this.SelectedValue
                    })

                    $settingPanel = New-Object System.Windows.Forms.Panel
                    $settingPanel.Height = 22
                    $settingPanel.Width = $removeButton.Width + $sortDirection.Width + $settingLabel.Width + $fieldSelection.Width

                    [void]$settingPanel.Controls.Add($sortDirection)
                    [void]$settingPanel.Controls.Add($fieldSelection)
                    [void]$settingPanel.Controls.Add($settingLabel)
                    [void]$settingPanel.Controls.Add($removeButton)

                    $registration = [PSCustomObject]@{
                        Name = $available
                        SortDirection = "Ascending"
                        Setting = $settingPanel
                    }

                    Add-Member -InputObject $settingPanel -MemberType NoteProperty -Name SettingsTab -Value $this.SettingsTab

                    Add-Member -InputObject $settingPanel -MemberType NoteProperty -Name Registration -Value $registration

                    Add-Member -InputObject $settingPanel -MemberType NoteProperty -Name SettingType -Value "Group"

                    Add-Member -InputObject $settingPanel -MemberType ScriptMethod -Name Unregister -Value {
                        [void]$this.Parent.Controls.Remove($this)
                        $this.SettingsTab.GroupFields.Remove($this.Registration)
                        Write-Debug ("Unregistered: {0}`t {1}" -f $this.Registration.Name, $this.GetHashCode())
                    }

                    # Register the setting
                    [void]$this.SettingsTab.GroupFields.Add($registration)

                    Write-Debug ("Field Registered: {0}`t{1}" -f $registration.Name, $registration.Setting.GetHashCode())

                    [void]$this.OptionsPanel.Controls.Add($settingPanel)
        
                    # After registering the field set the combo box selected value
                    $fieldSelection.SelectedItem = $available

                    # Adding the event handler last to prevent issues with the initial loading of the setting panel
                    $fieldSelection.Add_SelectedValueChanged({
                        $current = $this.Parent # Setting Panel

                        $registered = $this.SettingsTab.GroupFields.ToArray()
                        foreach ($field in $registered) {
                            if (!$field.Setting.Equals($current) -and $field.Name -eq $this.SelectedValue) {
                                $field.Setting.Unregister()
                            }
                        }

                        $current.Registration.Name = $this.SelectedValue
                        Write-Debug ("Field Registered: {0}`t{1}" -f $current.Registration.Name, $current.GetHashCode())
                    })
                }) # End Button.Add_Click
        }

        # Add the TreeView Settings Panel
        [void]$SettingsTab.Controls.Add( $SettingsContainer )
    }

    Add-Member -InputObject $BaseContainer -MemberType NoteProperty -Name SettingsTab -Value $SettingsTab

    Add-Member -InputObject $BaseContainer -MemberType NoteProperty -Name Display -Value $TreeViewControl

    return $BaseContainer
}