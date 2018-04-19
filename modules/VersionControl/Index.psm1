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

$Index = [PSCustomObject]@{
    idx  = $null
    Path = [String]::Empty
}

Add-Member -InputObject $Index -MemberType ScriptMethod -Name Load -Value {
    param(
        # Index file path.
        [Parameter(Mandatory = $true)]
        [ValidateScript({[System.IO.Directory]::Exists($_)})]
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

    return $this.idx.HEAD
}

Add-Member -InputObject $Index -MemberType ScriptMethod -Name Checkout -Value {
    param(
        # A commit tree.
        [Parameter(Mandatory = $true)]
        [Object]
            $Commit
    )

    $this.idx = New-Index
    $this.idx.Cache   = ConvertTo-CacheTree $Commit.Tree
    $this.idx.Entries = Build-Cache $Commit.Tree $this.idx.Cache
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

function New-Index {
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