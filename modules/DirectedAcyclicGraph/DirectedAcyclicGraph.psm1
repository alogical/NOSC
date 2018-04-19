<#
.SYNOPSIS
    Directed Acyclic Graph (DAG) module.

.DESCRIPTION
    Provides DAG capabilities for data coloboration and version control.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>
Add-Type -TypeDefinition @"
namespace VersionControl {
    namespace DAG {
        public enum ObjectType {
            Blob,
            Commit,
            Tree,
            TreeEntry
            TreeCache,
            Tag
        }
    }
}
"@

Import-Module "$AppPath\modules\AddressableFileSystem\AddressableFileSystem.psm1"

###############################################################################
###############################################################################
## SECTION 01 ## PUBILC FUNCTIONS AND VARIABLES
##
## Pass-thru Export-ModuleMember calls export all functions and variables
## to the global session that were passed to this modules session from nested
## modules.
###############################################################################
###############################################################################

$Repository = [PSCustomObject]@{
    Index = $null
    HEAD  = [String]::Empty
}

Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Stage -Value {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]
            $File
    )


}

Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Commit -Value {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]
            $Parents,

        [Parameter(Mandatory = $true)]
        [String]
            $Author,

        [Parameter(Mandatory = $true)]
        [String]
            $Message,

        [Parameter(Mandatory = $true)]
        [String]
            $Tree
    )

    $commit = New-Commit
    $commit.Parents = $this.HEAD
    $commit.Author  = $Author
    $commit.Message = $Message
    $commit.Tree    = Build-Commit $this.Index.Entries $this.Index.TREE

    return $FileSystem.Write( (ConvertTo-Json $commit) )
}

function Load-Tree {
    param(
        # Root directory of the content addressable files system.
        [Parameter(Mandatory = $true)]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
        [String]
            $LiteralPath,

        # SHA1 name of index tree.
        [Parameter(Mandatory = $true)]
        [String]
            $Name
    )

    $f = Get-Item (Join-Path $LiteralPath $Name)

    if (!$f) {
        throw (New-Object System.IO.FileNotFoundException("Could not locate index: $Name"))
    }

    $stream  = $f.OpenText()
    $content = $stream.ReadToEnd()

    $stream.Close()
    return ( ConvertFrom-PSObject (ConvertFrom-Json $content) )
}

Export-ModuleMember *

###############################################################################
###############################################################################
## SECTION 02 ## PRIVATE FUNCTIONS AND VARIABLES
##
## No function or variable in this section is exported unless done so by an
## explicit call to Export-ModuleMember
###############################################################################
###############################################################################

$InvocationPath  = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

function Build-Commit {
    param(
        # The list of entries to be processed for this tree.
        [Parameter(Mandatory = $true)]
        [System.Collections.ArrayList]
            $Entries,

        # The index list of cached trees to speed up processing.
        [Parameter(Mandatory = $true)]
        [Hashtable]
            $TreeCache
    )

    # Paths that have been walked, and Trees created for.
    $walked  = @{
        root = New-Object System.Collections.ArrayList
    }
    $current = New-Object System.Collections.Stack

    # Walk entries to build reference list.
    foreach ($entry in $Entries)
    {
        # Write object to content addressable file system.
        if (!$FileSystem.Exists($entry.Name))
        {
            [void]$FileSystem.Write( (Get-Item $entry.Path) )
        }

        $parent = Split-Path $entry.Path -Parent
        if ([String]::IsNullOrEmpty($parent))
        {
            [void]$walked.root.Add($entry)
            continue
        }
        if (!$walked.Contains( $parent ))
        {
            $walked.Add($parent, (New-Object System.Collections.ArrayList))
        }
        [void]$walked[$parent].Add($entry)
    }

    # Initialize root tree
    $root = New-Tree
    $root.Entries = $walked.root

    # Recursively build subtrees
    foreach ($cache in $TreeCache)
    {
        # Cached tree validation check.  If the cached tree is valid than the
        # tree hasn't been modified, and the tree object already exists in the
        # content addressable file system.
        if ($cache.Count -ge 0)
        {
            [void]$root.Subtrees.Add($cache.Name)
            continue
        }

        [void]$tree.Subtrees.Add( (Build-Tree $cache $Walked $Current) )
    }

    $tree.EntryCount = $tree.Entries.Count
    $tree.TreeCount  = $tree.Subtrees.Count

    return $tree
}

function Build-Tree {
    param(
        [Parameter(Mandatory = $true)]
        [Hashtable]
            $Cache,

        [Parameter(Mandatory = $true)]
        [Hashtable]
            $Walked,

        [Parameter(Mandatory = $true)]
        [System.Collections.Stack]
            $Current
    )
    # Set current tree path relative to working directory.
    $Current.Push($cache.Path)

    # Initialize Tree object.
    $tree = New-Tree
    $tree.Path = $cache.Path
        
    # Get list of entries learned from the index.
    $tree.Entries = $walked[ ($current.ToArray() -join '\') ]

    foreach ($item in $Cache.Subtrees)
    {
        # Cached tree validation check.  If the cached tree is valid than the
        # tree hasn't been modified, and the tree object already exists in the
        # content addressable file system.
        if ($item.Count -ge 0)
        {
            [void]$tree.Subtrees.Add($item.Name)
            continue
        }

        [void]$tree.Subtrees.Add( (Build-Tree $item $Walked $Current) )
    }

    $tree.EntryCount = $tree.Entries.Count
    $tree.TreeCount  = $tree.Subtrees.Count

    [void]$Current.Pop()

    return $FileSystem.Write( (ConvertTo-Json $tree) )
}

function New-Commit {
    $commit = @{
        # SHA1 identifier of the tree that represents the files of this commit.
        Tree    = [String]::Empty

        # SHA1 identifiers of the commits that preceded this commit.
        Parents = [String]::Empty

        # The name of the person who authored this commit.
        Author  = [String]::Empty
        
        # Message describing the changes and purpose of this commit.
        Message = [String]::Empty

        # Date the commit object was created.
        Date    = [DateTime]::Now
    }

    return $commit
}

function New-Tree {
    $tree = @{
        # Object type.
        Type  = [VersionControl.DAG.ObjectType]::Tree

        # Relative path of this tree from it's parent.
        Path  = [String]::Empty
        
        # Pre-computed entry object count so array.count doesn't need to be
        # called, which requires a O(n) linear operation.
        EntryCount = [Int32]0

        # Pre-computed subtree object count so array.count doesn't need to be
        # called, which requires a O(n) linear operation.
        TreeCount = [Int32]0

        # The list of entries contained by this tree.
        Entries = New-Object System.Collections.ArrayList

        # The list of subtree object id's contained by this tree.
        Subtrees = New-Object System.Collections.ArrayList
    }

    return $tree
}

<#
.SYNOPSIS
    Cached tree object.

.DESCRIPTION
    Cached tree extension contains pre-computed hashes for trees that can be derived
    from the index.  It helps speed up tree object generation from index for a new
    commit.
#>
function New-CachedTree {
    $tree = @{
        # SHA1 Identifier.
        Name     = [String]::Empty
        
        # Object type.
        Type     = [VersionControl.DAG.ObjectType]::TreeCache

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
        Name         = [String]::Empty

        # Object type.
        Type         = [VersionControl.DAG.ObjectType]::TreeEntry

        # Size on disk of the file, truncated to 32-bit.
        Size         = [Int32]0

        # Time the file was created.
        CreatedTime  = [UInt32]0

        # Time the file was last modified.
        ModifiedTime = [UInt32]0

        # Relative path of the file from the root of the working directory.
        Path         = [String]::Empty
    }
    return $entry
}

#
# Object Utilities
# ----------------
# These functions provide conversion from stored data to in memory nested data
# structures.  And object data structure copying.
#

<#
.SYNOPSIS
    Performs a deep copy of a Hashtable memory structure.
#>
function Copy-Hashtable {
    param(
        [Parameter(Mandatory = $true)]
        [Hashtable]
            $InputObject
    )
    $hash = @{}
    foreach ($entry in $InputObject.GetEnumerator()) {
        $hash[$entry.Key] = $entry.Value
    }

    return $hash
}

function New-SecureHashProvider {
    $provider = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider

    Add-Member -InputObject $provider -MemberType ScriptMethod -Name HashFile -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.FileInfo]
                $File
        )
        $reader = [System.IO.StreamReader]$File.FullName
        [void] $this.ComputeHash( $reader.BaseStream )

        $reader.Close()

        return $this.OutString
    }

    Add-Member -InputObject $provider -MemberType ScriptMethod -Name HashString -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $InputString
        )

        $buffer = [System.Text.UnicodeEncoding]::UTF8.GetBytes($InputString)
        $this.ComputeHash($buffer)

        return $this.OutString
    }

    Add-Member -InputObject $provider -MemberType ScriptProperty -Name OutString -Value {
        $hash = $this.Hash | %{"{0:x2}" -f $_}
        return ($hash -join "")
    }

    return $provider
}