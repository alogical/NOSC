﻿<#
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
            Modified
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

        $this.RefreshCache()

        return $this.idx.HEAD
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Checkout -Value {
        param(
            # A commit tree.
            [Parameter(Mandatory = $true)]
            [Object]
                $Commit
        )

        $this.idx = New-PrivateIndex
        $this.idx.TREE   = ConvertTo-CacheTree $Commit.Tree
        $this.idx.Entries = Build-Cache $Commit.Tree $this.idx.TREE

        $this.RefreshCache()
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name RefreshCache -Value {
        $PathCache = $this.PathCache
        $PathCache.Clear()

        foreach ($entry in $this.idx.Entries)
        {
            $PathCache.Add($entry.Path, $entry)
        }
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Add -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Repository.Index.ObjectType]::Entry})]
            [Hashtable]
                $InputObject
        )

        # Previous entry if the added entry updates an existing entry
        $previous = $null
        $this.Modified = $true

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

        # Cache Tree for this object
        #   The Cache Tree may also be invalidated by Repository.Status()
        $path_component = @((Split-Path $InputObject.Path -Parent).Split('\'))
        $current = $this.TREE
        $current.Count = -1
        foreach ($dir in $path_component)
        {
            # Create Empty Cache Tree
            if ($current.Subtrees.Count -eq 0 -and ![String]::IsNullOrEmpty($dir))
            {
                $new = New-CacheTree
                $new.Path  = $dir
                $new.Count = -1
                [void]$current.Subtrees.Add($new)
                $current = $new
                continue
            }

            # Invalidate Tree
            foreach ($tree in $current.Subtrees)
            {
                if ($tree.Path -eq $dir)
                {
                    $tree.Count = -1
                    $current = $tree
                    break
                }
            }
        }

        # Save changes to the index.
        $i = $this.idx.Entries.Add($InputObject)
        $this.Write()

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

        $this.Modified = $true
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
        Performs equivalency comparison between an index entry object and a file.

    .DESCRIPTION
        Used to compare index and file objects to determine modified files within
        the repository's working directory.
    #>
    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Compare -Value {
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

        # Subtrees contained by this tree.
        Subtrees = New-Object System.Collections.ArrayList
    }
    return $tree
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
        $child = Convert-Tree $t
        [void]$Cache.Subtrees.Add( $child )
        Build-Cache $t $child
    }
}

function ConvertTo-CacheTree {
    param(
        [Parameter(Mandatory = $true)]
        [Hashtable]
            $Tree
    )

    $t = New-CachedTree
    $t.Name = $Tree.Name
    $t.Path = $Tree.Path
    $t.Count = $Tree.Count

    return $t
}