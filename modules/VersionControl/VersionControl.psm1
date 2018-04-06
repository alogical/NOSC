<#
.SYNOPSIS
    Customized Git version control system.

.DESCRIPTION
    Provides the version control functionality using a Git style content-addressable
    filesystem.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>

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

<#
.SYNOPSIS
    Turns a directory into a repository.

.DESCRIPTION

.NOTES

#>
function Initialize-Repository {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Scans the working directory for changes.

.DESCRIPTION
    Scans the working directory and determines which files have changed,
    added, or deleted based on the index metadata.

.NOTES
    Uses the .gitignore file to determine with files to exclude from the
    list of changed files

#>
function Scan-WorkingDirectory {
    throw (New-Object System.NotImplementedException)

    <#
     # Within 1 second of this sequence:
     #      echo old > file; Stage-File file
     # running this command:
     #      echo new > file
     # would give a falsely clean cache entry.  The mtime and
     # length match the cache, and other stat fields do not change.
     #
     # We could detect this at update-index time (the cache entry
     # being registered/updated records the same time as "now")
     # and delay the return from Stage-File, but that would
     # effectively mean we can make at most one commit per second,
     # which is not acceptable.  Instead, we check cache entries
     # whose mtime are the same as the index file timestamp more
     # carefully than others.
     #
     #
     # psuedo
     #
     #  $changed = Compare-StatData Cache-Entry Stat-Struct
     #  if ($changed) {
     #      Update-Entry Cache-Entry Stat-Struct
     #  }
     #>
}

###############################################################################
# User Commandline Utilities

<#
.SYNOPSIS
    Displays the contents of the Git index.

.DESCRIPTION

.NOTES
    Equivalent of:
        git ls-files --stage

#>
function Show-Index {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Displays the status of the Git index.

.DESCRIPTION

.NOTES
    Equivalent of:
        git status

#>
function Show-Status {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Turns an object into a SHA1 hash.

.DESCRIPTION
    Used to get the blob SHA1 hash of an input object.

.NOTES
    Does not modify the input, repository or index in any way.  Only used to see
    what the SHA1 of an object would be if it were to be turned into a blob.

.OUTPUT
    [String]
        20-character hexadicimal string representation of the SHA hash.

#>
function Get-Hash {
    param(
        [Parameter(Mandatory = $true)]
            [Object]
            $InputObject
    )

    switch ($InputObject.GetType()) {
        default {
            $SHACSP.OutString($InputObject)
        }
    }
}

###############################################################################
# User Index Operations

<#
.SYNOPSIS
    Stages (adds) a file to the index.

.DESCRIPTION
    Adds a file's metadata to the index, staging it for the next commit.

.NOTES

#>
function Stage-File {
    throw (New-Object System.NotImplementedException)
}

###############################################################################
# Local Branch Operations

<#
.SYNOPSIS
    Creates a temporary object store for non-committed changes.

.DESCRIPTION

.NOTES

#>
function New-Stash {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Creates a new branch of the repository.

.DESCRIPTION

.NOTES

#>
function New-Branch {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Changes from one repository branch to another.

.DESCRIPTION

.NOTES

#>
function Checkout-Branch {
    param(
        # Branch name to be checked out
        [Parameter(Mandatory = $true)]
            [String]
            $Name,

        # Create as new branch
        [Parameter(Mandatory = $false)]
            [Switch]
            $b
    )
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Stores the current contents of the index for a branch in a new commit.

.DESCRIPTION
    Stores the current contents of the index for a branch in a new commit along
    with a log message from the user describing the changes.

.NOTES
    Equivalent of:
        git commit -m "commit message"

    Updates:
        - Branch log
        - Branch HEAD
#>
function Commit-Branch {
    param(
        # Commit message
        [Parameter(Mandatory = $true)]
            [String]
            $m
    )
    throw (New-Object System.NotImplementedException)
}

###############################################################################
# Remote Branch Operations

<#
.SYNOPSIS
    Pulls changes from a remote branch.

.DESCRIPTION

.NOTES
    Uses Merge-Branch to merge changes from the remote branch into the current
    branch.

    Equivalent of:
        git pull

#>
function Pull-Branch {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Pushes changes to a remote branch.

.DESCRIPTION

.NOTES
    Uses Merge-Branch to merge changes from the local branch into the remote
    branch.

    Equivalent of:
        git push

#>
function Push-Branch {
    throw (New-Object System.NotImplementedException)
}

###############################################################################
# Encryption Operations

<#
.SYNOPSIS
    Encrypts a file.

.DESCRIPTION

.NOTES

#>
function Encrypt-File {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Decrypts a file.

.DESCRIPTION

.NOTES

#>
function Decrypt-File {
    throw (New-Object System.NotImplementedException)
}

###############################################################################
# Merge Operations

<#
.SYNOPSIS
    Combines the changes from one branch into another.

.DESCRIPTION
    Replays changes made on the topic branch to the current branch.

    WARNING: Running Merge-Branch with non-trivial uncommitted changes is
    discouraged: while possible, it may leave you in a state that is hard to
    back out of in case of a conflict.

.NOTES

.LINK
    See... Merge-Abort, Merge-Continue, Pull-Branch, Push-Branch
#>
function Merge-Branch {
    param(
        # The name of the branch to be merged into the current branch.
        [Parameter(Mandatory = $true)]
            [String]
            $Branch,

        # Perform a fast forward merge.
        [Parameter(Mandatory = $false)]
            [Switch]
            $NoFastForward
    )

    # Pre-merge checks
    <#  - Stop if local uncommitted changes overlap with files that the merge
     #    may need to update.
     #
     #  - To avoid recording unrelated changes in the merge commit, abort if
     #    there are any changes registered in the index relative to the HEAD
     #    commit.  Exception is when the changed index entries are in the state
     #    that would result from the merge already.
     #
     #  - If all named commits are alread ancestors of HEAD, exit early with the
     #    message "Already up to date."
     #>

    if ($NoFastForward) {
        Merge-Recursive $Branch
    }

    Merge-FastForward $Branch
}

<#
.SYNOPSIS
    Performs a three-way merge of a single file.

.DESCRIPTION
    Performs a three-way merge of a single file using a common ancestor of
    the two files being merged.  Used to complete a conflicted merge.

.NOTES
    Equivalent of:
        git merge-file name.ours.rb name.common.rb name.theirs.rb > name.rb

.LINK
    See... About Git Merge Conflicts, About Git Index Operations
#>
function Merge-File {
    param(
        [Parameter(Mandatory = $true)]
            [String]
            $Ours,

        [Parameter(Mandatory = $true)]
            [String]
            $Common,

        [Parameter(Mandatory = $true)]
            [String]
            $Theirs
    )
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Aborts the merge process.

.DESCRIPTION
    Attempts to reconstruct the pre-merge state of the index.

.NOTES
    Can only be run after a merge has resulted in conflicts.

    If there wre uncommitted changes when the merge started (and especially if
    those changes were futher modified after the merge was started), abort will
    in some cases be unable to reconstruct the original (pre-merge) changes.
#>
function Merge-Abort {

}

<#
.SYNOPSIS
    Continues the merge process after conflicts.

.DESCRIPTION
    Attempts to reconstruct the pre-merge state of the index.

.NOTES
    Can only be run after a merge has resulted in conflicts.
#>
function Merge-Continue {
    throw (New-Object System.NotImplementedException)
}

###############################################################################
# Basic Git Object Constructors

<#
.SYNOPSIS
    Creates a tree object to represent a directory.

.DESCRIPTION
    Converts the index staging area into a new tree object.

.NOTES

#>
function New-Tree {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Creates a binary blob object from the contents of a file.

.DESCRIPTION

.NOTES

#>
function New-Blob {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Creates a commit object.

.DESCRIPTION

.NOTES

#>
function New-Commit {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Creates a tag reference to a repository object.

.DESCRIPTION

.NOTES

#>
function New-Tag {
    throw (New-Object System.NotImplementedException)
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

###############################################################################
# Constants and Static Objects

# ctime lower limit: Start Date
$CTIME_FLOOR = [DateTime]"1/1/1970 00:00:00 GMT"

<#
.SYNOPSIS
    Static SHA hashing provider.

.DESCRIPTION
    The version control system relies heavily on creating SHA hashes of all objects
    within the repository.  The SHA provider is made static so that it doesn't have
    to be created and destroyed each time a function is called that needs to create
    a hash from an object.

.NOTES
    Must use a FIPS approved SHA crypto service provider for compliance with U.S.
    Government security policies.
#>
$SHACSP = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider

Add-Member -InputObject $SHACSP -MemberType ScriptMethod -Name ComputeFile -Value {
    param(
        [Parameter(Mandatory = $true)]
            [String]
            $Path
    )

    # Expand path to fully qualified path.
    $fqp = (Resolve-Path $Path).ProviderPath
    If (-Not ([uri]$fqp).IsAbsoluteUri)
    {
        throw (New-Object System.ArgumentException("File not found: $fqp"))
    }
    If(Test-Path $fqp -Type Container)
    {
        throw (New-Object System.ArgumentException( ("Cannot calculate hash for directory: {0}" -f $fqp) ))
    }

    #Open the File Stream.
    $stream = New-Object System.IO.FileStream($fqp, [System.IO.FileMode]::Open)
    $buffer = New-Object byte[] $stream.Length
    [void]$stream.Read($buffer, 0, $stream.Length)

    # Close Stream to free memory
    $stream.Close()

    return $this.ComputeHash( $buffer )
}

Add-Member -InputObject $SHACSP -MemberType ScriptMethod -Name OutString -Value {
    return -join ( $this.Hash | ForEach { "{0:x2}" -f $_ } )
}

###############################################################################
# Git <> .NET Data Structure Conversion

<#
.SYNOPSIS
    Converts System.DateTime to ctime format.

.DESCRIPTION
    Converts PowerShell .NET System.Time to ctime format used by Git.

.NOTES
    CTime values are based on coordinated universal time (UTC), which is
    equivalent to Coordinated Universal time (Greenwich Mean Time, GMT).

#>
function ConvertTo-CTime {
    param(
        [Parameter(Mandatory = $true)]
            [System.DateTime]
            $DateTime
    )
    $diff  = $DateTime - $CTIME_FLOOR
    return [UInt32]$diff.TotalSeconds
}

<#
.SYNOPSIS
    Converts ctime format to System.DateTime.

.DESCRIPTION
    Converts ctime used by Git into .NET System.DateTime used by PowerShell.

.NOTES
    CTime values are based on coordinated universal time (UTC), which is
    equivalent to Coordinated Universal time (Greenwich Mean Time, GMT).

#>
function ConvertFrom-CTime {
    param(
        # Four byte CTIME array.
        [Parameter(Mandatory = $true)]
            [UInt32]
            $CTime
    )
    return $CTIME_FLOOR.AddSeconds($CTime)
}

<#
.SYNOPSIS
    Converts UInt32 to Byte[] array.

.DESCRIPTION
    Converts UInt32 used by Git into a network order 4 byte array format.

.NOTES
    [UInt32]Ctime formatted numbers are stored in network byte order
    (Big-Endian) on the filesystem.

    NBA - Network Order Byte Array
#>
function ConvertTo-UInt32NBA {
    param(
        # Four byte CTIME array.
        [Parameter(Mandatory = $true)]
            [UInt32]
            $UInt32
    )
    $bytes = [BitConverter]::GetBytes($UInt32)
    if ([BitConverter]::IsLittleEndian) {
        [Array]::Reverse($bytes)
    }
    return $bytes
}

<#
.SYNOPSIS
    Converts Byte[] array to UInt32 format.

.DESCRIPTION
    Converts network order 4 byte array into a UInt32 used by Git.

.NOTES
    [UInt32]Ctime formatted numbers are stored in network byte order
    (Big-Endian) on the filesystem.

    NBA - Network Order Byte Array
#>
function ConvertFrom-UInt32NBA {
    param(
        # Four byte CTIME array.
        [Parameter(Mandatory = $true)]
            [Byte[]]
            $Bytes
    )
    if ([BitConverter]::IsLittleEndian) {
        [Array]::Reverse($Bytes)
    }
    return [BitConverter]::ToUInt32($Bytes)
}

###############################################################################
# Data & Object Comparers

<#
.SYNOPSIS
    Compare binary byte[] arrays for equivalence.

.DESCRIPTION
    Performs fast equavalence comparison for binary byte arrays.

.NOTES
    Used to compare SHA1 byte arrays.

.OUTPUT
    [Boolean]
#>
function Compare-ByteArray {
    param(
        # The SHA1 being compared against
        [Parameter(Mandatory = $true)]
            [byte[]]
            $Original,

        # The SHA1 to be compared against the reference SHA1
        [Parameter(Mandatory = $true)]
            [byte[]]
            $Reference
    )

    # Argument validation
    if ($Original.Length -ne $Reference.Length) {
        throw (New-Object System.ArgumentOutOfRangeException("Reference SHA1 array is not the same length as the Compare SHA1 array."))
    }

    for ($i = 0; $i -lt $Original.Length; $i++) {
        if ($Original[$i] -bxor $Reference[$i]) {
            return $false
        }
    }

    return $true
}

<#
.SYNOPSIS

.DESCRIPTION

.NOTES

.OUTPUT
    [Boolean]
#>
function Compare-StatData {
    param(
        # Index cache entry
        [Parameter(Mandatory = $true)]
            [PSCustomObject]
            $CacheEntry,

        # Filesystem file object
        [Parameter(Mandatory = $true)]
            [System.IO.FileInfo]
            $FileInfo
    )

    <#
     #  CacheEntry Stat Structure
     #
     #  [PSCustomObject]@{
     #
     #      # Created time
     #      CTime = {
     #          seconds = [UInt32]
     #          nanosec = [UInt32]
     #      }
     #
     #      # Modified time
     #      MTime = {
     #          seconds = [UInt32]
     #          nanosec = [UInt32]
     #      }
     #
     #      # Always 0
     #      Device = [UInt32]0
     #
     #      # Always 0
     #      Inode  = [UInt32]0
     #
     #      # File type & permissions
     #      Mode   = [UInt32]bit flags
     #
     #      # Always 0
     #      Uid    = [UInt32]0
     #
     #      # Always 0
     #      Gid    = [UInt32]0
     #
     #      # Size on disk
     #      Size   = [UInt32]byte count
     #
     #      # Object name
     #      SHA1   = [byte[]] 20
     #
     #      # Git flags
     #      Flags  = [UInt16]bit flags
     #  }
     #>

     [UInt32]$changed = 0

     if ($CacheEntry.Flags) {

     }
}

###############################################################################
# Git Index Extension Operations

<#
.SYNOPSIS
    Writes a TREE cache extension to the index.

.DESCRIPTION
    Processes the working directory into a TREE cache to speed up tree creation
    during a commit operation.

.NOTES
    See... About Git Index Format: Cached tree

#>
function Cache-TREE {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Writes a Resolve Undo (REUC) extension to the index.

.DESCRIPTION
    Caches merge conflict information within the index after a conflict has
    been updated using Stage-File.

.NOTES
    See... About Git Index Format: Resolve undo

#>
function Cache-REUC {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Reads a TREE cache extension from the index.

.DESCRIPTION
    Reads the serialized TREE extension cache data from the index.

.NOTES
    See... About Git Index Format: Cached tree

.OUPUT
    [PSCustomObject]
        Object representation of the TREE cache.
#>
function Read-TREE {
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Reads a Resolve Undo (REUC) extension from the index.

.DESCRIPTION
    Reads the serialized REUC extension cache data from the index.
.NOTES
    See... About Git Index Format: Resolve undo

.OUTPUT
    [PSCustomObject]
        Object representation of the REUC cache.
#>
function Read-REUC {
    throw (New-Object System.NotImplementedException)
}

###############################################################################
# Git Merge Strategies

<#
.SYNOPSIS
    Replays changes from topic branch recursively.

.DESCRIPTION
    Replays all changes from the topic branch onto the current branch
    recursively.  Creates a merge commit.

.NOTES
    Equivalent of:
        git merge topic --no-ff
#>
function Merge-Recursive {
    param(
        [Parameter(Mandatory = $true)]
            [String]
            $Branch
    )
    throw (New-Object System.NotImplementedException)
}

<#
.SYNOPSIS
    Fast forwards the current branch to the topic branch.

.DESCRIPTION
    Merges the changes from the topic branch to the current branch by updating
    the branch pointer.  This does not create a merge commit.

.NOTES
    Commit history of the topic branch will be lost when performing a fast
    forward merge.

    Can only be performed when the HEAD of the current branch is an ancestor of
    the topic branch HEAD.

    Equivalent of:
        git merge topic
#>
function Merge-FastForward {
    param(
        [Parameter(Mandatory = $true)]
            [String]
            $Branch
    )
    throw (New-Object System.NotImplementedException)
}

###############################################################################
# About Git Index Format
<#

https://github.com/git/git/blob/867b1c1bf68363bcfd17667d6d4b9031fa6a1300/Documentation/technical/index-format.txt#L38
https://msdn.microsoft.com/en-us/magazine/mt493250.aspx?f=255&MSPPError=-2147217396

== The Git index file has the following format

  All binary numbers are in network byte order. Version 2 is described
  here unless stated otherwise.

   - A 12-byte header consisting of

     4-byte signature:
       The signature is { 'D', 'I', 'R', 'C' } (stands for "dircache")
       Hex bytes: [63][65][73][2F]

     4-byte version number:
       The current supported versions are 2, 3 and 4.

     32-bit number of index entries.

   - A number of sorted index entries (see below).

   - Extensions

     Extensions are identified by signature. Optional extensions can
     be ignored if Git does not understand them.

     Git currently supports cached tree and resolve undo extensions.

     4-byte extension signature. If the first byte is 'A'..'Z' the
     extension is optional and can be ignored.

     32-bit size of the extension in bytes

     Extension data

   - 160-bit SHA-1 over the content of the index file before this
     checksum.

== Index entry

  Index entries are sorted in ascending order on the name field,
  interpreted as a string of unsigned bytes (i.e. memcmp() order, no
  localization, no special casing of directory separator '/'). Entries
  with the same name are sorted by their stage field.

  Index entries are tracked files (staged for commit).  There are two
  types of untracked files: files that are in the working directory but
  haven't been added to the index (unstaged), and files that are explicitly
  designated as not to be tracked (see index extensions section).

  Time data is stored as c library (ctime) format.  The ctime format is
  not the same as the ctime index entry field, which is the filesystem
  time metadata of when the file was created.

  stat(2) data is metadata that would be returned by the Unix system stat()
  call.  In particular, this information includes file permissions, timestamps,
  file size, user/group owners, and inode.  The only values used under Micrsoft
  Windows is the ctime, mtime, mode, and file size.

  32-bit ctime seconds
    time the file was created
    this is stat(2) data

  32-bit ctime nanosecond fractions
    this is stat(2) data

  32-bit mtime seconds
    time a file's data was last changed (modified)
    this is stat(2) data

  32-bit mtime nanosecond fractions
    this is stat(2) data

  32-bit dev, always 0 in Microsoft Windows
    (device) originates from Unix file attributes
    this is stat(2) data

  32-bit ino, always 0 in Microsoft Windows
    (inode) originates from Unix file attributes
    this is stat(2) data

  32-bit mode, split into (high to low bits)
    (mode) originates from Unix file attributes
    this is stat(2) data

    4-bit object type
      valid values in binary are 1000 (regular file), 1010 (symbolic link)
      and 1110 (gitlink)

    3-bit unused

    9-bit unix permission. Only 0755 and 0644 are valid for regular files.
      Symbolic links and gitlinks have value 0 in this field.

    - Bit representation:

      Top 16 bits (Unused)

      Bottom 16 Bits
                             permissions (user, group, other)
                            /
          object type      read
         /                / write
        /        unused  / / execute
       /        /       / / /
      [][][][].[][][]~([][][].[][][].[][][])
                       / / /  / / /  / / /
         bit values:  4 2 1  4 2 1  4 2 1

    Most commonly in windows (regular file | 644 permissions). Git for
    Windows uses the below mode for both non-executable and executable files.

    Hex bytes: [00][00][81]A4]

       regular file            usr (rw)  grp (r)   other (r)
      /                       /         /         /
    [1][0][0][0].[0][0][0]~([1][1][0].[1][0][0].[1][0][0])

  32-bit uid, always 0 in Microsoft Windows
    Unix filesystem user id
    this is stat(2) data

  32-bit gid, always 0 in Microsoft Windows
    Unix filesystem group id
    this is stat(2) data

  32-bit file size in bytes
    This is the on-disk size from stat(2), truncated to 32-bit.

  160-bit SHA-1 for the represented object

  A 16-bit 'flags' field split into (high to low bits)
    Low bits:

    1-bit assume-valid flag

    1-bit extended flag (must be zero in version 2)

    2-bit stage (during merge) 1-3 if merge conflict object; otherwise 0

    12-bit name length if the length is less than 0xFFF; otherwise 0xFFF
    is stored in this field.

    - Bit representation:

              assume valid
             /
            /  extended (must be zero in version 2)
           /  /
          /  /  stage (0, 1, 2, or 3).  See about merge conflict.
         /  /  /
        /  /  /     length of path\file (max 4096 {0xFFF})
       /  /  /     /
      []~[]~[][].([][][][].[][][][].[][][][])

  (Version 3 or later) A 16-bit field, only applicable if the
  "extended flag" above is 1, split into (high to low bits).

  - Bit representation:

    1-bit reserved for future

    1-bit skip-worktree flag (used by sparse checkout)

    1-bit intent-to-add flag (used by "git add -N")

    13-bit unused, must be zero

    - Bit representation:

              reserved
             /
            /  skip-worktree flag (used by sparse checkout)
           /  /
          /  /  intent-to-add flag (used by "git add -N")
         /  /  /
        /  /  /   unused, must be zero (null)
       /  /  /   /
      []~[]~[]~([].[][][][].[][][][].[][][][])

  Entry path name (variable length) relative to top level directory
    (without leading slash). '/' is used as path separator. The special
    path components ".", ".." and ".git" (without quotes) are disallowed.
    Trailing slash is also disallowed.

    The exact encoding is undefined, but the '.' and '/' characters
    are encoded in 7-bit ASCII and the encoding cannot contain a NUL
    byte (iow, this is a UNIX pathname).

  (Version 4) In version 4, the entry path name is prefix-compressed
    relative to the path name for the previous entry (the very first
    entry is encoded as if the path name for the previous entry is an
    empty string).  At the beginning of an entry, an integer N in the
    variable width encoding (the same encoding as the offset is encoded
    for OFS_DELTA pack entries; see pack-format.txt) is stored, followed
    by a NUL-terminated string S.  Removing N bytes from the end of the
    path name for the previous entry, and replacing it with the string S
    yields the path name for this entry.

  1-8 nul bytes as necessary to pad the entry to a multiple of eight bytes
  while keeping the name NUL-terminated.

  - v2 Byte representation:

     /0 - ASCII (0x00) Null

     Header (62-bytes)
      ( 8-byte ctime, 8-byte mtime, 4-byte dev, 4-byte ino,  4-byte mode, |
      | 4-byte uid,   4-byte gid,   4-byte len, 20-byte SHA, 2-byte flag  )

     Length of path/file (18-bytes)          null termination
                                            /
                   7-bit ASCII encoded     /   padding........
                  /                       /   /               \
    [p][a][t][h][/][e][x][a][m][p][l][e][/0][/0][/0][/0][/0][/0]
     1  2  3  4  5  6  7  8  9 10 11 12  13  14  15  16  17  18

     Illegal example; 62-byte header + 20-byte path = 82-bytes.
       Must be divisible by 8; should be padded to 88-bytes.

           cannot start with "/" or "."
          /
         /  ".." cannot use backwards directory traversal
        /  /
       /  /        may not contain ".git"              cannot end with "/"
      /  / \      /       \                           /
    [/][.][.][/][.][g][i][t][/][i][l][l][e][g][a][l][/][/0][/0]
     1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 18  19  20

  (Version 4) In version 4, the padding after the pathname does not
  exist.

== Extensions

=== Cached tree

  Cached tree extension contains pre-computed hashes for trees that can
  be derived from the index. It helps speed up tree object generation
  from index for a new commit.

  When a path is updated in index, the path must be invalidated and
  removed from tree cache.

  32-bit ASCII signature
    The signature for this extension is { 'T', 'R', 'E', 'E' }.
    Hex bytes: [54][52][45][45]

  32-bit length in bytes of the extension data

  A series of entries fill the entire extension; each of which
  consists of:

    - Variable length path component
      NUL-terminated (relative to its parent directory);

    - Variable length count of entries
      ASCII decimal number of entries in the index that is covered by the
      tree this entry represents (entry_count); (file blobs)

    - 1-byte separator (0x20)
      A space (ASCII 32);

    - Variable length count of subtrees
      ASCII decimal number that represents the number of subtrees this
      tree has; (directories)

    - 1-byte terminator (0xA)
      A newline (ASCII 10); and

    - 160-bit object name for the object that would result from writing
      this span of index as a tree.

    - Byte representation:

      /0 - ASCII (0x00) Null
      LF - ASCII (0x0A) Line Feed

                   Relative path to parent; variable length
                  /
                 /           Path null terminator
                /           /
               /           /  entry_count (ASCII); variable length
              /           /  /
             /           /  /      Space (ASCII 0x20)
            /           /  /      /
           /           /  /      /  subtree_count (ASCII); variable length
          /           /  /      /  /
         /           /  /\     /  /  Linefeed terminator (ASCII 0x0A)
        /           /  /  \   /  /  /
      [p][a][t][h][/0][1][2][ ][2][LF]([][][][]...x5 SHA1)

  An entry can be in an invalidated state and is represented by having
  a negative number in the entry_count field. In this case, there is no
  object name (SHA1) and the next entry starts immediately after the linefeed.
  When writing an invalid entry, -1 (Hex: [2D][31]) should always be used as
  entry_count.

  The entries are written out in the top-down, depth-first order.  The
  first entry represents the root level of the repository, followed by the
  first subtree---let's call this A---of the root level (with its name
  relative to the root level), followed by the first subtree of A (with
  its name relative to A), ...

  - Byte representation:

    /0 - ASCII (0x00) Null
    LF - ASCII (0x0A) Line Feed

    Header        length 129 bytes (0x81)
    [T][R][E][E]  [00][00][00][81]

    (r) Root (25-bytes); 0 length path - null terminator only
    [/0] [2][ ][2][LF] [SHA[20-bytes]]

    (c1) First child of root (27-bytes)
    [c][1][/0] [2][ ][2][LF] [SHA[20-bytes]]

    (c11) First child of c1 (28-butes)
    [c][1][1][/0]...

    (c12) Second child of c1 (28-bytes)
    [c][1][2][/0]...

    (c2) Second child of root (8-bytes); invalidated
    [c][2][/0] [-][1][ ][0][LF] //NO SHA//

=== Resolve undo

  A conflict is represented in the index as a set of higher stage entries.
  When a conflict is resolved (e.g. with "git add path"), these higher
  stage entries will be removed and a stage-0 entry with proper resolution
  is added.

  When these higher stage entries are removed, they are saved in the
  resolve undo extension, so that conflicts can be recreated (e.g. with
  "git checkout -m"), in case users want to redo a conflict resolution
  from scratch.

  32-bit ASCII signature
    The signature for this extension is { 'R', 'E', 'U', 'C' }.
    Hex bytes: [52][45[55][43]

  32-bit length in bytes of the extension data

  A series of entries fill the entire extension; each of which
  consists of:

   - NUL-terminated pathname the entry describes (relative to the root of
     the repository, i.e. full pathname);

   - Three NUL-terminated ASCII octal numbers, entry mode of entries in
     stage 1 to 3 (a missing stage is represented by "0" in this field);

     - Stage 1: The common ancestor version (common)

     - Stage 2: HEAD; merge target branch version (ours)

     - Stage 3: MERGE_HEAD; merge source branch version (theirs)

   - At most three 160-bit object names (SHA-1) of the entry in stages from
     1 to 3 (nothing is written for a missing stage).

   - Byte representation:

     /0 - ASCII (0x00) Null

      Header       length 182 bytes (0xB6)
     [R][E][U][C]  [00][00][00][B6]

     First Entry: All stages.

           Undefined encoding (ASCII, UTF8)
          /-- - no multi-byte encodings containing NULLs (e.g. UTF16..32)
         /
        /           ASCII (0x2F) '/' path separator      null terminated
       /           /                                                    \
     [f][u][l][l][/][p][a][t][h][/][c][o][n][f][l][i][c][t][.][t][x][t][/0]
      1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21 22  23

        No missing stages (81-bytes)

      Stage 1 mode.......    Stage 2 mode......    Stage 3 mode......
     /                   \  /                  \  /                  \
     [1][0][0][6][4][4][/0][1][0][0][6][4][4][/0][1][0][0][6][4][4][/0]
      1  2  3  4  5  6  7   8  9 10 11 12 13  14 15 16 17 18 19 20  21

     [20-Byte Stage 1 SHA ][20-Byte Stage 2 SHA ][20-Byte Stage 3 SHA ]

     Second Entry: No ancestor, object was introduced into the merge branches
       after they diverged from this branch.

          Undefined encoding (ASCII, Utf8, Utf16, etc...)
         /
        /           ASCII (0x2F) '/' path separator      null terminated
       /           /                                                   /
     [f][u][l][l][/][p][a][t][h][/][a][d][o][p][t][e][d][.][t][x][t][/0]
      1  2  3  4  5  6  7  8  9 10 11 12 13 14 15 16 17 18 19 20 21  22

        One missing stage - stage 1 ancestor - (56-bytes)

      Missing  Stage 2 mode.....    Stage 3 mode......
     /      / /                 \  /                  \
     [0][/0][1][0][0][6][4][4][/0][1][0][0][6][4][4][/0]
      1   2  3  4  5  6  7  8   9 10 11 12 13 14 15  16

            [20-Byte Stage 2 SHA ][20-Byte Stage 3 SHA ]

=== Untracked


#>

###############################################################################
# About Git Index Operations
<#

    W |                                |                               |
    O |        [Stage (Add)]-->        |             [Commit]-->       | O
    R |                                                                | B
    K |                                I                               | J
    I |                                N               <--[Merge]      | E
    N |                                D                               | C
    G |        <--[Clone]              E          <--[Clone]           | T
      |                                X                               |
    T |        <--[Pull ]                         <--[Pull ]           | D
    R |                                |                               | A
    E |  <--[Switch Branch (Checkout)] | <--[Switch Branch (Checkout)] | G
    E |                                |                               |

== Stage (Add)
#>

###############################################################################
# About Git Merge Conflicts
<#

#>