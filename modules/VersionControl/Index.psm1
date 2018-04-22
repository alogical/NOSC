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
        idx       = $null
        PathCache = @{}
        OidCache  = @{}
        Path      = [String]::Empty
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
        ConvertTo-Json $this.idx > $this.Path
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Load -Value {
        param(
            # Index file path.
            [Parameter(Mandatory = $true)]
            [ValidateScript({[System.IO.File]::Exists($_)})]
            [String]
                $LiteralPath
        )

        $f = Get-Item $LiteralPath

        if (!$f) {
            throw (New-Object System.IO.FileNotFoundException("Could not locate index"))
        }

        $stream  = $f.OpenText()
        $content = $stream.ReadToEnd()
        $stream.Close()

        $this.idx = ConvertFrom-PSObject (ConvertFrom-Json $content)

        $this.RefreshCache()

        return $this.idx.HEAD
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name LoadCommit -Value {
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
        $OidCache  = $this.OidCache

        $PathCache.Clear()
        $OidCache.Clear()

        foreach ($entry in $this.idx.Entries)
        {
            $PathCache.Add($entry.Path, $entry)
            $OidCache.Add($entry.Name, $entry)
        }
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Add -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Index.ObjectType]::Entry})]
            [Hashtable]
                $InputObject
        )
        # Cache the object
        if (!$this.PathCache.Contains($InputObject.Path))
        {
            $this.PathCache.Add($InputObject.Path, $InputObject)
        }
        else
        {
            $this.UpdateEntry($this.PathCache[$InputObject.Path], $InputObject)
        }

        if (!$this.OidCache.Contains($InputObject.Name))
        {
            $this.OidCache.Add($InputObject.Name, $InputObject)
        }
        else
        {
            $this.UpdateEntry($this.PathCache[$InputObject.Path], $InputObject)
        }

        return $this.idx.Entries.Add($InputObject)
    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name UpdateEntry -Value {
        param(
            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Index.ObjectType]::Entry})]
            [Hashtable]
                $Previous,

            [Parameter(Mandatory = $true)]
            [ValidateScript({$_.Type -eq [VersionControl.Index.ObjectType]::Entry})]
            [Hashtable]
                $Current
        )

    }

    Add-Member -InputObject $Index -MemberType ScriptMethod -Name Remove -Value {
        param(
            [Parameter(Mandatory = $true,
                       ParameterSetName = 'Object')]
            [ValidateScript({$_.Type -eq [VersionControl.Index.ObjectType]::Entry})]
            [Hashtable]
                $InputObject,

            [Parameter(Mandatory = $true,
                       ParameterSetName = 'Index')]
            [Int]
                $Index
        )
        if ($InputObject)
        {
            [void]$this.idx.Entries.Remove($InputObject)
        }
        else
        {
            $InputObject = $this.idx.Entries[$Index]
            [void]$this.idx.Entries.RemoveAt($Index)
        }

        # Cache Management
        $this.PathCache.Remove($InputObject.Path)
    }

    Add-Member -InputObject $Index -MemberType ScriptProperty -Name Entries -Value {
        return $this.idx.Entries
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

function New-PrivateIndex {
    $idx = @{
        # Collection of entries representing tracked files in the working directory.
        Entries = New-Object System.Collections.ArrayList

        # Tree cache object.
        TREE    = @{}

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
        Type     = [VersionControl.Repository.Index.ObjectType]::TreeCache

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

function ConvertFrom-PSObject {
    param(
        [Parameter(Mandatory         = $false,
                   ValueFromPipeline = $true)]
        $InputObject = $null
    )

    process
    {
        if (!$InputObject) {
            return $null
        }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string]) {
            $collection = New-Object System.Collections.ArrayList
            $collection.AddRange(
                @( foreach ($object in $InputObject) { ConvertFrom-PSObject $object } )
            )
            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [psobject]) {
            $hash = @{}
            foreach ($property in $InputObject.PSObject.Properties) {
                $hash[$property.Name] = ConvertFrom-PSObject $property.Value
            }
            Write-Output -NoEnumerate $hash
        }
        else {
            Write-Output $InputObject
        }
    }
}