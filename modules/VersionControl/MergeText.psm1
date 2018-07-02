<#
.SYNOPSIS
    3-Way diff text file merge utility.

.DESCRIPTION
    Utility for performing a 3-way merge of modified text files.

.NOTES
    This module relies on the unix style diff.exe file.  The location to the
    external dependency is expected at:
        
        Global:AppPath\bin\diff.exe

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>
Add-Type -TypeDefinition @"
namespace VersionControl {
    namespace Diff {
        public enum EditAction {
            None,
            Addition,
            Deletion,
            Change
        }

        public enum LineState {
            Original,
            Modified,
            Conflicted
        }
    }
}
"@

###############################################################################
###############################################################################
## SECTION 01 ## PUBILC FUNCTIONS AND VARIABLES
##
## Pass-thru Export-ModuleMember calls export all functions and variables
## to the global session that were passed to this modules session from nested
## modules.
###############################################################################
###############################################################################

<#
.SYNOPSIS
    Performs a 3-way merge between two files and a common parent.

.DESCRIPTION
    Used to perform a 3-way merge for UTF8 documents.
#>
function Merge-Text {
    param(
        # Merge object containing the entries to be merged.
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
            $InputObject
    )

    # Get Ancestor content
    $ancestor = Get-Content $InputObject.FileSystem.Get($InputObject.Ancestor.Name)

    $ours   = Parse-Diff (& "$DIFF_EXEC $($InputObject.FileSystem.Get($InputObject.Ancestor.Name)) $($InputObject.FileSystem.Get($InputObject.Ours.Name))")
    $theirs = Parse-Diff (& "$DIFF_EXEC $($InputObject.FileSystem.Get($InputObject.Ancestor.Name)) $($InputObject.FileSystem.Get($InputObject.Theirs.Name))")
    $merge  = Compare-Diff3 $ours $theirs $ancestor.Count

    # Write new output file with line sources from Ancestor or merge edits.
    $edit_index  = 0
    $output_file = [String]::Empty
    $state = $merge.LineStates
    for ($i = 0; $i -lt $ancestor.Count; $i++)
    {
        # Unedited line:
        if ($state[$i] -eq [VersionControl.Diff.LineState]::Original)
        {
            # write original ancestor line
            $ancestor[$i] >> $output_file
        }
        # Edited line:
        else
        {
            $edit = $merge.Ordered[$edit_index++]

            if ($state[$i] -eq [VersionControl.Diff.LineState]::Conflicted)
            {
                if ($merge.OverlapsA.Contains($i))
                {
                    $conflicts = $merge.OverlapsA[$i]
                    $our_edit = $true
                }
                elseif ($merge.OverlapsB.Contains($i))
                {
                    $conflicts = $merge.OverlapsB[$i]
                    $our_edit = $false
                }
                else
                {
                    throw (New-Object System.ApplicationException(""))
                }

                # ===>
                '===>' >> $output_file

                # Write Their Version
                if ($our_edit)
                {
                    foreach ($conflict in $conflicts)
                    {
                        $edit_index++
                        foreach ($line in $conflict.rlines)
                        {
                            $line >> $output_file
                        }
                    }
                }
                else
                {
                    foreach ($line in $edit.rlines)
                    {
                        $line >> $output_file
                    }
                }

                # ========
                '========' >> $output_file

                # Write Our Version
                if ($our_edit)
                {
                    foreach ($line in $edit.rlines)
                    {
                        $line >> $output_file
                    }
                }
                else
                {
                    foreach ($conflict in $conflicts)
                    {
                        $edit_index++
                        foreach ($line in $conflict.rlines)
                        {
                            $line >> $output_file
                        }
                    }
                }

                # <===
                '<===' >> $output_file
            }
            # Else (not conflicted):
            else
            {
                # Write merge.edit version
                foreach ($line in $edit.rlines)
                {
                    $line >> $output_file
                    $i++
                }
            }
        }
    }

    # Verify all edits have been written
    if ($edit_index -ne $merge.Ordered.Count - 1)
    {
        throw (New-Object System.ApplicationException("All edits should have been written, but weren't!"))
    }

    # Return if merged files had conflict lines
    return ($merge.Conflicts.Count -gt 0)
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

$DIFF_EXEC = "$AppPath\bin\diff.exe"

<#
.SYNOPSIS
    Compares two diffs between a common ancestor and two changed files.

.DESCRIPTION
    Used to perform a 3-way merge for UTF8 documents.
#>
function Compare-Diff3 {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]
            $DiffA,

        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]
            $DiffB,

        [Parameter(Mandatory = $true)]
        [Int]
            $AncestorLength
    )
    # Current position within DiffB to optimize multiple passes
    $seek = 0

    # Ordered list of edits
    $ordered   = New-Object System.Collections.ArrayList

    # List of all conflicting edits
    $conflicts = New-Object System.Collections.ArrayList

    # DiffA edits that overlap multiple DiffB edits
    $overlap_a = @{}

    # DiffB edits that overlap multiple DiffA edits
    $overlap_b = @{}

    # Ancestor line edit state 
    #  line is unedited [original], edited [modified], or in conflict between a and b [conflicted]
    $line_states = New-Object VersionControl.Diff.LineState[] $AncestorLength
    $line_count  = $line_states.Count
    $line_max    = $line_states.Count - 1

    # Record DiffB lines as modified (0 based array)
    #  This is required as we may pass over the same record more than once in the DiffB array.
    #  as we search for conflicts with DiffA.
    foreach ($b in $DiffB)
    {
        if ($b.lstart -le $line_count)
        {
            if ($b.lstop -ge $line_count)
            {
                $sstop = $line_max
            }
            else
            {
                $sstop = $b.lstop - 1
            }
            for ($s = $b.lstart - 1; $s -lt $sstop; $s++)
            {
                $line_states[$s] = [VersionControl.Diff.LineState]::Modified
            }
        }

        if ($sstop -eq $line_max)
        {
            break
        }
    }

    foreach ($a in $DiffA)
    {
        # Record the lines as modified (0 based array)
        if ($a.lstart -le $line_count)
        {
            if ($a.lstop -ge $line_count)
            {
                $sstop = $line_max
            }
            else
            {
                $sstop = $a.lstop - 1
            }
            for ($s = $a.lstart - 1; $s -lt $sstop; $s++)
            {
                $line_states[$s] = [VersionControl.Diff.LineState]::Modified
            }
        }

        for ($i = $seek; $i -lt $DiffB.Count; $i++)
        {
            $b = $DiffB[$i]

            # [a...]
            #   [b...]
            if ($a.lstart -le $b.lstart -and $a.lstop -ge $b.lstart)
            {

                # Record the lines as conflicted (0 based array)
                if ($a.lstart -lt $line_count)
                {
                    # All lines of both edit records are considered in conflict for overlaps even if
                    # some of the changes don't overlap.
                    if ($a.lstop -gt $b.lstop)
                    {
                        $sstop = $a.lstop - 1
                    }
                    else
                    {
                        $sstop = $b.lstop - 1
                    }

                    # Index out of range protection
                    if ($sstop -ge $line_count)
                    {
                        $sstop = $line_max
                    }
                    for ($s = $a.lstart - 1; $s -lt $sstop; $s++)
                    {
                        $line_states[$s] = [VersionControl.Diff.LineState]::Conflicted
                    }
                }

                if (!$ordered.Contains($a))
                {
                    [void]$ordered.Add($a)
                }
                else
                {
                    [void]$ordered.Add($b)
                }

                # [a..............]
                #   [b...][b...][b...]
                if (!$overlap_a.Contains($a.lstart))
                {
                    $overlap_a.Add($a.lstart, (New-Object System.Collections.ArrayList))
                }
                [void]$overlap_a[$a.lstart].Add($b)

                $c = [PSCustomObject]@{a = $a; b = $b}
                [void]$conflicts.Add($c)
                continue
            }

            #   [a...]
            # [b...]
            if ($a.lstart -ge $b.lstart -and $a.lstart -le $b.lstop)
            {
                # Record the lines as conflicted (0 based array)
                if ($b.lstart -lt $line_count)
                {
                    # All lines of both edit records are considered in conflict for overlaps even if
                    # some of the changes don't overlap.
                    if ($a.lstop -gt $b.lstop)
                    {
                        $sstop = $a.lstop - 1
                    }
                    else
                    {
                        $sstop = $b.lstop - 1
                    }

                    # Index out of range protection
                    if ($sstop -ge $line_count)
                    {
                        $sstop = $line_max
                    }
                    for ($s = $b.lstart - 1; $s -lt $sstop; $s++)
                    {
                        $line_states[$s] = [VersionControl.Diff.LineState]::Conflicted
                    }
                }

                if (!$ordered.Contains($b))
                {
                    [void]$ordered.Add($b)
                }
                
                #   [a...][a...][a...]
                # [b...............]
                if (!$overlap_b.Contains($b.lstart))
                {
                    $overlap_b.Add($b.lstart, (New-Object System.Collections.ArrayList))
                }
                [void]$overlap_b[$b.lstart].Add($a)

                $c = [PSCustomObject]@{a = $a; b = $b}
                [void]$conflicts.Add($c)
                continue
            }

            # Optimize multiple passes over the b edits array
            # [a...]
            #        [b...]
            if ($a.lstop -lt $b.lstart)
            {
                if (!$ordered.Contains($a))
                {
                    [void]$ordered.Add($a)
                }
                if (!$ordered.Contains($b))
                {
                    [void]$ordered.Add($b)
                }

                $seek = $i
                break
            }

            # Optimize multiple passes over the b edits array
            #        [a...]
            # [b...]
            if ($a.lstart -gt $b.lstop)
            {
                if (!$ordered.Contains($b))
                {
                    [void]$ordered.Add($b)
                }
                if (!$ordered.Contains($a))
                {
                    [void]$ordered.Add($a)
                }

                $seek = $i + 1
                break
            }

            # DiffA has more edits
            #         [a...]++
            # [b=EOF]
            [void]$ordered.Add($a)
        }
    }

    # DiffB has more edits
    # [a=EOF]
    #         [b...]++
    if ($seek -lt $DiffB.Count)
    {
        for ($i = $seek; $i -lt $DiffB.Count; $i++)
        {
            [void]$ordered.Add($DiffB[$i])
        }
    }

    return [PSCustomObject]@{
        LineStates = $line_states
        Ordered    = $ordered
        Conflicts  = $conflicts
        OverlapsA  = $overlap_a
        OverlapsB  = $overlap_b
    }
}

<#
.SYNOPSIS
    Constructs a new Diff edit record.

.DESCRIPTION
    Data structure object constructor for diff edit records.
#>
function New-Edit {
    param(
        [Parameter(Mandatory = $false)]
        [String]
            $header = [String]::Empty
    )
        
    $edit = [PSCustomObject]@{
        action  = [VersionControl.Diff.EditAction]::None
        header  = [String]::Empty
        lstart  = 0
        lstop   = 0
        llines  = New-Object System.Collections.ArrayList
        llength = 0
        rstart  = 0
        rstop   = 0
        rlength = 0
        rlines  = New-Object System.Collections.ArrayList
        parsed  = $false
    }

    Add-Member -InputObject $edit -MemberType ScriptMethod -Name ParseHeader -Value $EDIT_PARSE_HEADER

    if (![String]::IsNullOrEmpty($header))
    {
        $edit.ParseHeader($header)
    }

    return $edit
}

<#
.SYNOPSIS
    Parses diff output into a dictionary of changes.

.DESCRIPTION
    Used to convert the text output of diff into a structured
    object representing the diff.
#>
function Parse-Diff {
    param(
        [Parameter(Mandatory = $true)]
        [String[]]
            $Diff
    )

    # Parsed diff content
    $parse = New-Object System.Collections.ArrayList
    $eof = $false

    # Diff sequential line parser
    for ($i = 0; $i -lt $Diff.Count; $i++)
    {
        if ($eof) { break }

        $edit = New-Edit $Diff[$i]
        [void]$parse.Add($edit)

        if ($edit.Action -eq [VersionControl.Diff.EditAction]::Change)
        {
            for ($l = 0; $l -le $edit.llength; $l++)
            {
                $i++
                [void]$edit.llines.Add( ($Diff[$i] -replace '< ', [String]::Empty) )
            }
            
            # Skip section divider "---"
            $i++
            # End of File marker for the diff
            if ($Diff[$i] -eq '\ No newline at end of file')
            {
                $eof = $true
                $i++
            }

            for ($r = 0; $r -le $edit.rlength; $r++)
            {
                $i++
                [void]$edit.rlines.Add( ($Diff[$i] -replace '> ', [String]::Empty) )
            }
        }

        if ($edit.Action -eq [VersionControl.Diff.EditAction]::Addition)
        {
            for ($r = 0; $r -le $edit.rlength; $r++)
            {
                $i++
                [void]$edit.rlines.Add( ($Diff[$i] -replace '> ', [String]::Empty) )
            }
        }

        if ($edit.Action -eq [VersionControl.Diff.EditAction]::Deletion)
        {
            for ($l = 0; $l -le $edit.llength; $l++)
            {
                $i++
                [void]$edit.llines.Add( ($Diff[$i] -replace '< ', [String]::Empty) )
            }
        }
    }

    return $parse
}

<#
.SYNOPSIS
    Edit record method scriptblock.

.DESCRIPTION
    Scriptblock for a diff edit record.ParseHeader() method. The ParseHeader method
    is written as a named scriptblock as an optimization.  This way, a new anonymous
    function doesn't have to be created for what may be hundreds of objects.
#>
$EDIT_PARSE_HEADER = {
    param(
        [Parameter(Mandatory = $true)]
        [String]
            $header
    )

    if ($this.parsed -eq $true)
    {
        throw (New-Object System.ApplicationException("Edit record header already parsed. [$($this.header)]"))
    }

    $this.header = $header

    if ($header -match '^(\d+),?(\d+)?(\w)(\d+),?(\d+)?')
    {
        if ($Matches[1] -ne $null) {$this.lstart = [int]($Matches[1])} else {$this.lstart = 0}
        if ($Matches[2] -ne $null) {$this.lstop  = [int]($Matches[2])} else {$this.lstop  = 0}
        $this.action = $Matches[3]
        if ($Matches[4] -ne $null) {$this.rstart = [int]($Matches[4])} else {$this.rstart = 0}
        if ($Matches[5] -ne $null) {$this.rstop  = [int]($Matches[5])} else {$this.rstop  = 0}

        if ($this.lstop -eq 0)
        {
            $this.llength = 0
            $this.lstop   = $this.lstart
        }
        else
        {
            $this.llength = $this.lstop - $this.lstart
        }

        if ($this.rstop -eq 0)
        {
            $this.rlength = 0
            $this.rstop   = $this.rstart
        }
        else
        {
            $this.rlength = $this.rstop - $this.rstart
        }
    }
    else
    {
        throw (New-Object System.ApplicationException("Parse diff header failed. [$header]"))
    }

    switch ($Matches[3])
    {
        # Addition
        a { $this.action = [VersionControl.Diff.EditAction]::Addition }
        # Deletion
        d { $this.action = [VersionControl.Diff.EditAction]::Deletion }
        # Change
        c { $this.action = [VersionControl.Diff.EditAction]::Change }
        default {
            throw (New-Object System.ApplicationException("Unknown diff edit action."))
        }
    }
}
