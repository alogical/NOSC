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
    namespace Repository {
        public enum ObjectType {
            Blob,
            Commit,
            Tree,
            Tag
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
    $Repository.Index.FileSystem = $Repository.FileSystem

    <#
    .SYNOPSIS
        Changes working directories.

    .DESCRIPTION
        Changes from one repository to another.
    #>
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

    <#
    .SYNOPSIS
        Initializes a standard repository.

    .DESCRIPTION
        Used to initialize a standard repository's hidden .vc sub-directory structure.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name InitStd -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({[System.IO.Directory]::Exists($_)})]
            [String]
                $LiteralPath
        )

        # Repository directory path
        $data_path = Join-Path $LiteralPath .vc

        $vc = New-Item $data_path -ItemType Directory
        $vc.Attributes = [System.IO.FileAttributes]::Hidden

        Initialize-Repository $data_path -FileSystem $this.FileSystem

        if (!$this.SetLocation($LiteralPath)) {
            throw (New-Object System.IO.DirectoryNotFoundException("Failed to initialize: $LiteralPath"))
        }
    }

    <#
    .SYNOPSIS
        Initializes a bare repository.

    .DESCRIPTION
        Used to initialize a bare repository which has no working directory.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name InitBare -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({[System.IO.Directory]::Exists($_)})]
            [String]
                $LiteralPath
        )

        Initialize-Repository $LiteralPath -FileSystem $this.FileSystem

        if (!$this.SetLocation($LiteralPath)) {
            throw (New-Object System.IO.DirectoryNotFoundException("Failed to initialize: $LiteralPath"))
        }
    }

    <#
    .SYNOPSIS
        Get a list of modified files.

    .DESCRIPTION
        Compares the index cache against the working directory to determine which tracked
        files have been modified, and if there are any new files.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Status -Value {
        $files    = Get-ChildItem -LiteralPath $this.WorkingDirectory -Recurse -File
        $modified = @{}

        $path_filter = [System.Text.RegularExpressions.Regex]::Escape( ($this.WorkingDirectory + '\') )

        # Entries that were not found in the working directory
        $entry_filter = New-Object System.Collections.ArrayList

        if ($this.idx.Entries.Count -gt 0)
        {
            $entry_filter.AddRange($this.idx.Entries.ToArray())
        }

        # Validate current working directory contents
        foreach ($file in $files)
        {
            $rel_path = $file.FullName -replace $path_filter, [String]::Empty

            # Modified file detection
            if ($this.Index.PathCache.Contains($rel_path))
            {
                $entry = $this.Index.PathCache[$rel_path]
                [void]$entry_filter.Remove($entry)

                if ($this.Index.Compare($file, $entry) -eq [VersionControl.Repository.Index.CompareResult]::Modified)
                {
                    $modified.Add($rel_path, @{
                            Entry = $entry
                            File  = $file
                        }
                    )
                }
            }

            # New file
            else
            {
                $modified.Add($rel_path, @{
                        Entry = $null
                        File  = $file
                    }
                )
            }
        }

        # Renamed or Deleted file detection
        foreach ($entry in $entry_filter)
        {
            $modified.Add($rel_path, @{
                    Entry = $entry
                    File  = $null
                }
            )
        }

        if ($modified.Count -gt 0)
        {
            $this.Index.Modified = $true
        }

        return $modified
    }

    <#
    .SYNOPSIS
        Adds an entry for a new or modified file.

    .DESCRIPTION
        Used to track changes to the working directory in preparation for the next commit.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Stage -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.FileInfo]
                $File
        )

        $path_filter = [System.Text.RegularExpressions.Regex]::Escape( ($this.WorkingDirectory + '\') )

        $entry = New-Entry
        $entry.Name   = $this.FileSystem.Hash($File)
        $entry.Length = $File.Length
        $entry.cTime  = $File.CreationTimeUtc.ToFileTimeUtc()
        $entry.mTime  = $File.LastWriteTimeUtc.ToFileTimeUtc()
        $entry.Path   = $File.FullName -replace $path_filter, [String]::Empty

        $this.Index.Add($entry)
    }

    <#
    .SYNOPSIS
        Unstages the modified version of a file.

    .DESCRIPTION
        Used to untrack changes to a file and revert the index entry for the file to
        the previously committed version of the file.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Unstage -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Repository.Index.ObjectType]::Entry})]
            [Hashtable]
                $Entry
        )

        # Revert to the previous commit entry if available.
        $head = $this.FileSystem.Get($this.HEAD)
        if ($head)
        {
            $commit = ConvertFrom-Json (Get-Content $head.FullName -Raw)
            foreach ($item in $commit.Entries)
            {
                if ($item.Path -eq $Entry.Path)
                {
                    return $this.Index.Add($item)
                }
            }
            return $this.Index.Remove($entry)
        }
        else
        {
            return $this.Index.Remove($entry)
        }
    }

    <#
    .SYNOPSIS
        Untracks a file.

    .DESCRIPTION
        Used to untrack a file from the repository history when deleting a file from
        the working directory.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Untrack -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Index.ObjectType]::Entry})]
            [Hashtable]
                $Entry
        )

        return $this.Index.Remove($entry)
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
Import-Module "$AppPath\modules\Common\Objects.psm1"

$InvocationPath  = [System.IO.Path]::GetDirectoryName($MyInvocation.MyCommand.Definition)

<#
.SYNOPSIS
    Initializes a repository.

.DESCRIPTION
    Used to initialize a repository's file structure.
#>
function Initialize-Repository {
    param(
        # The directory in which the repository structure will be created.
        [Parameter(Mandatory = $true)]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
        [String]
            $LiteralPath,

        # The content addressable file system object of the repository.
        [Parameter(Mandatory = $true)]
        [Object]
            $FileSystem
    )

    # Index file path
    $idx_path  = Join-Path $LiteralPath index

    # HEAD file path
    $head_path = Join-Path $LiteralPath HEAD

    # File system object storage directory path
    $fs_path   = Join-Path $LiteralPath objects

    # Returns the directories created | NULL
    $d = New-Item (Join-Path $LiteralPath refs)      -ItemType Directory
    $h = New-Item (Join-Path $d.FullName heads)      -ItemType Directory
        '0000000000000000000000000000000000000000' > (Join-Path $h.FullName master)
            New-Item (Join-Path $d.FullName remotes) -ItemType Directory | Out-Null
            New-Item (Join-Path $d.FullName tags)    -ItemType Directory | Out-Null

    $d = New-Item (Join-Path $LiteralPath logs)      -ItemType Directory
        [String]::Empty > (Join-Path $d.FullName HEAD)
    $d = New-Item (Join-Path $d.FullName refs)       -ItemType Directory
            New-Item (Join-Path $d.FullName heads)   -ItemType Directory | Out-Null
            New-Item (Join-Path $d.FullName remotes) -ItemType Directory | Out-Null

    # Initialize the content addressable file system.
    New-Item $FileSystem.Init($fs_path)
    'ref: refs/heads/master' > $head_path
}

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