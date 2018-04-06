$LX_TERM                 = [UInt32]0x00000000
$LX_DATATYPE             = [UInt32]0x20000000
$LX_DATATYPE_NULL        = [UInt32]0x20000001
$LX_DATATYPE_VOID        = [UInt32]0x20000002
$LX_DATATYPE_INT         = [UInt32]0x20000004
$LX_DATATYPE_SHORT       = [UInt32]0x20000008
$LX_DATATYPE_LONG        = [UInt32]0x20000010
$LX_DATATYPE_DOUBLE      = [UInt32]0x20000020
$LX_DATATYPE_FLOAT       = [UInt32]0x20000040
$LX_DATATYPE_CHAR        = [UInt32]0x20000080
$LX_DATATYPE_SIGNED      = [UInt32]0x20000100
$LX_DATATYPE_UNSIGNED    = [UInt32]0x20000200
$LX_DATATYPE_CONST       = [UInt32]0x20000400
$LX_DATATYPE_VOLITILE    = [UInt32]0x20000800
$datatype = @(
    # Special data constant
    "null", "void",

    # Basic data types
    "int", "short", "long", "double", "float", "char",

    # Integer modifiers
    "signed", "unsigned",

    # Data access modifiers
    "const", "volitile"
)

# Storage classes
$LX_STORAGE              = [UInt32]0x40000000
$LX_STORAGE_AUTO         = [UInt32]0x40000001
$LX_STORAGE_DEFAULT      = [UInt32]0x40000002
$LX_STORAGE_REGISTER     = [UInt32]0x40000004
$LX_STORAGE_STATIC       = [UInt32]0x40000008
$LX_STORAGE_EXTERN       = [UInt32]0x40000010
$storage = @(
    "auto", "default", "register", "static", "extern"
)

$LX_FLOWCONTROL          = [UInt32]0x60000000
$LX_FLOWCONTROL_IF       = [UInt32]0x60000001
$LX_FLOWCONTROL_ELSE     = [UInt32]0x60000002
$LX_FLOWCONTROL_?        = [UInt32]0x60000004
$LX_FLOWCONTROL_SWITCH   = [UInt32]0x60000008
$LX_FLOWCONTROL_CASE     = [UInt32]0x60000010
$LX_FLOWCONTROL_FOR      = [UInt32]0x60000020
$LX_FLOWCONTROL_WHILE    = [UInt32]0x60000040
$LX_FLOWCONTROL_DO       = [UInt32]0x60000080
$LX_FLOWCONTROL_BREAK    = [UInt32]0x60000100
$LX_FLOWCONTROL_CONTINUE = [UInt32]0x60000200
$LX_FLOWCONTROL_GOTO     = [UInt32]0x60000400
$LX_FLOWCONTROL_RETURN   = [UInt32]0x60000800
$flowctrl = @(
    # Branching control statements
    "if", "else", "?", "switch", "case",

    # Looping control statements
    "for", "while", "do", "break", "continue", "goto",

    # Final control statement
    "return"
)

# Data definitions
$LX_DATADEF              = [UInt32]0x8 -shl 28 #0x80000000
$LX_DATADEF_STRUCT       = $KW_DATADEF + [UInt32]0x00000001
$LX_DATADEF_UNION        = $KW_DATADEF + [UInt32]0x00000002
$LX_DATADEF_ENUM         = $KW_DATADEF + [UInt32]0x00000004
$LX_DATADEF_TYPEDEF      = $KW_DATADEF + [UInt32]0x00000008
$datadef = @(
    "struct", "union", "enum", "typedef"
)

# Pre-processor directives
$LX_PREPROC              = [UInt32]0xA -shl 28 #0xA0000000
$LX_PREPROC_DEFINE       = $KW_PREPROC + [UInt32]0x00000001
$LX_PREPROC_IFDEF        = $KW_PREPROC + [UInt32]0x00000002
$LX_PREPROC_IFNDEF       = $KW_PREPROC + [UInt32]0x00000004
$LX_PREPROC_ELSE         = $KW_PREPROC + [UInt32]0x00000008
$LX_PREPROC_ENDIF        = $KW_PREPROC + [UInt32]0x00000010
[String[]]$preproc = @(
    "#define", "#ifdef", "#ifndef", "#else", "#endif"
)

$COMMENT_BLOCK_OPEN      = "/*"
$COMMENT_BLOCK_CLOSE     = "*/"

$CODE_BLOCK_OPEN         = "{"
$CODE_BLOCK_CLOSE        = "}"

$EXPR_BLOCK_OPEN         = "("
$EXPR_BLOCK_CLOSE        = ")"

$CHAR_ESCAPE             = "\"
$CHAR_LINEBREAK          = "/"

$regex = @{
    tokenChar    = New-Object System.Text.RegularExpressions.Regex(
                       "[0-9a-zA-Z_]",
                       [System.Text.RegularExpressions.RegexOptions]::Compiled
                   )
    openComment  = New-Object System.Text.RegularExpressions.Regex(
                        $COMMENT_BLOCK_OPEN,
                        [System.Text.RegularExpressions.RegexOptions]::Compiled
                   )
    closeComment = New-Object System.Text.RegularExpressions.Regex(
                        $COMMENT_BLOCK_OPEN,
                        [System.Text.RegularExpressions.RegexOptions]::Compiled
                   )
}

$__init = {
    param(
        # Char array of the word
        [Parameter(Mandatory = $true)]
            [Char[]]
            $c,

        [Parameter(Mandatory = $false)]
            [UInt32]
            $t = 0
    )

    $max = $c.Count - 1

    if ($this.depth -eq $max) {
        $this.type   = $t
        $this.isleaf = $true
        $this.char   = $c[$max]
        return
    }

    if (!$this.tree) {
        $this.tree = @{}
    }

    if (!$this.tree.ContainsKey($c[$this.depth])) {
        $this.tree.Add($c[$this.depth], $this.New($this.depth + 1))
    }

    $this.tree[$c[$this.depth]].Initialize($c, $t)
}
$__add = {
    param(
        # The string value of the keyword being mapped.
        [Parameter(Mandatory = $true)]
            [String[]]
            $value,

        [Parameter(Mandatory = $false)]
            [UInt32]
            $type = 0
    )
    $this.Initialize($value.ToCharArray(), $type)
}
$__add_range = {
    param(
        # The string value of the keyword being mapped.
        [Parameter(Mandatory = $true)]
            [String[]]
            $value,

        [Parameter(Mandatory = $false)]
            [UInt32]
            $type = 0
    )

    for ($i = 0; $i -lt $value.Count; $i++) {
        $this.Add($value[$i], $type)
    }
}
$__match = {
    param(
        [Parameter(Mandatory = $true)]
            [Char[]]
            $line,

        [Parameter(Mandatory = $true)]
            [Int]
            $index
    )

    $pos = $index + $this.depth
    $max = $line.Length - 1

    # Is this the final character in the token? Peek ahead.
    $fin = $pos -eq $max -or !$regex.tokenChar.IsMatch( $line[$pos + 1] )

    # End of the line
    if ($fin) {
        if ($this.isleaf -and $line[$pos] -eq $this.char) {
            return $true, ($this.depth + 1), $this.type
        }
        return $false, ($this.depth + 1), $null
    }

    if (!$this.tree -or !$this.tree.ContainsKey($line[$pos])) {
        return $false, ($this.depth + 1), $null
    }

    return $this.tree[$line[$pos]].Match($line, $index)
}
$__new = {
    param(
        [Parameter(Mandatory = $true)]
            [Int]
            $depth
    )

    $node = [PSCustomObject]@{
        # character tree
        tree   = $null

        # node depth
        depth  = $depth

        # intermediate endpoint (ex. 'if' is an endpoint, but the node may contain children for ifdef...)
        isleaf = $false

        # if this is a leaf, what is the terminating character for this word
        char   = $null

        # a caller defined type for the 'word' matched at the end of the character tree
        type   = [UInt32]0
    }
    Add-Member -InputObject $node -MemberType ScriptMethod -Name New        -Value $__new
    Add-Member -InputObject $node -MemberType ScriptMethod -Name Initialize -Value $__init
    Add-Member -InputObject $node -MemberType ScriptMethod -Name Add        -Value $__add
    Add-Member -InputObject $node -MemberType ScriptMethod -Name AddRange   -Value $__add_range
    Add-Member -InputObject $node -MemberType ScriptMethod -Name Match      -Value $__match

    return $node
}

$keywords = & $__new 0

# maximum number of keyword types is 28
#   otherwise you'll overwrite the category flag
&{
    for ($i = 0; $i -lt $datatype.Length; $i++) {
        $type = $LX_DATATYPE + [UInt32](1 -shl $i)
        $keywords.Add($datatype[$i], $type)
    }

    for ($i = 0; $i -lt $storage.Length; $i++) {
        $type = $LX_STORAGE + [UInt32](1 -shl $i)
        $keywords.Add($storage[$i], $type)
    }

    for ($i = 0; $i -lt $flowctrl.Length; $i++) {
        $type = $LX_FLOWCONTROL + [UInt32](1 -shl $i)
        $keywords.Add($flowctrl[$i], $type)
    }

    for ($i = 0; $i -lt $datadef.Length; $i++) {
        $type = $LX_DATADEF + [UInt32](1 -shl $i)
        $keywords.Add($datadef[$i], $type)
    }

    for ($i = 0; $i -lt $preproc.Length; $i++) {
        $type = $LX_PREPROC + [UInt32](1 -shl $i)
        $keywords.Add($preproc[$i], $type)
    }
}

