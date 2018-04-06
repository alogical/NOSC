# Load Class Module Hack
#$using = "using module $HOME\Documents\WindowsPowerShell\Modules\ISEAddOns\SolutionExplorer\lib\index\resource.psm1"
#$load = [ScriptBlock]::Create($using); & $load
#using module C:\Users\Danny\Documents\WindowsPowerShell\Modules\ISEAddOns\SolutionExplorer\lib\index\resource.psm1

Import-Module ISEAddOns\SolutionExplorer\lib\index\resource.psm1

$res = New-Resource
$res.Load( (Import-Clixml C:\Users\Danny\Documents\WindowsPowerShell\Modules\ISEAddOns\SolutionExplorer\indexes\exp_8a7f13b6f5eb55da9172115526371b23ca2e2f4f) )

#// Resource Private Variable Hiding //
if($false){
    #------------------------------------------------------------------------------
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// Private Variables :: Are Not So Private " + "/" * (80 - "// Private Variables :: Are Not So Private ".Length)) -ForegroundColor Cyan
    $res.resource
    $res.pathdef
}

#// Hashtable Key Navigation Tests //
if($true){
    #------------------------------------------------------------------------------
    ## check literal path expression
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// PrintPaths('Functions') " + "/" * (80 - "// PrintPath('Functions') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Functions')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Functions')
    #endregion

    #------------------------------------------------------------------------------
    ## check greedy path expression
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// PrintPaths('/.*/./.*/') " + "/" * (80 - "// PrintPaths('/.*/./.*/') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('/.*/./.*/')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('/.*/./.*/')
    #endregion

    #------------------------------------------------------------------------------
    ## Check path expression; return value
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// PrintPaths('Functions./.*/{}') " + "/" * (80 - "// PrintPaths('Functions./.*/{}') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Functions./.*/{}')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Functions./.*/{}')
    #endregion

    #------------------------------------------------------------------------------
    ## Check return value after path expression
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// PrintPaths('Functions./.*/./.*Solution.*/{}') " + "/" * (80 - "// PrintPaths('Functions./.*/./.*Solution.*/{}') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Functions./.*/./.*Solution.*/{}')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Functions./.*/./.*Solution.*/{}')
    #endregion

    #------------------------------------------------------------------------------
    ## Check greedy path expression with downline filter expression; select first list element
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// PrintPaths('Functions./.*/./.*Solution.*/[]') " + "/" * (80 - "// PrintPaths('Functions./.*/./.*Solution.*/[]') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Functions./.*/./.*Solution.*/[]')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Functions./.*/./.*Solution.*/[]')
    #endregion

    #------------------------------------------------------------------------------
    ## Test invalid path expression
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Red
    Write-Host ("// INVALID PrintPaths('Files./.*/./.*Solution.*/[*]') " + "/" * (80 - "// INVALID PrintPaths('Files./.*/./.*Solution.*/[*]') ".Length )) -ForegroundColor Red
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Files./.*/./.*Solution.*/[*]')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Files./.*/./.*Solution.*/[*]')
    #endregion

    #------------------------------------------------------------------------------
    ## Test invalid path literal
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Red
    Write-Host ("// INVALID PrintPaths('Functions./.*/.OtherFiles[*]') " + "/" * (80 - "// INVALID PrintPaths('Functions./.*/.OtherFiles[*]') ".Length )) -ForegroundColor Red
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Files./.*/.OtherFiles[*]')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Files./.*/.OtherFiles[*]')
    #endregion

    #------------------------------------------------------------------------------
    ## Test mixed path expressions with ending list expression
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// PrintPaths('Files./.*File.*/.Functions./\w-OtherFiles/[*]') " + "/" * (80 - "// PrintPaths('Files./.*File.*/.Functions./\w-OtherFiles/[*]') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Files./.*File.*/.Functions./\w-OtherFiles/[*]')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Files./.*File.*/.Functions./\w-OtherFiles/[*]')
    #endregion

    #------------------------------------------------------------------------------
    ## Test mixed path expressions
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// PrintPaths('Files./.*File.*/.Functions./\w-OtherFiles/{}') " + "/" * (80 - "// PrintPaths('Files./.*File.*/.Functions./\w-OtherFiles/{}') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Files./.*File.*/.Functions./\w-OtherFiles/{}')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Files./.*File.*/.Functions./\w-OtherFiles/{}')
    #endregion

    #------------------------------------------------------------------------------
    ## Test glob splatting at end of path to recurse through the remainder.
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// PrintPaths('Files./.*File.*/.Functions.@') " + "/" * (80 - "// PrintPaths('Files./.*File.*/.Functions.@') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Files./.*File.*/.Functions.@')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Files./.*File.*/.Functions.@')
    #endregion

    #------------------------------------------------------------------------------
    ## check quoted string literal path expression
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// PrintPaths('Files.'quoted string'.Functions.@') " + "/" * (80 - "// PrintPaths('Files.'quoted string'.Functions.@') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files.'C:\Users\1272976216A\Documents\WindowsPowerShell\ISE.AddOns\ISE.EditorExtensions\ISE.FilesManagement.psm1'.Functions.@")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    ''
    $res.PrintPaths('Files./.*File.*/.Functions.@')
    #endregion

    Remove-Variable tab, p
}

#// Resource Data Retrieval Tests //
if($false){
    #------------------------------------------------------------------------------
    ## Test glob splatting at end of path to recurse retrieve structure data
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// Retrieve('Files./.*File.*/.Functions.@') " + "/" * (80 - "// Retrieve('Files./.*File.*/.Functions.@') ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Files./.*File.*/.Functions.@')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    $data = $res.Retrieve('Files./.*File.*/.Functions.@')
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "Path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test selecting list range
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[0-1]`") " + "/" * (80 - "// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[0-1]`") ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions.'Save-AllFiles'.[0-1]")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[0-1]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "Path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test selecting multiple list range
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// Retrieve(`"Files./.*File.*/.Functions./.*/.[0-1]`") " + "/" * (80 - "// Retrieve(`"Files./.*File.*/.Functions./.*/.[0-1]`") ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions./.*/.[0-1]")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    $data = $res.Retrieve("Files./.*File.*/.Functions./.*/.[0-1]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "Path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test selecting list range overflow
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[1-2]`") " + "/" * (80 - "// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[1-2]`") ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions.'Save-AllFiles'.[1-2]")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[1-2]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "Path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test selecting list element
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[1]`") " + "/" * (80 - "// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[1]`") ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions.'Save-AllFiles'.[1]")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[1]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "Path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test selecting list glob
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[*]`") " + "/" * (80 - "// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[*]`") ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions.'Save-AllFiles'.[*]")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[*]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "Path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test selecting list last element
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ("// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[$]`") " + "/" * (80 - "// Retrieve(`"Files./.*File.*/.Functions.'Save-AllFiles'.[$]`") ".Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions.'Save-AllFiles'.[$]")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[$]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "Path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test selecting hashtable
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ('// Retrieve(Files./.*File.*/.Functions.{}) ' + "/" * (80 - '// Retrieve(Files./.*File.*/.Functions.{}) '.Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Files./.*File.*/.Functions.{}')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    $data = $res.Retrieve('Files./.*File.*/.Functions.{}')
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan; $obj.data
        Write-Host "Path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test selecting multiple hashtable
    #region
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    Write-Host ('// Retrieve(Files./.*Editing.*|.*Extensions\.psm1/{}) ' + "/" * (80 - '// Retrieve(Files./.*Editing.*|.*Extensions\.psm1/{}) '.Length )) -ForegroundColor Cyan
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath('Files./.*Editing.*|.*Extensions\.psm1/{}')){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    $data = $res.Retrieve('Files./.*Editing.*|.*Extensions\.psm1/{}')
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan; $obj.data
        Write-Host "Path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    Remove-Variable obj, data
    Remove-Variable tab, p
}

 # NOTE: Hashtable Limitations
<#
 # You cannot modify the data within the hashtable using the DictionaryEntry objects provided by a
 # hashtable's enumerator.  The enumerator returned by hash.GetEnumerator() creates a copy of the
 # DictionaryEntry objects as it iterates through the hashtable elements and so no changes to the
 # keyname or valuetype data of an entry will be reflected within the parent hashtable.  If the
 # entry's value is a reference to another object, than that object can be manipulated, but you
 # cannot delete the reference in the hashtable to that object using the entry returned by the
 # enumerator.
#>

#// Modify Data Tests //
if($false){
    #------------------------------------------------------------------------------
    ## Test modifying list range last element
    #region
    $transformlist = {
        param($data)

        # Change last element value to 10
        $data[$data.count-1] = 10
    }
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    $msg = "// Modify(`"Files./.*File.*/.Functions.'Save-AllFiles'.[0-1]`", `$transformlist) "
    $tail = 80 - $msg.Length
    if($tail -lt 0){
        $tail = 0
    }
    Write-Host ($msg + "/" * $tail) -ForegroundColor Cyan
    Write-Host $transformlist -ForegroundColor Magenta
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions.'Save-AllFiles'.[0-1]")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    # Print data before modification
    Write-Host "Pre-Op Data:" -ForegroundColor Cyan
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[0-1]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }

    $res.Modify("Files./.*File.*/.Functions.'Save-AllFiles'.[0-1]", $transformlist)

    # Verify the modification
    ''
    ''
    Write-Host "Post-Op Data:" -ForegroundColor Cyan
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[0-1]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test modifying list range last element
    #region
    $transformlist = {
        param($data)

        # Change value to 10
        $data[0] = 20
    }
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    $msg = "// Modify(`"Files./.*File.*/.Functions.'Save-AllFiles'.[0]`", `$transformlist, `$true) "
    $tail = 80 - $msg.Length
    if($tail -lt 0){
        $tail = 0
    }
    Write-Host ($msg + "/" * $tail) -ForegroundColor Cyan
    Write-Host $transformlist -ForegroundColor Magenta
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions.'Save-AllFiles'.[0]")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    # Print data before modification
    Write-Host "Pre-Op Data:" -ForegroundColor Cyan
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[*]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }

    $res.Modify("Files./.*File.*/.Functions.'Save-AllFiles'.[0]", $transformlist)

    # Verify the modification
    ''
    ''
    Write-Host "Post-Op Data:" -ForegroundColor Cyan
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[*]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test modifying list range last element
    #region
    $transformlist = {
        param($data)

        # Change value to 10
        $data.Sort()
    }
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    $msg = "// Modify(`"Files./.*File.*/.Functions.'Save-AllFiles'.[*]`", `$transformlist) "
    $tail = 80 - $msg.Length
    if($tail -lt 0){
        $tail = 0
    }
    Write-Host ($msg + "/" * $tail) -ForegroundColor Cyan
    Write-Host $transformlist -ForegroundColor Magenta
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions.'Save-AllFiles'.[*]")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    # Print data before modification
    Write-Host "Pre-Op Data:" -ForegroundColor Cyan
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[*]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }

    $res.Modify("Files./.*File.*/.Functions.'Save-AllFiles'.[*]", $transformlist)

    # Verify the modification
    ''
    ''
    Write-Host "Post-Op Data:" -ForegroundColor Cyan
    $data = $res.Retrieve("Files./.*File.*/.Functions.'Save-AllFiles'.[*]")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    #------------------------------------------------------------------------------
    ## Test modifying hashtable entries
    #region
    $transformlist = {
        param($data)

        $data.Parent.Remove($data.Key)
        $data.Parent.Add('modifiedkey', $data.Value)
    }
    ''
    Write-Host ("/" * 80) -ForegroundColor Cyan
    $msg = "// Modify(`"Files./.*File.*/.Functions.'Save-AllFiles'`", `$transformlist) "
    $tail = 80 - $msg.Length
    if($tail -lt 0){
        $tail = 0
    }
    Write-Host ($msg + "/" * $tail) -ForegroundColor Cyan
    Write-Host $transformlist -ForegroundColor Magenta
    $tab = 0
    Write-Host "Parsing Path" -ForegroundColor Cyan
    foreach($p in $res.ParsePath("Files./.*File.*/.Functions.'Save-AllFiles'")){
        Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
        $tab++
    }
    ''
    Write-Host "Pre-Op Data:" -ForegroundColor Cyan
    $data = $res.Retrieve("Files./.*File.*/.Functions./.*/")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }

    ''
    $res.Modify("Files./.*File.*/.Functions.'Save-AllFiles'", $transformlist)

    # Verify the modification
    ''
    ''
    Write-Host "Post-Op Data:" -ForegroundColor Cyan
    $data = $res.Retrieve("Files./.*File.*/.Functions./.*/")
    foreach($obj in $data){
        Write-Host "data: " -ForegroundColor Cyan -NoNewline; Write-Host $obj.data
        Write-Host "path: " -ForegroundColor Cyan -NoNewline
        $tab = 0
        foreach($p in $obj.path){
            Write-Host ("`t" * $tab + $p) -ForegroundColor Magenta
            $tab++
        }
    }
    #endregion

    Remove-Variable msg, tail, transformlist, obj
    Remove-Variable tab, p
}

Remove-Module resource