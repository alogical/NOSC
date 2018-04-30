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
    param(
        [Parameter(Mandatory = $false)]
        [String]
            $ConfigPath
    )

    $Repository = [PSCustomObject]@{
        # Branch index object.
        Index = New-Index

        # The working directory file path.
        WorkingDirectory = [String]::Empty

        # The repository sub file system.
        Repository       = [String]::Empty

        # The HEAD ref for this branch.
        HEAD  = [String]::Empty

        # Content addressable file system manager.
        FileSystem = New-FileManager

        # User name supplied for commits and merges.
        User = [String]::Empty

        # Email address of user.
        Email = [String]::Empty

        # Repository configuration path.
        Config = $ConfigPath
    }

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
                $LiteralPath,

            [Parameter(Mandatory = $false)]
            [Bool]
                $Bare = $false
        )
        $this.WorkingDirectory = $LiteralPath

        if (!$Bare)
        {
            $data_path = Join-Path $LiteralPath .vc
        }
        else
        {
            $data_path = $LiteralPath
        }

        # Repository directory path
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

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name GetHeadOid -Value {
        [System.Text.RegularExpressions.Match]$match = $Regex.Head.Match($this.HEAD)
        $ref = $match.Groups['path'].Value
        return (Get-Content (Join-Path $this.Repository $ref))
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name WriteHeadOid -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $ObjectID
        )
        [System.Text.RegularExpressions.Match]$match = $Regex.Head.Match($this.HEAD)
        $ref = $match.Groups['path'].Value
        $ObjectID > (Join-Path $this.Repository $ref)
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name GetHead -Value {
        $object = Get-Content $this.FileSystem.Get($this.GetHeadOid()) -Raw
        return (ConvertFrom-PSObject (ConvertFrom-Json $object))
    }

    ## Configuration Control --------------------------------------------------
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name InitConfig -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $ConfigPath,

            [Parameter(Mandatory = $false)]
            [String]
                $User,

            [Parameter(Mandatory = $false)]
            [String]
                $Email
        )

        $config = @{
            User      = $env:USERNAME
            Email     = [String]::Empty
        }

        if (![String]::IsNullOrEmpty($User))
        {
            $config.User = $User
        }

        if (![String]::IsNullOrEmpty($Email))
        {
            $config.Email = $Email
        }

        $this.Config = $ConfigPath

        ConvertTo-Json $config > $ConfigPath
        return $config
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name SetUser -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $User
        )

        $config = ConvertFrom-Json (Get-Content $this.Config -Raw)
        $config.User = $User
        $this.User   = $User

        ConvertTo-Json $config > $this.Config
    }

    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name SetEmail -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $Email
        )

        $config = ConvertFrom-Json (Get-Content $this.Config -Raw)
        $config.Email = $Email
        $this.Email   = $Email

        ConvertTo-Json $config > $this.Config
    }

    <#
    .SYNOPSIS
        Initializes a standard repository.

    .DESCRIPTION
        Used to initialize a standard repository's hidden .vc sub-directory structure.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name InitLocal -Value {
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
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name InitRemote -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({[System.IO.Directory]::Exists($_)})]
            [String]
                $LiteralPath
        )

        Initialize-Repository $LiteralPath -FileSystem $this.FileSystem

        if (!$this.SetLocation($LiteralPath, $true)) {
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
        $head = $this.FileSystem.Get($this.GetHeadOid())
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

    <#
    .SYNOPSIS
        Commits changes tracked in the repository index.

    .DESCRIPTION
        Saves modified objects to the content addressable file system and creates a commit
        object which represents the state of the saved changes to the working directory.  The
        HEAD of the branch is pointed to the new commit object, and the index updated.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Commit -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $Message
        )

        if ($this.Index.idx.Commit)
        {
            # Abort - No changes have been added to the index for the commit.
            return
        }

        $parent = $this.GetHeadOid()

        $commit = New-Commit
        [void]$commit.Parents.Add($parent)
        $commit.Author  = $this.User
        $commit.Email   = $this.Email
        $commit.Message = $Message
        $commit.Tree    = Build-Commit $this.Index.Entries $this.Index.TREE $this.FileSystem

        $oid = $this.FileSystem.WriteBlob( [System.Text.ASCIIEncoding]::UTF8.GetBytes((ConvertTo-Json $commit -Depth 100)) )
        $this.WriteHeadOid($oid)

        # Update the Index
        $this.Index.Checkout($oid)
        $this.Index.idx.HEAD   = $oid
        $this.Index.idx.Commit = $true
        $this.Index.Write()

        # Update the Logs
        $this.LogCommit(
            $parent,
            $oid,
            $commit.Date,
            $commit.UtcOffset,
            ($commit.Message.Split("`n"))[0]
        )

        return $oid
    }

    <#
    .SYNOPSIS
        Logs commits to a branch.

    .DESCRIPTION
        Updates the branch and head log for a commit.

          Format:
          <prev_sha1> <new_sha1> <user_name> <email_addr> <utc_time> <utc_offset> commit: <message_line1>
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name LogCommit -Value {
        param(
            # Parent commit SHA1 object ID.
            [Parameter(Mandatory = $true)]
            [String]
                $Parent,

            # Current commit SHA1 object ID.
            [Parameter(Mandatory = $true)]
            [String]
                $Commit,

            # UTC time of commit.  File time format.
            [Parameter(Mandatory = $true)]
            [String]
                $UtcTime,

            # UTC timezone offset.
            [Parameter(Mandatory = $true)]
            [String]
                $UtcOffset,

            # First line of commit message. Used as title of the commit.
            [Parameter(Mandatory = $true)]
            [String]
                $Message
        )

        # Resolve logging paths.
        $head_path = $this.HEAD -replace "ref: refs\/heads\/", "" -replace "\/", "\"
        $LogBranch = Join-Path (Join-Path $this.Repository logs\refs\heads) $head_path
        $LogHead   = Join-Path $this.Repository logs\HEAD

        $msg = "{0} {1} {2} <{3}> {4} {5} commit: {6}" -f $Parent, $Commit, $this.User, $this.Email, $UtcTime, $UtcOffset, $Message
        $msg >> $LogBranch
        $msg >> $LogHead
    }

    <#
    .SYNOPSIS
        Starts a new branch log.

    .DESCRIPTION
        Creates a new branch log and adds the first line of log specifying from
        from which branch the target branch was created.

          Format:
          0000000000000000000000000000000000000000 <HEAD_sha1> <user_name> <email_addr> <utc_time> <utc_offset> branch: Created from <source_branch_name>
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name LogBranch -Value {

    }

    <#
    .SYNOPSIS
        Logs moving between branches.

    .DESCRIPTION
        Updates the HEAD log when moving from one branch to another.
          Format:
          <from_sha1> <to_sha1> <user_name> <email_addr> <utc_time> <utc_offset> checkout: moving from <source_branch_name> to <destination_branch_name>
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name LogCheckout -Value {

    }

    <#
    .SYNOPSIS
        Logs the initialization of a repository by cloning another repository.

    .DESCRIPTION
        Updates the HEAD log with information about the source repository that
        was used during the clone operation.

        NOTE: This will be the first log entry for the HEAD and ref logs created
        during the clone operation.

          Format:
          0000000000000000000000000000000000000000 <HEAD_sha1> <user_name> <email_addr> <utc_time> <utc_offset> clone: from <source_repository_uri>
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name LogClone -Value {

    }

    <#
    .SYNOPSIS
        Logs merges of a branch into another branch.

    .DESCRIPTION
        Updates the branch and head log for a merge.

          Format:
          <prev_sha1> <new_sha1> <user_name> <email_addr> <utc_time> <utc_offset> merge <source_branch_name>: Merge made by the <strategy_type> strategy.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name LogMerge -Value {

    }

    <#
    .SYNOPSIS
        Logs pulling changes from a remote branch into a local branch.

    .DESCRIPTION
        Updates the branch and head log for a pull.

          Format:
          <prev_sha1> <new_sha1> <user_name> <email_addr> <utc_time> <utc_offset> pull: Fast-forward
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name LogPull -Value {

    }

    # Set repository content addressable file system.
    $Repository.Index.FileSystem = $Repository.FileSystem

    # Load configuration user information
    if (![String]::IsNullOrEmpty($ConfigPath))
    {
        if (Test-Path $ConfigPath)
        {
            $config = ConvertFrom-Json (Get-Content $ConfigPath -Raw)
            $Repository.Config = $ConfigPath
        }
        else
        {
            $config = $Repository.InitConfig($ConfigPath)
        }
    }
    else
    {
        $default = Join-Path $InvocationPath config
        if (Test-Path $default)
        {
            $config = ConvertFrom-Json (Get-Content $default -Raw)
            $Repository.Config = $default
        }
        else
        {
            $config = $Repository.InitConfig($default)
        }
    }

    $Repository.User      = $config.User
    $Repository.Email     = $config.Email

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

$Regex = @{}
$Regex.Head = New-Object System.Text.RegularExpressions.Regex(
    '^ref: (?<path>.*)$',
    [System.Text.RegularExpressions.RegexOptions]::Compiled)

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

    # HEAD file path
    $head_path = Join-Path $LiteralPath HEAD

    # File system object storage directory path
    $fs_path   = Join-Path $LiteralPath objects

    # Returns the directories created | NULL
    $d = New-Item (Join-Path $LiteralPath refs)      -ItemType Directory
    $h = New-Item (Join-Path $d.FullName heads)      -ItemType Directory
        '0000000000000000000000000000000000000000' > (Join-Path $h.FullName master)
         New-Item (Join-Path $d.FullName remotes)    -ItemType Directory | Out-Null
         New-Item (Join-Path $d.FullName tags)       -ItemType Directory | Out-Null

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
            [void]$FileSystem.WriteStream( (Get-Item $entry.Path).FullName )
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

        [void]$root.Subtrees.Add( (Build-Tree $cache $Walked $Current $FileSystem) )
    }

    $root.EntryCount = $root.Entries.Count
    $root.TreeCount  = $root.Subtrees.Count

    return $root
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

    return $FileSystem.WriteBlob( [System.Text.ASCIIEncoding]::UTF8.GetBytes((ConvertTo-Json $tree -Depth 100)) )
}

function New-Commit {
    $commit = @{
        # SHA1 identifier of the tree that represents the files of this commit.
        Tree      = [String]::Empty

        # SHA1 identifiers of the commits that preceded this commit.
        Parents   = New-Object System.Collections.ArrayList

        # The name of the person who authored this commit.
        Author    = [String]::Empty

        # The name of the person who authored this commit.
        Email     = [String]::Empty
        
        # Message describing the changes and purpose of this commit.
        Message   = [String]::Empty

        # Date the commit object was created.
        Date      = [DateTime]::Now.ToFileTimeUtc()

        # UTC timezone offset
        UtcOffset = Get-UtcOffset
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

function Get-UtcOffset {
    $tz = Get-TimeZone
    $offset = $tz.GetUtcOffset( (Get-Date) )

    if ($offset.Hours -gt 0)
    {
        return ("+{0:d2}{1:d2}" -f $offset.Hours, $offset.Minutes)
    }
    else
    {
        return ("{0:d2}{1:d2}" -f $offset.Hours, $offset.Minutes)
    }
}