<#
.SYNOPSIS
    File version control management module.

.DESCRIPTION
    Provides version control capabilities for data coloboration and historical
    data management using a directed acyclic graph (DAG) commit model.

.NOTES
    This module emulates the Git version control system, but doesn't implement
    all of the features available in Git. This module cannot be used to manage
    a Git repository.

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
        Repository = [String]::Empty

        # The HEAD ref for this branch.
        HEAD = [String]::Empty

        # Content addressable file system manager.
        FileSystem = New-FileManager

        # User name supplied for commits and merges.
        User = [String]::Empty

        # Email address of user.
        Email = [String]::Empty

        # Repository user configuration path.
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

    <#
    .SYNOPSIS
        Get the HEAD object ID for a branch.

    .DESCRIPTION
        Retrieves the SHA1 object ID of the specified branch name.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name GetBranchOid -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $Name
        )
        $refs = Join-Path $this.Repository refs/heads
        return (Get-Content (Join-Path $refs $Name))
    }

    <#
    .SYNOPSIS
        Get the names of all branches.

    .DESCRIPTION
        Retrieves the ref name for all repository branches.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name GetBranches -Value {
        $ref_path = Join-Path $this.Repository refs/heads
        $pattern  = [System.Text.RegularExpressions.Regex]::Escape($ref_path + '\')
        $refs     = Get-ChildItem $ref_path -File -Recurse
        foreach ($ref in $refs)
        {
            $name = $ref.FullName -replace $pattern, [String]::Empty
            Write-Output ($name -replace '\\', '/')
        }
    }

    <#
    .SYNOPSIS
        Get the HEAD object ID for the current branch.

    .DESCRIPTION
        Retrieves the SHA1 object ID of the current branch.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name GetHeadOid -Value {
        $ref = $this.GetHeadPath()
        return (Get-Content (Join-Path $this.Repository $ref))
    }

    <#
    .SYNOPSIS
        Get the HEAD branch ref path for the current branch.

    .DESCRIPTION
        Retrieves the reference path of the current branch.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name GetHeadPath -Value {
        [System.Text.RegularExpressions.Match]$match = $Regex.Head.Match($this.HEAD)
        return $match.Groups['path'].Value
    }

    <#
    .SYNOPSIS
        Get the HEAD branch name for the current branch.

    .DESCRIPTION
        Retrieves the reference name of the current branch.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name GetHeadName -Value {
        $path = $this.GetHeadPath()
        return ($path -replace 'refs\/heads\/', [String]::Empty)
    }

    <#
    .SYNOPSIS
        Updates the HEAD ref pointer.

    .DESCRIPTION
        Updates the HEAD reference pointer for the current branch to the supplied SHA1
        object ID.
    #>
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

    <#
    .SYNOPSIS
        Retrieves the HEAD commit object.

    .DESCRIPTION
        Returns a deserialized copy the commit object that represents the HEAD of the
        current branch.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name GetHead -Value {
        $object = Get-Content $this.FileSystem.Get($this.GetHeadOid()) -Raw
        return (ConvertFrom-PSObject (ConvertFrom-Json $object))
    }

    <#
    .SYNOPSIS
        Initializes the VersionControl user information configuration file.

    .DESCRIPTION
        Used to initialize the user information configuration file at the specified
        location.
    #>
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

    <#
    .SYNOPSIS
        Sets the configured user name.

    .DESCRIPTION
        Sets the configured user name and updates the configuration file.
    #>
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

    <#
    .SYNOPSIS
        Sets the configured user email address.

    .DESCRIPTION
        Sets the configured user email address and updates the configuration file.
    #>
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

                if ($this.Index.CompareEntry($file, $entry) -eq [VersionControl.Repository.Index.CompareResult]::Modified)
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
        Checks if the working directory has modifications.

    .DESCRIPTION
        Compares the index cache against the working directory to determine if any tracked
        files have been modified or new files added.

        Returns true if the working tree has been modified, otherwise false.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptProperty -Name Modified -Value {
        # If a previous action has marked the index as modified, skip working directory.
        if ($this.Index.Modified)
        {
            return $true
        }

        $modified = @{}
        $path_filter = [System.Text.RegularExpressions.Regex]::Escape( ($this.WorkingDirectory + '\') )

        # Entries that were not found in the working directory
        $entry_filter = New-Object System.Collections.ArrayList

        if ($this.idx.Entries.Count -gt 0)
        {
            $entry_filter.AddRange($this.idx.Entries.ToArray())
        }

        # Validate current working directory contents
        foreach ($file in (Get-ChildItem -LiteralPath $this.WorkingDirectory -Recurse -File))
        {
            $rel_path = $file.FullName -replace $path_filter, [String]::Empty

            # Modified file detection
            if ($this.Index.PathCache.Contains($rel_path))
            {
                $entry = $this.Index.PathCache[$rel_path]
                [void]$entry_filter.Remove($entry)

                if ($this.Index.CompareEntry($file, $entry) -eq [VersionControl.Repository.Index.CompareResult]::Modified)
                {
                    return $true
                }
            }

            # New file
            else
            {
                return $true
            }
        }

        # Renamed or Deleted file detection
        if ($entry_filter.Count -gt 0)
        {
            return $true
        }

        return $false
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
        Adds an entries for a new or modified files.

    .DESCRIPTION
        Used to track changes to the working directory in preparation for the next commit.

        Updates all new or modified files to the index.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name StageAll -Value {
        $status = $this.Status()
        foreach ($item in $status.GetEnumerator())
        {
            if ($item.Value.File -ne $null)
            {
                [void]$this.Stage($item.Value.File)
            }
        }
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
        }
        else
        {
            return $this.Index.Remove($entry)
        }

        # Get Tree object for this blob
        $root = ConvertFrom-Json (Get-Content $this.FileSystem.Get($commit.Tree) -Raw)
        if ($Entry.Path -notmatch '\\')
        {
            $tree = $root
        }
        else
        {
            $path = @(Split-Path $Entry.Path -Parent)
            $path_stack = New-Object System.Collections.Stack
            for ($i = $path.Count - 1; $i -ge 0; $i--)
            {
                $path_stack.Push($path[$i])
            }
            $tree = Get-SubTree -Stack $path_stack -Tree $root -FileSystem $this.FileSystem
        }

        # Get Parent blob object ID from Tree
        if ($tree)
        {
            $i = -1
            foreach ($item in $tree.Entries)
            {
                if ($item.Path -eq $Entry.Path)
                {
                    # Revert to previous entry; skip tree invalidation & index write
                    $i = $this.Index.Add( (ConvertFrom-PSObject $item), $false, $false )
                    $this.Index.RevalidateTree($item.Path)
                    break
                }
            }
            if ($i -ge 0 -and $commit.Summary -eq $this.Index.Summary)
            {
                $this.Index.idx.Commit = $true
            }
            # Save the index changes
            $this.Index.Write()
            return $i
        }
        return $this.Index.Remove($Entry)
    }

    <#
    .SYNOPSIS
        Untracks a file.

    .DESCRIPTION
        Used to untrack a file from the repository history when deleting a file from
        the working directory.
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Remove -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Repository.Index.ObjectType]::Entry})]
            [Hashtable]
                $Entry
        )
        $fullpath = Join-Path $this.WorkingDirectory $Entry.Path
        Remove-Item $fullpath -Force
        return $this.Index.Remove($entry)
    }

    <#
    .SYNOPSIS
        Creates a new branch within the repository.

    .DESCRIPTION
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name CreateBranch -Value {
        param(
            # The name of the new branch to create.
            [Parameter(Mandatory = $true)]
            [String]
                $Name,

            # The name of the branch from which the new branch is being created from.
            [Parameter(Mandatory = $true)]
            [String]
                $Source
        )
        $ref_path = Join-Path $this.Repository refs/heads
        $log_path = Join-Path $this.Repository logs/refs/heads

        if ($Name -match '\\')
        {
            $dir = $Name.Split('\')
        }
        elseif ($Name -match '\/')
        {
            $dir = $Name.Split('/')
        }
        if ($dir.Count -gt 0)
        {
            for ($i = 0; $i -lt $dir.Count - 1; $i++)
            {
                $ref_path = Join-Path $ref_path $dir[$i]
                if (!(Test-Path $ref_path))
                {
                    New-Item $ref_path -ItemType Directory | Out-Null
                }

                $log_path = Join-Path $log_path $dir[$i]
                if (!(Test-Path $log_path))
                {
                    New-Item $log_path -ItemType Directory | Out-Null
                }
            }
        }
        $ref_path = Join-Path $ref_path $Name
        $log_path = Join-Path $log_path $Name

        $this.GetBranchOid($Source) > $ref_path
        New-Item $log_path -ItemType File | Out-Null

        $this.LogBranch($Name, $Source)
    }

    <#
    .SYNOPSIS
        Deletes a branch from the repository.

    .DESCRIPTION
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name DeleteBranch -Value {
        param(
            # The name of the branch to delete.
            [Parameter(Mandatory = $true)]
            [String]
                $Name
        )

        # DO NOT DELETE THE CURRENT REPOSITORY HEAD

        # Validate branch has been merged!

        # If forcing deletion of an unmerged branch, trace objects that will be orphaned.

            # Remove orphan objects from content addressable file system.

        # Remove branch ref

        # Remove branch log
    }

    <#
    .SYNOPSIS
        Changes between branches within the repository.

    .DESCRIPTION
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Checkout -Value {
        param(
            # The name of the branch to checkout.
            [Parameter(Mandatory = $true)]
            [String]
                $Name,

            # Force checkout regardless of changes to the working directory
            [Parameter(Mandatory = $false)]
            [Bool]
                $Force = $false
        )

        if (!$Force -and ($this.Index.Modified -or $this.Modified))
        {
            throw (New-Object System.InvalidOperationException("There are un-committed changes to the working directory."))
        }

        $this.LogCheckout($Name)

        # Point the repository to the destination branch head
        $this.HEAD = "ref: refs/heads/$Name"
        $this.HEAD > (Join-Path $this.Repository HEAD)
        $head = $this.GetHeadOid()

        # Create Checkout Index
        $checkout = New-Index
        $checkout.Path = $this.Index.Path
        $checkout.FileSystem = $this.FileSystem
        $checkout.Checkout($head)

        # Entries that are to be removed from the working directory
        $rem_filter = New-Object System.Collections.ArrayList
        $rem_filter.AddRange($this.Index.idx.Entries.ToArray())

        # Entries missing from the working directory
        $add_filter = New-Object System.Collections.ArrayList
        $add_filter.AddRange($checkout.idx.Entries.ToArray())

        # Reset Working Directory
        $cache = $checkout.PathCache
        foreach ($e in $this.Index.Entries)
        {
            if ($cache.Contains($e.Path))
            {
                # Checkout entry
                $c = $cache[$e.Path]

                # Remove entry from filter lists
                [void]$rem_filter.Remove($e)
                [void]$add_filter.Remove($c)

                # Replace current file with checkout file
                if ($c.Name -ne $e.Name)
                {
                    $full_path = Join-Path $this.WorkingDirectory $c.Path
                    Copy-Item $this.FileSystem.Get($c.Name) $full_path -Force
                    $file = Get-Item $full_path
                    $file.LastWriteTimeUtc = [DateTime]::FromFileTimeUtc($c.mTime)
                    $file.CreationTimeUtc  = [DateTime]::FromFileTimeUtc($c.cTime)
                }
            }
        }

        # Add missing entries
        #  Perform this action before removing old files so we don't have to duplicate
        #  work adding and removing directories.
        foreach ($e in $add_filter)
        {
            $full_path = Join-Path $this.WorkingDirectory $e.Path
            $dir_path  = Split-Path $full_path -Parent

            # Force creation of destination folder
            New-Item $dir_path -ItemType Directory -ErrorAction Continue | Out-Null

            # Copy checkout file to working directory
            Copy-Item $this.FileSystem.Get($e.Name) $full_path -Force
            $file = Get-Item $full_path
            $file.LastWriteTimeUtc = [DateTime]::FromFileTimeUtc($e.mTime)
            $file.CreationTimeUtc  = [DateTime]::FromFileTimeUtc($e.cTime)
        }

        # Remove entries not a part of this commit
        foreach ($e in $rem_filter)
        {
            $full_path = Join-Path $this.WorkingDirectory $e.Path
            $dir_path  = Split-Path $full_path -Parent

            # Remove file from working directory
            Remove-Item $full_path -Force

            # Remove empty folders from working directory
            if (!(Get-ChildItem $dir_path -File -Recurse))
            {
                Remove-Item $dir_path -Force
            }
        }

        # Updated Repository Index
        $this.Index = $checkout
        $this.Index.Write()

        return $this.Index.idx.HEAD
    }

    <#
    .SYNOPSIS
        Merges changes from a branch into the current branch.

    .DESCRIPTION
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Merge -Value {
        param(
            # The name of the branch to being merged from.
            [Parameter(Mandatory = $true)]
            [String]
                $Source
        )

        # Our-->Parent || Their-->Parent
        $commit_parent = $null
        $commit = ConvertFrom-Json (Get-Item $this.FileSystem.Get($this.Index.idx.HEAD))
        if ($commit)
        {
            foreach ($p in $commit.Parents)
            {
                if ($p -ne $NULL_COMMIT)
                {
                    $commit_parent = $p
                    break
                }
            }
        }

        # There is no parent commit from which to perform a three way merge
        #  Complain to the user... or:
        #  Consider all files with the same names in ours && theirs to be a conflict
        #  ... or:
        #  Fast Forward all changes to match theirs
        if ($commit_parent -eq $null)
        {
            throw (New-Object System.InvalidOperationException("There is no parent commit from which to perform a three way merge."))
        }

        # Checkout the current branch parent commit as index --> Parent
        $parent = New-Index
        $parent.FileSystem = $this.FileSystem
        $parent.Checkout($commit_parent)

        # Checkout the source branch commit as index --> Theirs
        $theirs = New-Index
        $theirs.FileSystem = $this.FileSystem
        $theirs.Checkout($this.GetBranchOid($Source))

        # Compare Ours <==> Parent --> Our-Changes

        # Compare Theirs <==> Parent --> Their-Changes

        # Compare Our-Changes <==> Their-Changes --> File-Conflicts

        # ForEach File-Conflict in File-Conflicts

            # Diff Our-File <==> Parent-File --> Our-Diff

            # Diff Their-File <==> Parent-File --> Their-Diff

            # Compare Our-Diff <==> Their-Diff --> Diff-Conflicts, Diff-Merges

            # Update Diff-Conflicts --> Index
    }

    <#
    .SYNOPSIS
        Clones a repository to the specified path.

    .DESCRIPTION
    #>
    Add-Member -InputObject $Repository -MemberType ScriptMethod -Name Clone -Value {
        param(
            # The path to the repository being cloned.
            [Parameter(Mandatory = $true)]
            [String]
                $Source,

            # The path of the working directory being cloned too.
            [Parameter(Mandatory = $true)]
            [String]
                $Destination
        )
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
        $commit.Summary = $this.Index.Summary
        $commit.Tree    = Build-Commit $this.Index.Entries $this.Index.TREE $this.FileSystem

        $oid = $this.FileSystem.WriteBlob( [System.Text.ASCIIEncoding]::UTF8.GetBytes((ConvertTo-Json $commit -Depth 100)) )
        $this.WriteHeadOid($oid)

        # Update the Index
        $this.Index.Checkout($oid)
        $this.Index.Modified = $false
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
        param(
            # The name of the new branch created.
            [Parameter(Mandatory = $true)]
            [String]
                $Name,

            # The name of the branch from which the new branch is being created from.
            [Parameter(Mandatory = $true)]
            [String]
                $Source
        )

        $log_path = Join-Path $this.Repository logs/refs/heads
        $log_path = Join-Path $log_path $Name

        $msg = "{0} {1} {2} <{3}> {4} {5} branch: Created from {6}" -f `
            $NULL_COMMIT,
            $this.GetBranchOid($Source),
            $this.User,
            $this.Email,
            [DateTime]::Now.ToFileTimeUtc(),
            (Get-UtcOffset),
            $Source

        $msg >> $log_path
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
        param(
            # Name of the branch being checked out.
            [Parameter(Mandatory = $true)]
            [String]
                $Name
        )
        $log_path = Join-Path $this.Repository logs/HEAD
        $msg = "{0} {1} {2} <{3}> {4} {5} checkout: moving from {6} to {7}" -f `
            $this.GetHeadOid(),
            $this.GetBranchOid($Name),
            $this.User,
            $this.Email,
            [DateTime]::Now.ToFileTimeUtc(),
            (Get-UtcOffset),
            $this.GetHeadName(), $Name

        $msg >> $log_path
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

    $Repository.User  = $config.User
    $Repository.Email = $config.Email

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

$NULL_COMMIT = '0000000000000000000000000000000000000000'

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
         $NULL_COMMIT > (Join-Path $h.FullName master)
         New-Item (Join-Path $d.FullName remotes)    -ItemType Directory | Out-Null
         New-Item (Join-Path $d.FullName tags)       -ItemType Directory | Out-Null

    $d = New-Item (Join-Path $LiteralPath logs)      -ItemType Directory
         New-Item (Join-Path $d.FullName HEAD)       -ItemType File      | Out-Null
    $d = New-Item (Join-Path $d.FullName refs)       -ItemType Directory
            New-Item (Join-Path $d.FullName heads)   -ItemType Directory | Out-Null
            New-Item (Join-Path $d.FullName remotes) -ItemType Directory | Out-Null

    # Initialize the content addressable file system.
    New-Item $FileSystem.Init($fs_path)
    'ref: refs/heads/master' > $head_path
}

<#
.SYNOPSIS
    Constructs a commit object.

.DESCRIPTION
    Constructs the root tree for the commit and initiates the recursive construction
    of sub-trees.
#>
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
    $root.Summary = Get-Summary $root.Entries $FileSystem.ShaProvider

    # Recursively build subtrees
    $current = New-Object System.Collections.Stack
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

        [void]$root.Subtrees.Add( (Build-Tree $cache $Walked $current $FileSystem) )
    }

    $root.EntryCount = $root.Entries.Count
    $root.TreeCount  = $root.Subtrees.Count

    $data = ConvertTo-Json $root -Depth 100
    $oid  = $FileSystem.ShaProvider.HashString($data)
    if (!$FileSystem.Exists($oid))
    {
        [void]$FileSystem.WriteBlob( [System.Text.ASCIIEncoding]::UTF8.GetBytes($data) )
    }

    return $oid
}

<#
.SYNOPSIS
    Constructs a tree object.

.DESCRIPTION
    Recursively builds a tree and it's sub-trees to represent the file structure of
    the working directory that has been staged for this commit in the index.
    
    Saves completed tree objects to the content addressable file system as they are
    created.
#>
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
    $path_components = $current.ToArray()
    [Array]::Reverse($path_components)
    $tree.Entries = $walked[ ($path_components -join '\') ]
    $tree.Summary = Get-Summary $tree.Entries $FileSystem.ShaProvider

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

    $data = ConvertTo-Json $tree -Depth 100
    $oid  = $FileSystem.ShaProvider.HashString($data)
    if (!$FileSystem.Exists($oid))
    {
        [void]$FileSystem.WriteBlob( [System.Text.ASCIIEncoding]::UTF8.GetBytes($data) )
    }

    return $oid
}

<#
.SYNOPSIS
    Commit object constructor.

.DESCRIPTION
    Initializes a new commit data structure with default values.
#>
function New-Commit {
    $commit = @{
        # SHA1 identifier of the tree that represents the files of this commit.
        Tree      = [String]::Empty

        # SHA1 summary of all entry oid's that are written in this commit.
        #  Provides for quick index comparison against a commit.
        Summary   = [String]::Empty

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

<#
.SYNOPSIS
    Tree object constructor.

.DESCRIPTION
    Initializes a new tree data structure with default values.
#>
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

        # Summary SHA1 of the oids for the entries contained within this tree.
        Summary   = [String]::Empty

        # The list of entries contained by this tree.
        Entries = New-Object System.Collections.ArrayList

        # The list of subtree object id's contained by this tree.
        Subtrees = New-Object System.Collections.ArrayList
    }

    return $tree
}

<#
.SYNOPSIS
    Recursively retrieves the sub-tree of a tree.

.DESCRIPTION
    Used to recursively walk a nested tree structure to retrieve a sub-tree
    at the specified path.
#>
function Get-SubTree {
    param(
        [Parameter(Mandatory = $true)]
        [System.Collections.Stack]
            $Stack,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]
            $Tree,

        [Parameter(Mandatory = $true)]
        [PSCustomObject]
            $FileSystem
    )

    if ($Stack.Count -eq 0)
    {
        return $Tree
    }

    $current = $Stack.Pop()

    foreach ($oid in $Tree.Subtrees)
    {
        $subtree = ConvertFrom-Json (Get-Content $FileSystem.Get($oid) -Raw)
        if ($subtree.Path -eq $current)
        {
            return Get-SubTree -Stack $Stack -Tree $subtree -FileSystem $FileSystem
        }
    }

    return $null
}

<#
.SYNOPSIS
    Get the system's timezone UTC offset.

.DESCRIPTION
    Calculates the UTC offset of the system timezone so timestamps can be converted
    back into the local time of the author for a commit and logs.
#>
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
