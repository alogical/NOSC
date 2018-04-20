﻿<#
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
    namespace Repository {
        public enum ObjectType {
            Blob,
            Commit,
            Tree,
            Tag
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

function New-Repository {
    $Repository = [PSCustomObject]@{
        # Branch index object.
        Index = New-Index

        # The working directory file path.
        WorkingDirectory = [String]::Empty

        # The repository sub file system.
        Repository       = [String]::Empty

        # The most recent commit object id for this branch.
        HEAD  = [String]::Empty

        # Content addressable file system manager.
        FileSystem = New-FileManager
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name SetLocation -Value {
        param(
            # Working directory path.
            [Parameter(Mandatory = $true)]
            [ValidateScript({[System.IO.Directory]::Exists($_)})]
            [String]
                $LiteralPath
        )

        $this.WorkingDirectory = $LiteralPath

        # Repository directory path
        $data_path = Join-Path $LiteralPath .vc
        $this.Repository = $data_path

        # Index file path
        $idx_path  = Join-Path $data_path index

        # HEAD file path
        $head_path = Join-Path $data_path HEAD

        # File system object storage directory path
        $fs_path   = Join-Path $data_path objects

        if (!$this.FileSystem.SetLocation($fs_path))
        {
            # Abort
            Write-Debug 'Directory is not initialized as a repository.'
            return
        }

        $this.HEAD = Get-Content $head_path

        if ([System.IO.File]::Exists($idx_path))
        {
            $this.Index.Load($idx_path)
        }
        else
        {
            $this.Index.Init($data_path)
        }

        return $true
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Init -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({[System.IO.Directory]::Exists($_)})]
            [String]
                $LiteralPath
        )
        # Repository directory path
        $data_path = Join-Path $LiteralPath .vc

        # Index file path
        $idx_path  = Join-Path $data_path index

        # HEAD file path
        $head_path = Join-Path $data_path HEAD

        # File system object storage directory path
        $fs_path   = Join-Path $data_path objects

        # Returns the directories created | NULL
        $a = New-Item $data_path -ItemType Directory
        $d = New-Item (Join-Path $data_path refs)     -ItemType Directory
        $h = New-Item (Join-Path $d.FullName heads)   -ItemType Directory
            '0000000000000000000000000000000000000000' > (Join-Path $h.FullName master)
             New-Item (Join-Path $d.FullName remotes) -ItemType Directory | Out-Null
             New-Item (Join-Path $d.FullName tags)    -ItemType Directory | Out-Null

        $d = New-Item (Join-Path $data_path logs)     -ItemType Directory
            [String]::Empty > (Join-Path $d.FullName HEAD)
        $d = New-Item (Join-Path $d.FullName refs)    -ItemType Directory
             New-Item (Join-Path $d.FullName heads)   -ItemType Directory | Out-Null
             New-Item (Join-Path $d.FullName remotes) -ItemType Directory | Out-Null

        $a.Attributes = [System.IO.FileAttributes]::Hidden

        # Initialize the content addressable file system.
        New-Item $this.FileSystem.Init($fs_path)
        'ref: refs/heads/master' > (Join-Path $data_path HEAD)

        if (!$this.SetLocation($LiteralPath)) {
            throw (New-Object System.IO.DirectoryNotFoundException("Failed to initialize: $LiteralPath"))
        }
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Status -Value {
        $files    = Get-ChildItem -LiteralPath $this.WorkingDirectory -Recurse -File
        $modified = @{}

        $path_filter = [System.Text.RegularExpressions.Regex]::Escape( ($this.WorkingTree + '\') )

        foreach ($file in $files)
        {
            $rel_path = $file.FullName -replace $path_filter, [String]::Empty
            if ($this.Index.Cache.Contains($rel_path))
            {
                $entry = $this.Index.Cache[$rel_path]
                if ($this.Compare($file, $entry) - [VersionControl.Repository.CompareResult]::Modified)
                {
                    $modified.Add($rel_path, @{
                            Entry = $entry
                            File  = $file
                        }
                    )
                }
            }
            else
            {
                $modified.Add($rel_path, @{
                        Entry = $null
                        File  = $file
                    }
                )
            }
        }

        return $modified
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Compare -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.FileInfo]
                $File,

            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Repository.Index.ObjectType]::Entry})]
            [Hashtable]
                $Entry
        )
        return (Compare-Entry @PSBoundParameters)
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Stage -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.FileInfo]
                $File
        )

        $entry = New-Entry
        $entry.Name   = $this.FileSystem.Hash($File)
        $entry.Length = $File.Length
        $entry.cTime  = $File.CreationTimeUtc
        $entry.mTime  = $File.LastWriteTimeUtc
        $entry.Path   = $File.FullName -replace [System.Text.RegularExpressions.Regex]::Escape($this.WorkingDirectory), [String]::Empty

        $this.Index.Add($entry)
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name UnStage -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.FileInfo]
                $File
        )

        $path_filter = [System.Text.RegularExpressions.Regex]::Escape( ($this.WorkingDirectory + '\') )
        $rel_path    = $File.FullName -replace $path_filter, [String]::Empty

        return $this.Index.Remove($this.Index.Cache[$rel_path])
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
        $commit.Tree    = Build-Commit $this.Index.Entries $this.Index.TREE $this.FileSystem

        return $this.FileSystem.Write( (ConvertTo-Json $commit) )
    }

    return $Repository
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

Import-Module "$AppPath\modules\VersionControl\FileSystem.psm1"
Import-Module "$AppPath\modules\VersionControl\Index.psm1"

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
            $TreeCache,

        # The content addressable file system manager.
        [Parameter(Mandatory = $true)]
        [Object]
            $FileSystem
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
    foreach ($cache in $TreeCache.Subtrees)
    {
        # Cached tree validation check.  If the cached tree is valid than the
        # tree hasn't been modified, and the tree object already exists in the
        # content addressable file system.
        if ($cache.Count -ge 0)
        {
            [void]$root.Subtrees.Add($cache.Name)
            continue
        }

        [void]$tree.Subtrees.Add( (Build-Tree $cache $Walked $Current $FileSystem) )
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
            $Current,

        # The content addressable file system manager.
        [Parameter(Mandatory = $true)]
        [Object]
            $FileSystem
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

        [void]$tree.Subtrees.Add( (Build-Tree $item $Walked $Current $FileSystem) )
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
        Type  = [VersionControl.Repository.ObjectType]::Tree

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

#
# Object Utilities
# ----------------
# These functions provide conversion from stored data to in memory nested data
# structures.  And object data structure copying.
#

<#
.SYNOPSIS
    Performs equivalency comparison between an index entry object and a file.

.DESCRIPTION
    Used to compare index and file objects to determine modified files within
    the repository's working directory.
#>
function Compare-Entry {
    param(
        [Parameter(Mandatory = $true)]
        [System.IO.FileInfo]
            $File,

        [Parameter(Mandatory = $true)]
        [ValidateScript({$_.Type -eq [VersionControl.Repository.Index.ObjectType]::Entry})]
        [Hashtable]
            $Entry,

        # The content addressable file system manager.
        [Parameter(Mandatory = $true)]
        [Object]
            $FileSystem
    )

    if ($File.CreationTimeUtc  -eq $Entry.cTime -and
        $File.LastWriteTimeUtc -eq $Entry.mTime -and
        $File.Length           -eq $Entry.Length)
    {
        if ($FileSystem.Hash($File) -eq $Entry.Name)
        {
            return [VersionControl.Repository.CompareResult]::Equivalent
        }
    }

    return [VersionControl.Repository.CompareResult]::Modified
}

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