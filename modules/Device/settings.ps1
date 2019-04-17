Add-Type -AssemblyName System.Windows.Forms
$InvocationPath = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)
$SettingsPath = Join-Path $InvocationPath 'settings.json'

enum DeviceSource {
    Csv = 0
    Orion = 1
}

enum OrionAuthType {
    WindowsCredential = 0
    OrionCredential = 1
}

function New-SettingsObject () {
    $settings = [PSCustomObject]@{
        DatabaseOptions = [PSCustomObject]@{
            PrimarySource = [DeviceSource]::Csv
            Csv = [PSCustomObject]@{
                RemotePath = [String]::Empty
                LocalPath = "$InvocationPath\..\..\database\devicedb"
            }
            Orion = [PSCustomObject]@{
                Url = [String]::Empty
                AuthType = [OrionAuthType]::WindowsCredential
            }
        }
        DisplayOptions = [PSCustomObject]@{
            Default = [String]::Empty # Name of the stored treeview display settings to load by default.
            StorePath = "$InvocationPath\..\..\database\groupdb"
        }
    }

    return $settings
}

function New-SettingsDialog ([PSCustomObject]$Settings) {

    if ($Settings -eq $null)
    {
        $Settings = New-SettingsObject
    }

    $interface = [PSCustomObject]@{
        DatabaseOptions = [PSCustomObject]@{
            Csv = [PSCustomObject]@{
                OptionContainer = $null
                PrimarySource = $null
                RemotePath = [PSCustomObject]@{
                    DisplayLabel = $null
                }
            }
            Orion = [PSCustomObject]@{
                OptionContainer = $null
                PrimarySource = $null
                Url = $null
                AuthType = $null
            }
        }

        DisplayOptions = [PSCustomObject]@{
            Default = $null
        }

        OptionsContainer = [PSCustomObject]@{
            DatabaseOptions = $null
            DisplayOptions = $null
        }

        OptionsPanel = $null
    }

    #region Control Events
    $csvdb_browse_event = {
        param ([System.Windows.Forms.Button]$sender, [System.EventArgs]$e)
        $browse_dialog = New-Object System.Windows.Forms.OpenFileDialog
        $browse_dialog.Title = "Remote Shared Device Database File Selection"
        $browse_dialog.Multiselect = $false
    
        # Currently only CSV flat databases are supported.
        $browse_dialog.Filter = "CSV Database (*.csv)|*.csv"
        $browse_dialog.FilterIndex = 1

        if ($browse_dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            $sender.Settings.DatabaseOptions.Csv.RemotePath =  $browse_dialog.FileName
            $sender.Interface.DatabaseOptions.Csv.RemotePath.DisplayLabel.Text = $browse_dialog.FileName
        }
    }

    $database_option_radio_event = {
        param ([System.Windows.Forms.RadioButton]$sender, [System.EventArgs]$e)
        if ($sender.Interface.DatabaseOptions.Csv.PrimarySource.Checked)
        {
            $sender.Interface.DatabaseOptions.Csv.OptionContainer.Enabled = $true
            $sender.Interface.DatabaseOptions.Orion.OptionContainer.Enabled = $false
        }
        else
        {
            $sender.Interface.DatabaseOptions.Csv.OptionContainer.Enabled = $false
            $sender.Interface.DatabaseOptions.Orion.OptionContainer.Enabled = $true
        }
    }

    $options_treeview_selectnode = {
        param ([System.Windows.Forms.TreeView]$sender, [System.EventArgs]$e)
        $target = $sender.GetNodeAt($sender.PointToClient([System.Windows.Forms.Control]::MousePosition))
        $previous = $sender.SelectedNode

        if ($target -ne $null -and $target -ne $previous)
        {
            $sender.SelectedNode = $target
            $previous.BackColor = $target.BackColor
            $previous.ForeColor = $target.ForeColor
            $target.BackColor = [System.Drawing.SystemColors]::Highlight
            $target.ForeColor = [System.Drawing.SystemColors]::HighlightText
            $target.DisplayOptions()
        }
    }
    #endregion Control Events

    #region Dialog Layout
    $form = New-Object System.Windows.Forms.Form
        $form.Width = 900
        $form.Height = 300
        $form.BackColor = [System.Drawing.Color]::White

        # Non-Resizable dialog
        $form.FormBorderStyle = [System.Windows.Forms.FormBorderStyle]::FixedDialog

        Add-Member -InputObject $form -MemberType NoteProperty -Name Settings -Value $settings

    $form_layout = New-Object System.Windows.Forms.TableLayoutPanel
        $form_layout.Dock = [System.Windows.Forms.DockStyle]::Fill
        $form_layout.CellBorderStyle = [System.Windows.Forms.TableLayoutPanelCellBorderStyle]::Single
        $form_layout.RowCount = 2

        $form_layout_rowstyle0 = New-Object System.Windows.Forms.RowStyle
        $form_layout_rowstyle0.SizeType = [System.Windows.Forms.SizeType]::Percent
        $form_layout_rowstyle0.Height = 100

        $form_layout_rowstyle1 = New-Object System.Windows.Forms.RowStyle
        $form_layout_rowstyle1.SizeType = [System.Windows.Forms.SizeType]::Absolute
        $form_layout_rowstyle1.Height = 30

        [void]$form_layout.RowStyles.Add($form_layout_rowstyle0)
        [void]$form_layout.RowStyles.Add($form_layout_rowstyle1)

        [void]$form.Controls.Add($form_layout)

    $options_layout = New-Object System.Windows.Forms.SplitContainer
        $options_layout.Dock = [System.Windows.Forms.DockStyle]::Fill
        $options_layout.SplitterDistance = 40
        $options_layout.SplitterWidth = 5
        $options_layout.IsSplitterFixed = $true
        $options_layout.Panel1.AutoScroll = $true
        $interface.OptionsPanel = $options_layout.Panel2

        [void]$form_layout.Controls.Add($options_layout, 0, 0)

    $options_treeview = New-Object System.Windows.Forms.TreeView
        $options_treeview.Dock = [System.Windows.Forms.DockStyle]::Fill
        $options_treeview.Add_Click($options_treeview_selectnode)
        [void]$options_layout.Panel1.Controls.Add($options_treeview)

        $options_treenode_database = New-Object System.Windows.Forms.TreeNode
            $options_treenode_database.Text = "Remote Database Settings"
            [void]$options_treeview.Nodes.Add($options_treenode_database)

            $options_treeview.SelectedNode = $options_treenode_database
            $options_treenode_database.BackColor = [System.Drawing.SystemColors]::Highlight
            $options_treenode_database.ForeColor = [System.Drawing.SystemColors]::HighlightText

            Add-Member -InputObject $options_treenode_database -MemberType NoteProperty -Name Interface -Value $interface
            Add-Member -InputObject $options_treenode_database -MemberType ScriptMethod -Name DisplayOptions -Value {
                [void]$this.Interface.OptionsPanel.Controls.Clear()
                [void]$this.Interface.OptionsPanel.Controls.Add($this.Interface.OptionsContainer.DatabaseOptions)
            }

        $options_treenode_display = New-Object System.Windows.Forms.TreeNode
            $options_treenode_display.Text = "Display Settings"
            [void]$options_treeview.Nodes.Add($options_treenode_display)

            Add-Member -InputObject $options_treenode_display -MemberType NoteProperty -Name Interface -Value $interface
            Add-Member -InputObject $options_treenode_display -MemberType ScriptMethod -Name DisplayOptions -Value {
                [void]$this.Interface.OptionsPanel.Controls.Clear()
                [void]$this.Interface.OptionsPanel.Controls.Add($this.Interface.OptionsContainer.DisplayOptions)
            }

    #endregion Dialog Layout

    # Options layout default widths.
    $margin = 10
    $width_settingname = 175
    $width_settingvalue = $options_layout.Panel2.ClientSize.Width - $width_settingname - ($margin * 2) - 12

    #region Device List Source Database Options
    $csvdb_settingname = New-Object System.Windows.Forms.Label
        $csvdb_settingname.Location = New-Object System.Drawing.Point(0, 0)
        $csvdb_settingname.Width = $width_settingname
        $csvdb_settingname.TextAlign = [System.Drawing.ContentAlignment]::TopRight
        $csvdb_settingname.Text = "Shared CSV file path:"

    $csvdb_settingvalue = New-Object System.Windows.Forms.TextBox
        $left = $csvdb_settingname.Location.X + $csvdb_settingname.Width + $margin
        $csvdb_settingvalue.Location = New-Object System.Drawing.Point($left, 0)
        $csvdb_settingvalue.Width = $width_settingvalue - 60
        $csvdb_settingvalue.BorderStyle = [System.Windows.Forms.BorderStyle]::FixedSingle
        $csvdb_settingvalue.ReadOnly = $true
        $interface.DatabaseOptions.Csv.RemotePath.DisplayLabel = $csvdb_settingvalue

        Add-Member -InputObject $csvdb_settingvalue -MemberType NoteProperty -Name Settings -Value $settings

    $csvdb_browse = New-Object System.Windows.Forms.Button
        $left = $csvdb_settingvalue.Location.X + $csvdb_settingvalue.Width + $margin
        $csvdb_browse.Location = New-Object System.Drawing.Point($left, 0)
        $csvdb_browse.Width = 50
        $csvdb_browse.Text = "Browse"
        $csvdb_browse.Add_Click($csvdb_browse_event)

        Add-Member -InputObject $csvdb_browse -MemberType NoteProperty -Name Interface -Value $interface
        Add-Member -InputObject $csvdb_browse -MemberType NoteProperty -Name Settings -Value $settings

    $csvdb_primarysource = New-Object System.Windows.Forms.RadioButton
        $csvdb_primarysource.Dock = [System.Windows.Forms.DockStyle]::Top
        $csvdb_primarysource.Add_CheckedChanged($database_option_radio_event)
        $interface.DatabaseOptions.Csv.PrimarySource = $csvdb_primarysource

        Add-Member -InputObject $csvdb_primarysource -MemberType NoteProperty -Name Interface -Value $interface
        Add-Member -InputObject $csvdb_primarysource -MemberType NoteProperty -Name Settings -Value $settings

    $oriondb_url_settingname = New-Object System.Windows.Forms.Label
        $oriondb_url_settingname.Location = New-Object System.Drawing.Point(0, 0)
        $oriondb_url_settingname.TextAlign = [System.Drawing.ContentAlignment]::TopRight
        $oriondb_url_settingname.Width = $width_settingname
        $oriondb_url_settingname.Text = "SolarWinds Orion Hostname:"

    $oriondb_url_settingvalue = New-Object System.Windows.Forms.TextBox
        $left = $oriondb_url_settingname.Location.X + $oriondb_url_settingname.Width + $margin
        $oriondb_url_settingvalue.Location = New-Object System.Drawing.Point($left, 0)
        $oriondb_url_settingvalue.Width = $width_settingvalue
        $interface.DatabaseOptions.Orion.Url = $oriondb_url_settingvalue

        Add-Member -InputObject $oriondb_url_settingvalue -MemberType NoteProperty -Name Settings -Value $settings

    $oriondb_primarysource = New-Object System.Windows.Forms.RadioButton
        $oriondb_primarysource.Dock = [System.Windows.Forms.DockStyle]::Top
        $oriondb_primarysource.Add_CheckedChanged($database_option_radio_event)
        $interface.DatabaseOptions.Orion.PrimarySource = $oriondb_primarysource

        Add-Member -InputObject $oriondb_primarysource -MemberType NoteProperty -Name Interface -Value $interface
        Add-Member -InputObject $oriondb_primarysource -MemberType NoteProperty -Name Settings -Value $settings

    $oriondb_auth_settingname = New-Object System.Windows.Forms.Label
        $oriondb_auth_settingname.Location = New-Object System.Drawing.Point(0, 0)
        $oriondb_auth_settingname.TextAlign = [System.Drawing.ContentAlignment]::TopRight
        $oriondb_auth_settingname.Width = $width_settingname
        $oriondb_auth_settingname.Text = "Orion authentication mode:"

    $oriondb_auth_settingvalue = New-Object System.Windows.Forms.ComboBox
        $left = $oriondb_auth_settingname.Location.X + $oriondb_auth_settingname.Width + $margin
        $oriondb_auth_settingvalue.Location = New-Object System.Drawing.Point($left, 0)
        $oriondb_auth_settingvalue.Width = $width_settingvalue
        $oriondb_auth_settingvalue.DataSource = @([OrionAuthType]::WindowsCredential, [OrionAuthType]::OrionCredential)
        $interface.DatabaseOptions.Orion.AuthType = $oriondb_auth_settingvalue

        Add-Member -InputObject $oriondb_auth_settingvalue -MemberType NoteProperty -Name Settings -Value $settings
    #endregion Device List Source Database Options

    #region Display Options
    $display_settingname = New-Object System.Windows.Forms.Label
        $display_settingname.TextAlign = [System.Drawing.ContentAlignment]::TopRight
        $display_settingname.Location = New-Object System.Drawing.Point(0, 0)
        $display_settingname.Width = $width_settingname
        $display_settingname.Text = "Default display settings"

    $display_settingvalue = New-Object System.Windows.Forms.ListBox
        $left = $display_settingname.Location.X + $display_settingname.Width + $margin
        $display_settingvalue.Location = New-Object System.Drawing.Point($left, 0)
        $interface.DisplayOptions.Default = $display_settingvalue

        # Load list of saved display settings.
        if (Test-Path $settings.DisplayOptions.StorePath -PathType Container)
        {
            Get-ChildItem "$($settings.DisplayOptions.StorePath)\*" | %{
                $display_settingvalue.Items.Add($_.Name)
            }
        }

        Add-Member -InputObject $display_settingvalue -MemberType NoteProperty -Name Settings -Value $settings
    #endregion Display Options

    #region Options Layout
    # Database options need to be grouped onto a single layout control for the radio buttons
    # to be grouped properly.
    $database_options_container = New-Object System.Windows.Forms.TableLayoutPanel
        $database_options_container.Dock = [System.Windows.Forms.DockStyle]::Fill
        $database_options_container.RowCount = 2
        $database_options_container.ColumnCount = 2

        # Radio Buttons
        $columnstyle0 = New-Object System.Windows.Forms.ColumnStyle
        $columnstyle0.SizeType = [System.Windows.Forms.SizeType]::Absolute
        $columnstyle0.Width = 20

        # Setting Panels
        $columnstyle1 = New-Object System.Windows.Forms.ColumnStyle
        $columnstyle1.SizeType = [System.Windows.Forms.SizeType]::Percent
        $columnstyle1.Width = 100

        [void]$database_options_container.ColumnStyles.Add($columnstyle0)
        [void]$database_options_container.ColumnStyles.Add($columnstyle1)

        $interface.OptionsContainer.DatabaseOptions = $database_options_container

    $csvdb_options_panel = New-Object System.Windows.Forms.Panel
        #$csvdb_options_panel.Dock = [System.Windows.Forms.DockStyle]::Fill
        $csvdb_options_panel.Width = $options_layout.Panel2.ClientSize.Width - $columnstyle0.Width
        $csvdb_options_panel.BackColor = [System.Drawing.Color]::White
        $interface.DatabaseOptions.Csv.OptionContainer = $csvdb_options_panel

        # Manually positioned controls.
        [void]$csvdb_options_panel.Controls.Add($csvdb_settingname)
        [void]$csvdb_options_panel.Controls.Add($csvdb_settingvalue)
        [void]$csvdb_options_panel.Controls.Add($csvdb_browse)

        # Add options container to options layout.
        [void]$database_options_container.Controls.Add($interface.DatabaseOptions.Csv.PrimarySource, 0, 0)
        [void]$database_options_container.Controls.Add($csvdb_options_panel, 1, 0)

    $oriondb_options_container = New-Object System.Windows.Forms.Panel
        #$oriondb_options_container.Dock = [System.Windows.Forms.DockStyle]::Fill
        $oriondb_options_container.Width = $options_layout.Panel2.ClientSize.Width - $columnstyle0.Width
        $oriondb_options_container.BackColor = [System.Drawing.Color]::White
        $interface.DatabaseOptions.Orion.OptionContainer = $oriondb_options_container

    $oriondb_auth_panel = New-Object System.Windows.Forms.Panel
        $oriondb_auth_panel.Dock = [System.Windows.Forms.DockStyle]::Top
        $oriondb_auth_panel.Height = $oriondb_auth_settingname.Height + $oriondb_auth_panel.Margin.Top + $oriondb_auth_panel.Margin.Bottom

        # Manually positioned controls.
        [void]$oriondb_auth_panel.Controls.Add($oriondb_auth_settingname)
        [void]$oriondb_auth_panel.Controls.Add($oriondb_auth_settingvalue)
        [void]$oriondb_options_container.Controls.Add($oriondb_auth_panel)

    $oriondb_url_panel = New-Object System.Windows.Forms.Panel
        $oriondb_url_panel.Dock = [System.Windows.Forms.DockStyle]::Top
        $oriondb_url_panel.Height = $oriondb_url_settingname.Height + $oriondb_url_panel.Margin.Top + $oriondb_url_panel.Margin.Bottom

        [void]$oriondb_url_panel.Controls.Add($oriondb_url_settingname)
        [void]$oriondb_url_panel.Controls.Add($oriondb_url_settingvalue)
        [void]$oriondb_options_container.Controls.Add($oriondb_url_panel)

        [void]$database_options_container.Controls.Add($interface.DatabaseOptions.Orion.PrimarySource, 0, 1)
        [void]$database_options_container.Controls.Add($oriondb_options_container, 1, 1)

    $display_options_container = New-Object System.Windows.Forms.Panel
        $display_options_container.Dock = [System.Windows.Forms.DockStyle]::Top

        # Manually positioned controls.
        [void]$display_options_container.Controls.Add($display_settingtitle)
        [void]$display_options_container.Controls.Add($display_settingname)
        [void]$display_options_container.Controls.Add($display_settingvalue)

        $interface.OptionsContainer.DisplayOptions = $display_options_container

    # Add option containers to dialog.
    [void]$options_layout.Panel2.Controls.Add($database_options_container)
    #endregion Options Layout


    $interface.DatabaseOptions.Csv.PrimarySource.Height = $interface.DatabaseOptions.Csv.OptionContainer.Height
    $interface.DatabaseOptions.Orion.PrimarySource.Height = $interface.DatabaseOptions.Orion.OptionContainer.Height

    if ($settings.DatabaseOptions.PrimarySource -eq [DeviceSource]::Csv)
    {
        $interface.DatabaseOptions.Csv.PrimarySource.Checked = $true
    }
    else
    {
        $interface.DatabaseOptions.Orion.PrimarySource.Checked = $true
    }

    return $form
}

$dialog = New-SettingsDialog
[void]$dialog.ShowDialog()
$dialog.Dispose()
