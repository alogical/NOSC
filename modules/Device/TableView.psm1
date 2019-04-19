<#
.SYNOPSIS
    Baseline network host device information management.

.DESCRIPTION
    Windows GUI components for managing the list of devices that make up the
    network baseline as a sortable table.

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

Export-ModuleMember -Function *

###############################################################################
###############################################################################
## SECTION 02 ## PRIVATE FUNCTIONS AND VARIABLES
##
## No function or variable in this section is exported unless done so by an
## explicit call to Export-ModuleMember
###############################################################################
###############################################################################

function New-DataGridView {
    [CmdletBinding()]
    param(
        # Column data type information.
        [Parameter(Mandatory = $false)]
            [System.Management.Automation.PSCustomObject]
            $Schema,
        
        # Column data bindings.
        [Parameter(Mandatory = $false)]
            [System.Windows.Forms.Binding[]]
            $Binding,

        # Manager for a list of binding objects for other controls.
        [Parameter(Mandatory = $false)]
            [System.Windows.Forms.BindingContext]
            $BindingContext
    )
    $DataGridView = New-Object System.Windows.Forms.DataGridView
        #
        # Default Allow All User Actions
        #
        $DataGridView.AllowUserToAddRows       = $true
        $DataGridView.AllowUserToDeleteRows    = $true
        $DataGridView.AllowUserToOrderColumns  = $true
        $DataGridView.AllowUserToResizeColumns = $true
        $DataGridView.AllowUserToResizeRows    = $true

        #
        # Default Table Layout Options
        #
        $DataGridView.Dock                = [System.Windows.Forms.DockStyle]::Fill
        $DataGridView.AutoGenerateColumns = $true
        $DataGridView.AutoSizeRowsMode    = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink
        $DataGridView.AutoSizeColumnsMode = [System.Windows.Forms.AutoSizeMode]::GrowAndShrink

        #
        # Default Table Cell & Row Styles
        #
        $DataGridView.ColumnHeadersDefaultCellStyle.BackColor   = [System.Drawing.Color]::Navy
        $DataGridView.ColumnHeadersDefaultCellStyle.ForeColor   = [System.Drawing.Color]::White
        $DataGridView.AlternatingRowsDefaultCellStyle.BackColor = [System.Drawing.Color]::DarkBlue
        $DataGridView.AlternatingRowsDefaultCellStyle.ForeColor = [System.Drawing.Color]::AliceBlue

    #
    # ScriptMethod LoadData
    <#
    .SYNOPSIS
        Protected data loading method.

    .DESCRIPTION
        Imports a comma seperated value (CSV) file as a data table for the DataGridView control.
    #>
    $LoadData = {
        param(
            # Source file.
            [Parameter(Mandatory = $true)]
                [ValidateScript({$_.Extension -match '.csv'})]
                [System.IO.FileInfo]
                $DataSource
        )

        $parser = New-Object System.Data.DataTableReader
        $this.DataSource = $Data
    }
    Add-Member -InputObject $DataGridView -MemberType ScriptMethod -Name LoadData -Value $LoadData

    #
    # ScriptProperty DoubleBuffered
    <#
    .SYNOPSIS
        Exposes Private:DoubleBuffered Property

    .DESCRIPTION
        Set DoubleBuffered to true in order to improve scrolling performance for large
        data sets.
    #>
    $Get_DoubleBuffered = {
        param(
            [Parameter(Mandatory = $true)]
                [Bool]
                $Setting
        )
        $type = [System.Type]$this.GetType()
        $property = $type.GetProperty("DoubleBuffered",
            [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)

        return $property.GetValue($this)
    }
    <#
    .SYNOPSIS
        Exposes Private:DoubleBuffered Property

    .DESCRIPTION
        Set DoubleBuffered to true in order to improve scrolling performance for large
        data sets.
    #>
    $Set_DoubleBuffered = {
        param(
            [Parameter(Mandatory = $true)]
                [Bool]
                $Setting
        )
        $type = [System.Type]$this.GetType()
        $property = $type.GetProperty("DoubleBuffered",
            [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::NonPublic)

        $property.SetValue($this, $Setting, $null)
    }
    Add-Member -InputObject $DataGridView -MemberType ScriptProperty -Name DoubleBuffered -Value $Get_DoubleBuffered $Set_DoubleBuffered
}

# Csv Text Field Parsing to DataTable required by DataGridView
function Fill-DataTable ([System.IO.FileInfo]$Source, [System.Data.DataTable]$Table) {
    try
    {
        $parser = New-Object Microsoft.VisualBasic.FileIO.TextFieldParser($Source.FullName)
        $parser.Delimiters = @(",")
        $parser.HasFieldsEnclosedInQuotes = $true
        $parser.TextFieldType = [Microsoft.VisualBasic.FileIO.FieldType]::Delimited
        $parser.TrimWhiteSpace = $true

        # Read Columns... Row 0
        $headers = $parser.ReadFields()
        foreach ($col in $headers)
        {
            [void]$Table.Columns.Add($col, $col.GetType())
        }

        while (!$parser.EndOfData)
        {
            [void]$Table.Rows.Add($parser.ReadFields())
        }
    }
    catch
    {
        Write-Error $_
    }
    finally
    {
        $parser.Close()
    }
}

function Export-DataTable ([System.Data.DataTable]$DataTable, [String]$Path) {
    $schema = @{}
    $export = New-Object System.Collections.ArrayList
    foreach ($c in $DataTable.Columns)
    {
        $schema.Add($c.ColumnName, $null)
    }
    foreach ($r in $DataTable.Rows)
    {
        foreach ($c in $DataTable.Columns)
        {
            $schema[$c.ColumnName] = $r[$c.ColumnName]
        }
        [void]$export.Add(([PSCustomObject]$schema))
    }

    $export | ConvertTo-Csv -NoTypeInformation | Out-File $Path
}
