class Resource {
    [object] $private:resource
    [System.Text.RegularExpressions.Regex] $private:pathdef

    Resource () {
        $this.InitParser()
    }

    Resource ([object]$data) {
        $this.InitParser()
        $this.data = $data
    }

    # Set the resource to the specified data structure
    [void] Load ([object]$source) {
        $this.resource = $source
    }

    [void] InitParser () {
        $pattern  = '(?<glob>@)\.?'            # Special Glob:      *     - Recurse entire structure starting at position... Path termination character
        $pattern += "|'(?<hkeyqt>[^']+)'\.?"   # Hashtable Key: 'keyname' - recursive call on value of literal key <keyname>... quoted string with special characters
        $pattern += '|(?<hkey>\w+)\.?'         # Hashtable Key:  keyname  - recursive call on value of literal key <keyname>.
        $pattern += '|(?<hkeys>/[^/]+/)\.?'    # Hashtable Key: /pattern/ - recursive call on keys that match regex <pattern>
        $pattern += '|(?<hval>\{\})\.?'        # Hashtable value
        $pattern += '|(?<lelem>\[\d?\])\.?'
        $pattern += '|(?<lend>\[\$\])\.?'
        $pattern += '|(?<lrange>\[\d-\d\])\.?'
        $pattern += '|(?<lall>\[\*\])\.?'
        $this.pathdef = New-Object System.Text.RegularExpressions.Regex(
            $pattern,
            [System.Text.RegularExpressions.RegexOptions]::Compiled)
    }

    [string[]] ParsePath ([string]$path) {
        [string[]] $patharray = @()
        $m = $this.pathdef.Match($path)
        while($m.Success){
            if(![string]::IsNullOrEmpty($m.Groups['glob'].Value)){
                $patharray += $m.Groups['glob'].Value
                return $patharray
            }
            elseif(![string]::IsNullOrEmpty($m.Groups['hkeyqt'].Value)){ # test for quoted strings before others for proper capture
                $patharray += $m.Groups['hkeyqt'].Value
            }
            elseif(![string]::IsNullOrEmpty($m.Groups['hkey'].Value)){
                $patharray += $m.Groups['hkey'].Value
            }
            elseif(![string]::IsNullOrEmpty($m.Groups['hkeys'].Value)){
                $patharray += $m.Groups['hkeys'].Value
            }
            elseif(![string]::IsNullOrEmpty($m.Groups['hval'].Value)){
                $patharray += $m.Groups['hval'].Value
            }
            elseif(![string]::IsNullOrEmpty($m.Groups['lelem'].Value)){
                $patharray += $m.Groups['lelem'].Value
            }
            elseif(![string]::IsNullOrEmpty($m.Groups['lend'].Value)){
                $patharray += $m.Groups['lend'].Value
            }
            elseif(![string]::IsNullOrEmpty($m.Groups['lrange'].Value)){
                $patharray += $m.Groups['lrange'].Value
            }
            elseif(![string]::IsNullOrEmpty($m.Groups['lall'].Value)){
                $patharray += $m.Groups['lall'].Value
            }
            $m = $m.NextMatch()
        }
        return $patharray
    }

    [Int32[]] ParseRange ([String]$range) {
        $match = [System.Text.RegularExpressions.Regex]::Match($range, '\[(?<a>\d+)-(?<b>-?\d+)\]|\[(?<i>\d+)\]')
        if(!$match.Success){
            throw (New-Object System.ArgumentException)
        }

        $a = $b = $i = $null

        if(![System.String]::IsNullOrEmpty( $match.Groups['a'].Value )){
            $a = [System.Convert]::ToInt32($match.Groups['a'].Value)
        }
        if(![System.String]::IsNullOrEmpty( $match.Groups['b'].Value )){
            $b = [System.Convert]::ToInt32($match.Groups['b'].Value)
        }
        if(![System.String]::IsNullOrEmpty( $match.Groups['i'].Value )){
            $i = [System.Convert]::ToInt32($match.Groups['i'].Value)
        }

        if($a -ne $null -and $b -ne $null){
            return $a, $b
        }
        return $i, $i
    }

    [string] PrintLocation ([string[]]$path) {
        [System.Array]::Reverse( $path )

        $depth = 0
        $sb = New-Object System.Text.StringBuilder
        foreach($s in $path){
            [void] $sb.AppendLine( ("`t" * $depth + $s) )
            $depth++
        }
        # Trim trailing windows newline sequence
        if($sb.Length -gt 2){
            $sb.Length -= 2
        }

        return $sb.ToString()
    }

    [void] PrintPaths ([string]$path) {
        $resolved = $this.ResolvePath($path)
        foreach($p in $resolved){
            $depth = 0
            foreach($s in $p){
                $color = [System.ConsoleColor]::Green
                if($depth -eq $p.Count -1){
                    $color = [System.ConsoleColor]::Magenta
                }
                Write-Host (("`t" * $depth) + $s) -ForegroundColor $color
                $depth++
            }
        }
    }

    [System.Collections.ArrayList] ResolvePath ([string]$path) {
        return $this.ResolvePath($this.ParsePath($path))
    }

    [System.Collections.ArrayList] ResolvePath ([string[]]$path) {
        $resolved = New-Object System.Collections.ArrayList
        $action = {
            param($data)
            $pop = $false
            if($location.Peek() -notmatch '\{[^}]+\}'){
                $location.Push("{$($data.GetType())}")
                $pop = $true
            }
            [System.Collections.ArrayList]$path = $location.ToArray()
            $path.Reverse()
            [void]$resolved.Add( $path )

            if($pop){
                [void]$location.Pop()
            }
        }
        $this.Traverse($this.resource, $path, 0, (New-Object System.Collections.Stack), (New-Object System.Collections.Stack), $action)
        return $resolved
    }

    [System.Collections.ArrayList] Retrieve ([string]$path) {
        return $this.Retrieve( $this.ParsePath($path) )
    }

    [System.Collections.ArrayList] Retrieve ([String[]]$path) {
        $retrieved = New-Object System.Collections.ArrayList
        $action = {
            param($data)
            $path = $location.ToArray()
            [System.Array]::Reverse( $path )
            [void]$retrieved.Add( [PSCustomObject]@{
                data = $data
                path = $path
            } )
        }
        $this.Traverse($this.resource, $path, 0, (New-Object System.Collections.Stack), (New-Object System.Collections.Stack), $action)
        return $retrieved
    }

    [void] Modify ([string]$path, [scriptblock]$callback) {
         $this.Modify( $this.ParsePath($path), $callback)
    }

    [void] Modify ([string[]]$path, [scriptblock]$callback) {
        $action = {
            param($data)
            & $callback $data
        }
        $this.Traverse($this.resource, $path, 0, (New-Object System.Collections.Stack), (New-Object System.Collections.Stack), $action)
    }

    [void] Traverse ([object]$data, [string[]]$path, [int]$loc, [System.Collections.Stack]$location, [System.Collections.Stack]$current, [scriptblock]$action) {
        $isLastItem = $false
        if($loc -eq $path.Length -1) {
            $isLastItem = $true
        }
        if($location.Count -eq 0){
            $location.Push('.') # Root of the data structure
        }

        $current.Push($data)

        if($path[$loc] -eq "{}"){
            $location.Push("{$($data.GetType())}")
            & $action $data
            [void]$location.Pop()

            [void]$location.Pop()
            [void]$current.Pop()
            return
        }

        # Recurse Hashtables
        if($data -is [Hashtable]){
            switch -regex ($path[$loc]){
                # Glob
                '^@$' {
                    $keylist = $data.Keys
                    foreach($key in $keylist){
                        # $loc index does not progress... keep on @ glob
                        $location.Push($key)
                        $this.Traverse($data.Item($key), $path, $loc, $location, $current, $action)
                    }
                    & $action $data
                    [void]$location.Pop()
                    [void]$current.Pop()
                    return
                }

                # Keyname regex
                '/[^/]+/' {
                    $pattern = $path[$loc].Substring(1, $path[$loc].Length -2)
                    $keylist = $data.Keys

                    # Perform action if end of path... send list of matching keys to action block
                    if($isLastItem){
                        foreach($entry in $data.GetEnumerator()){
                            if($entry.Key -match $pattern){
                                # Attach a reference to the parent hashtable for this entry
                                Add-Member -InputObject $entry -MemberType NoteProperty -Name Parent -Value $data
                                $location.Push($entry.Key)
                                & $action $entry
                                [void]$location.Pop()
                            }
                        }
                        [void]$location.Pop()
                        [void]$current.Pop()
                        return
                    }

                    # Recurse through each matching key
                    foreach($entry in $data.GetEnumerator()){
                        if($entry.Key -match $pattern){
                            $location.Push($entry.Key)
                            $this.Traverse($entry.Value, $path, ($loc +1), $location, $current, $action)
                        }
                    }

                    [void]$location.Pop()
                    [void]$current.Pop()
                    return
                }

                # Keyname literal
                default {
                    $keyname = $path[$loc]

                    # Perform action if end of path
                    if($isLastItem) {
                        if($data.ContainsKey($keyname)){
                            # Create the dictionary entry for this entry...
                            $entry = New-Object System.Collections.DictionaryEntry
                            $entry.Name = $keyname
                            $entry.Value = $data.Item($keyname)
                            # Attach a reference to the parent hashtable for this entry
                            Add-Member -InputObject $entry -MemberType NoteProperty -Name Parent -Value $data

                            $location.Push($keyname)
                            & $action $entry
                            [void]$location.Pop()
                        }

                        [void]$location.Pop()
                        [void]$current.Pop()
                        return
                    }
                    # Navigate hashtable key
                    if($data.ContainsKey($keyname)){
                        $location.Push($keyname)
                        $this.Traverse($data.Item($keyname), $path, ($loc +1), $location, $current, $action)

                        [void]$location.Pop()
                        [void]$current.Pop()
                        return
                    }

                    # key doesn't exist
                    Write-Error -Message ("Hashtable literal key [$Keyname] not found.`nPath: " + $this.PrintLocation( $location.ToArray() )) `
                                -Exception (New-Object System.InvalidOperationException) `
                                -Category InvalidArgument

                    [void]$location.Pop()
                    [void]$current.Pop()
                    return
                }
            }
        }
        # Recurse Lists
        elseif($data -is [System.Collections.ArrayList]){
            $expression = $path[$loc]
            switch -regex ($expression){
                # Glob
                '^@$' {
                    for($i = 0; $i -lt $data.Count; $i++){
                        # $loc index does not progress... keep on @ glob
                        $location.Push("[$i]")
                        $this.Traverse($data[$i], $path, $loc, $location, $current, $action)
                    }
                    & $action $data
                    [void]$location.Pop()
                    [void]$current.Pop()
                    return
                }

                # Process specified element
                '\[\d?\]' {
                    $element = 0
                    if($expression.Length -gt 2){
                        $subexpression = $expression.Substring(1, 1)
                        $element = [System.Convert]::ToInt32($subexpression)
                    }

                    if($element -ge $data.Count){
                        Write-Error -Message ("[$element] out of range.`nPath: " + $this.PrintLocation( $location.ToArray() )) `
                                    -Exception (New-Object System.IndexOutOfRangeException) `
                                    -Category InvalidArgument

                        [void]$location.Pop()
                        [void]$current.Pop()
                        return
                    }

                    if($isLastItem){
                        $range = $data.GetRange($element, 1)
                        $location.Push("[$element]")
                        & $action $range
                        [void]$location.Pop()

                        [void]$location.Pop() # Pop the current location
                        [void]$current.Pop()
                        return
                    }

                    $location.Push("[$element]")
                    $this.Traverse($data[$element], $path, ($loc +1), $location, $current, $action)

                    [void]$location.Pop()
                    [void]$current.Pop()
                    return
                }
                # Process last element only
                '\[\$\]' {
                    $location.Push("[$($data.Count -1)]")

                    if($isLastItem){
                        # pass a arraylist range of size 1 with last element
                        $range = $data.GetRange($data.Count -1, 1)
                        & $action $range

                        [void]$location.Pop()
                        [void]$current.Pop()
                        return
                    }
                    $this.Traverse($data[$data.Count -1], $path, ($loc +1), $location, $current, $action)

                    [void]$location.Pop()
                    [void]$current.Pop()
                    return
                }
                #All items from the array
                '\[\*\]' {
                    if($isLastItem){
                        $location.Push("[0-$($data.Count -1)]")
                        & $action $data

                        [void]$location.Pop()
                        [void]$current.Pop()
                        return
                    }
                    foreach($element in $data){
                        $location.Push("[$element]")
                        $this.Traverse($element, $path, ($loc +1), $location, $current, $action)
                    }

                    [void]$location.Pop()
                    [void]$current.Pop()
                    return
                }
                # Range of values
                '\[\d-\d\]' {
                    # Parse desired range from expression
                    $a, $b = $this.ParseRange($expression)

                    # Correct range for upper bound limit
                    if($b -ge $data.Count){
                        $b = $data.Count -1
                    }

                    if($isLastItem){
                        $location.Push("[$a-$b]")
                        $range = $data.GetRange($a, ($b - $a) +1)
                        & $action $range

                        [void]$location.Pop()
                        [void]$current.Pop()
                        return
                    }

                    for($i = $a; $i -le $b; $i++){
                        $location.Push("[$i]")
                        $this.Traverse($data[$i], $path, ($loc +1), $location, $current, $action)
                    }

                    [void]$location.Pop()
                    [void]$current.Pop()
                    return
                }
            }
        }
        # Scalar data node, object, or system.array
        else{
            & $action $data
        }

        [void]$location.Pop()
        [void]$current.Pop()
    }
}

# Factory Function
function New-Resource([object]$Data){
    if($Data){
        return [Resource]::New($Data)
    }
    return [Resource]::New()
}

Export-ModuleMember -Function *