<#
.SYNOPSIS
    Index of a working directory for tracking changes.

.DESCRIPTION
    Provides context information of a working directory for determining what files
    have changed.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>
Add-Type -TypeDefinition @"
namespace VersionControl.Repository {
    namespace Index {
        public enum ObjectType {
            Entry,
            Cache
        }
        public enum CompareResult {
            Equivalent,
            Modified,
            Removed
        }
        public enum MergeState {
            None = 0,
            Ours,
            Theirs,
            Ancestor
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

function New-Index {
    $Index = [PSCustomObject]@{
        idx        = $null
        PathCache  = @{}
        Modified   = $false
        FileSystem = $null
        Path       = [String]::Empty
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Init -Value {
        param(
            # Index file path.
            [Parameter(Mandatory = $true)]
            [ValidateScript({Test-Path $_})]
            [String]
                $LiteralPath
        )

        $this.idx  = New-PrivateIndex
        $this.idx.HEAD = '0000000000000000000000000000000000000000'

        $this.Path = Join-Path $LiteralPath index
        $this.Write()
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Write -Value {
        ConvertTo-Json $this.idx -Depth 100 > $this.Path
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Load -Value {
        param(
            # Index file path.
            [Parameter(Mandatory = $true)]
            [ValidateScript({[System.IO.File]::Exists($_)})]
            [String]
                $LiteralPath
        )

        $content = Get-Content $LiteralPath -Raw
        $this.idx = ConvertFrom-PSObject (ConvertFrom-Json $content)
        $this.Path = $LiteralPath

        # If index has been changed...
        $this.Modified = !$this.idx.Commit
        $this.RefreshPathCache()

        return $this.idx.HEAD
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Checkout -Value {
        param(
            # A commit object ID.
            [Parameter(Mandatory = $true)]
            [String]
                $Commit
        )

        # Get commit object
        $object = ConvertFrom-Json (Get-Content $this.FileSystem.Get($Commit).FullName -Raw)
        $root   = ConvertFrom-PSObject (ConvertFrom-Json (Get-Content $this.FileSystem.Get($object.Tree) -Raw))

        # Update in-memory index
        $this.idx = New-PrivateIndex
        $this.idx.HEAD    = $Commit
        $this.idx.Commit  = $true
        $this.idx.TREE    = ConvertTo-CacheTree $root $Commit             # Root of TREE
        $this.idx.Entries.AddRange( (Build-Cache $root $this.idx.TREE) )  # Updates TREE/sub-trees

        $this.RefreshPathCache()
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name RefreshPathCache -Value {
        $PathCache = $this.PathCache
        $PathCache.Clear()

        foreach ($entry in $this.idx.Entries)
        {
            $PathCache.Add($entry.Path, $entry)
        }
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name SummarizeTrees -Value {
        # Walk entries to build reference list.
        $walked = @{
            root = New-Object System.Collections.ArrayList
        }
        foreach ($entry in $this.idx.Entries)
        {
            $parent = Split-Path $entry.Path -Parent
            if ([String]::IsNullOrEmpty($parent))
            {
                [void]$walked.root.Add( $entry.Path + $entry.Name )
                continue
            }
            if (!$walked.Contains( $parent ))
            {
                $walked.Add($parent, (New-Object System.Collections.ArrayList))
            }
            [void]$walked[$parent].Add( (Split-Path $entry.Path -Leaf) + $entry.Name )
        }
        $summary = @{}
        foreach ($entry in $walked.GetEnumerator())
        {
            $entry.Value.Sort()
            $summary[$entry.Key] = $this.FileSystem.ShaProvider.HashString( ($entry.Value -join [String]::Empty) )
        }
        return $summary, $walked
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name InvalidateTree -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $Path
        )

        # Cache Tree for this object
        #   The Cache Tree may also be invalidated by Repository.Status()
        $path_component = @((Split-Path $Path -Parent).Split('\'))
        $current = $this.TREE
        $current.Count = -1
        foreach ($dir in $path_component)
        {
            # File exists within the root of the working directory
            if ([String]::IsNullOrEmpty($dir))
            {
                break
            }

            # Tree Creation Control Flag
            $create = $true

            # Invalidate Tree
            foreach ($tree in $current.Subtrees)
            {
                if ($tree.Path -eq $dir)
                {
                    $tree.Count = -1
                    $current = $tree
                    $create  = $false
                    break
                }
            }

            # Create Empty Cache Tree
            if ($create)
            {
                $new = New-CacheTree
                $new.Path  = $dir
                $new.Count = -1
                [void]$current.Subtrees.Add($new)
                $current = $new
            }
        }
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name RevalidateTree -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $Path
        )

        # Calculate tree summaries to determine if the index is back in it's original
        # state for each tree in the entry path.
        $summary, $entries = $this.SummarizeTrees()

        # Cache Tree for this object
        #   The Cache Tree may also be invalidated by Repository.Status()
        $path_component = @((Split-Path $Path -Parent).Split('\'))
        $path_queue     = New-Object System.Collections.Queue
        $current = $this.TREE

        if ($summary.root -eq $current.Summary)
        {
            $current.Count = $entries.root.Count
        }

        foreach ($dir in $path_component)
        {
            $path_queue.Enqueue($dir)
            $path_rel = $path_queue.ToArray() -join '\'
            # Invalidate Tree
            foreach ($tree in $current.Subtrees)
            {
                if ($tree.Path -eq $dir)
                {
                    if ($tree.Summary -eq $summary[$path_rel])
                    {
                        $tree.Count = $entries[$path_rel].Count
                    }
                    $current = $tree
                    break
                }
            }
        }
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Add -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Repository.Index.ObjectType]::Entry})]
            [Hashtable]
                $InputObject,

            [Parameter(Mandatory = $false)]
            [Bool]
                $InvalidateTree = $true,

            [Parameter(Mandatory = $false)]
            [Bool]
                $Write = $true
        )

        # Previous entry if the added entry updates an existing entry
        $previous = $null
        $this.Modified   = $true
        $this.idx.Commit = $false

        # Cache the object path
        if (!$this.PathCache.Contains($InputObject.Path))
        {
            $this.PathCache.Add($InputObject.Path, $InputObject)
        }
        else
        {
            $previous = $this.PathCache[$InputObject.Path]
            $this.PathCache[$InputObject.Path] = $InputObject
        }

        # Remove the previous entry
        if ($previous)
        {
            [void]$this.Remove($previous, $true)
        }

        # Invalidate Cache Tree path for this object
        #   The Cache Tree may also be invalidated by Repository.Status()
        if ($InvalidateTree)
        {
            $this.InvalidateTree($InputObject.Path)
        }

        # Add new entry to the index.
        $i = $this.idx.Entries.Add($InputObject)

        if ($Write)
        {
            $this.Write()
        }

        return $i
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Remove -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Repository.Index.ObjectType]::Entry})]
            [Hashtable]
                $InputObject,

            [Parameter(Mandatory = $false)]
            [Bool]
                $CacheUpdated = $false
        )

        $this.Modified   = $true
        $this.idx.Commit = $false
        [void]$this.idx.Entries.Remove($InputObject)

        # Cache Management
        #   Entry object may have been removed from the cache by an Add operation
        #   before hand, or some other arbitrary action.
        if (!$CacheUpdated)
        {
            if ($this.PathCache.Contains($InputObject.Path))
            {
                $this.PathCache.Remove($InputObject.Path)
            }
        }
    }

    <#
    .SYNOPSIS
        Compares an index against this index for differences.

    .DESCRIPTION
        Used to identify differences between (additional files, and different versions
        of already tracked files) this index and a target index.
    #>
    Add-Member -InputObject $Index -MemberType ScriptMethod -Name DiffIndex -Value {
        param(
            # The index to be compared against this index.
            [Parameter(Mandatory = $true)]
            [PSCustomObject]
                $DifferenceIndex
        )

        # Difference representation between this index and the target index.
        $diff = [PSCustomObject]@{
            # File entries contained in target index, but not this index
            Additions  = New-Object System.Collections.ArrayList

            # File entries that are not the same between both indexes
            Changed    = New-Object System.Collections.ArrayList

            # File entries that are the same between both indexes
            Equivalent = New-Object System.Collections.ArrayList

            # File entries contained by this index, but not the target index
            Removed    = New-Object System.Collections.ArrayList

            # Quick reference cache
            PathCache  = @{}
        }

        $entry_filter = New-Object System.Collections.ArrayList
        $entry_filter.AddRange($this.idx.Entries.ToArray())

        $pathcache = $this.PathCache
        foreach ($entry in $DifferenceIndex.Entries)
        {
            $object = New-DiffObject

            # File Version Differences
            if ($pathcache.Contains($entry.Path))
            {
                $object.Ours   = $pathcache[$entry.Path]
                $object.Theirs = $entry

                $object.Ours.Merge   = [VersionControl.Repository.Index.MergeState]::Ours
                $object.Theirs.Merge = [VersionControl.Repository.Index.MergeState]::Theirs

                # Conflicts
                if ($entry.Name -ne $pathcache[$entry.Path].Name)
                {
                    $object.CompareResult = [VersionControl.Repository.Index.CompareResult]::Modified
                    [void]$diff.Changed.Add($object)
                }
                # Equivalent
                else
                {
                    $object.CompareResult = [VersionControl.Repository.Index.CompareResult]::Equivalent
                    [void]$diff.Equivalent.Add($object)
                }
                $entry_filter.Remove($pathcache[$entry.Path])
                $diff.PathCache.Add($entry.Path, $object)
            }
            # Additional Files
            else
            {
                $entry.Merge = [VersionControl.Repository.Index.MergeState]::Theirs
                $object.CompareResult  = [VersionControl.Repository.Index.CompareResult]::Modified
                $object.Theirs = $entry

                [void]$diff.Additions.Add($object)
                $diff.PathCache.Add($entry.Path, $object)
            }
        }

        # Removed Files
        foreach ($entry in $entry_filter)
        {
            $entry.Merge = [VersionControl.Repository.Index.MergeState]::Ours

            $object = New-DiffObject
            $object.CompareResult  = [VersionControl.Repository.Index.CompareResult]::Removed
            $object.Ours = $entry

            [void]$diff.Removed.Add($object)
            $diff.PathCache.Add($entry.Path, $object)
        }

        return $diff
    }

    <#
    .SYNOPSIS
        Performs equivalency comparison between an index entry object and a file.

    .DESCRIPTION
        Used to compare index and file objects to determine modified files within
        the repository's working directory.
    #>
    Add-Member -InputObject $Index -MemberType ScriptMethod -Name CompareEntry -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.FileInfo]
                $File,

            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Repository.Index.ObjectType]::Entry})]
            [Hashtable]
                $Entry
        )

        if ($File.CreationTimeUtc.ToFileTimeUtc()  -eq $Entry.cTime -and
            $File.LastWriteTimeUtc.ToFileTimeUtc() -eq $Entry.mTime -and
            $File.Length                           -eq $Entry.Length)
        {
            if ($this.FileSystem.Hash($File) -eq $Entry.Name)
            {
                return [VersionControl.Repository.Index.CompareResult]::Equivalent
            }
        }

        return [VersionControl.Repository.Index.CompareResult]::Modified
    }

    Add-Member -InputObject $Index -MemberType ScriptProperty -Name Summary -Value {
        return (Get-Summary $this.idx.Entries $this.FileSystem.ShaProvider)
    }

    Add-Member -InputObject $Index -MemberType ScriptProperty -Name Entries -Value {
        return (Write-Output -NoEnumerate $this.idx.Entries)
    }

    Add-Member -InputObject $Index -MemberType ScriptProperty -Name TREE -Value {
        return $this.idx.TREE
    }

    return $Index
}

#
# Public Object Constructors
# --------------------------
# Provides constructors for basic object data structures.  All objects are returned
# as a hashtable.
#

<#
.SYNOPSIS
    An index representation of a tracked file.

.DESCRIPTION
    Representation of a file used to identify changes to tracked files that will
    part of the next commit object.
#>
function New-Entry {
    $entry = @{
        # SHA1 Identifer of the blob object for this file.
        Name   = [String]::Empty

        # Object type.
        Type   = [VersionControl.Repository.Index.ObjectType]::Entry

        # Merge status state.
        Merge  = [VersionControl.Repository.Index.MergeState]::None

        # Size on disk of the file, truncated to 32-bit.
        Length = [Int32]0

        # Time the file was created.
        cTime  = [UInt32]0

        # Time the file was last modified.
        mTime  = [UInt32]0

        # Relative path of the file from the root of the working directory.
        Path   = [String]::Empty
    }
    return $entry
}

function Get-Summary {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]
            $Entries,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]
            $ShaProvider
    )
    $list = New-Object System.Collections.ArrayList
    for ($i = 0; $i -lt $Entries.Count; $i++)
    {
        [void]$list.Add( (Split-Path $Entries[$i].Path -Leaf) + $Entries[$i].Name )
    }
    $list.Sort()
    return $ShaProvider.HashString( ($list -join [String]::Empty) )
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

$InvocationPath  = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

Import-Module "$AppPath\modules\Common\Objects.psm1"

function New-PrivateIndex {
    $idx = @{
        # Represents if the objects in the index have been committed or not.
        Commit  = $false

        # Collection of entries representing tracked files in the working directory.
        Entries = New-Object System.Collections.ArrayList

        # Tree cache object.
        TREE    = New-CacheTree

        # The commit object that is represented by the index.
        HEAD    = [String]::Empty
    }

    return $idx
}

<#
.SYNOPSIS
    Cached tree object.

.DESCRIPTION
    Cached tree extension contains pre-computed hashes for trees that can be derived
    from the index.  It helps speed up tree object generation from index for a new
    commit.
#>
function New-CacheTree {
    $tree = @{
        # SHA1 Identifier.
        Name     = [String]::Empty

        # Object type.
        Type     = [VersionControl.Repository.Index.ObjectType]::Cache

        # Relative path of this tree from it's parent.
        Path     = [String]::Empty

        # Number of entries contained by this tree.
        #  If count is -1 than the tree is in an invalidated state.
        Count    = [Int32]0

        # Summary SHA1 of the oids for the entries contained within this tree.
        Summary   = [String]::Empty

        # Subtrees contained by this tree.
        Subtrees = New-Object System.Collections.ArrayList
    }
    return $tree
}

function New-DiffObject {
    $diff = [PSCustomObject]@{
        CompareResult  = $null
        Ours           = $null
        Theirs         = $null
        Ancestor       = $null
        FileSystem     = $null
    }

    return $diff
}

function Build-Cache {
    param(
        [Parameter(Mandatory = $true)]
        [Hashtable]
            $Tree,

        [Parameter(Mandatory = $true)]
        [Hashtable]
            $Cache
    )

    Write-Output $Tree.Entries

    foreach ($t in $Tree.Subtrees)
    {
        $object = Get-Content $this.FileSystem.Get($t).FullName -Raw
        $sub   = ConvertFrom-PSObject (ConvertFrom-Json $object)
        $child  = ConvertTo-CacheTree $sub $t
        [void]$Cache.Subtrees.Add( $child )
        Build-Cache $sub $child
    }
}

function ConvertTo-CacheTree {
    param(
        # Repository tree object.
        [Parameter(Mandatory = $true)]
        [Hashtable]
            $Tree,

        # SHA1 Object ID of the tree.
        [Parameter(Mandatory = $true)]
        [String]
            $Name
    )

    $t = New-CacheTree
    $t.Name    = $Name
    $t.Path    = $Tree.Path
    $t.Count   = $Tree.EntryCount
    $t.Summary = $Tree.Summary

    return $t
}