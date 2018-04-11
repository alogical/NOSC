<#
.SYNOPSIS
    Network device security baseline scanning tool.

.DESCRIPTION
    Uses text comparison to match network device configurations against
    STIG rules to validate compliance.

.NOTES
    Authors:
        [CB]  Christopher Bell
        [DKI] Daniel Ives

.NOTES
    CHANGE LOG
    ----------
    [DKI] 5/11/2017 >> Bug fixes, timeout adjustments, and report checkpoint
          features.
        ! Fixed bug where the script did not correctly parse the Command Line
          Interface prompt for devices that have a banner motd set.
        ! Fixed bug where the job removal list wasn't being cleared after the
          jobs have been removed from the running job list.
        + Refactored the session stream establishment logic into it's own
          function.
        ~ Changed the report logic to save the report data separately for each
          device as soon as it finishes scanning that device, and then con-
          solidates the files into the final report after all devices have been
          scanned.  This establishes the foundation for a future feature support
          to allow resuming scans that have been stopped due to computer restarts
          or hanged scripts.
        ~ Adjusted the timeouts for the cli prompt refresh logic in the Send-
          Command function to 15 seconds to allow for better network latency
          handling.
        ~ Made output modifier filter functions use case insensitive regex
          matching to support command format stadardization to lower case.

    [DKI] 4/28/2017 >> Warnings, comments, and cleanup.
        ! Fixed bug in command execution. Moved <cr> send during command
          confirmation to after the sent command has been replayed back.
        ! Fixed bug where report rows for NetIds that don't have a validation
          command weren't being properly recorded.
        ! Fixed bug where command cache was caching the same commands multiple
          times due to white space in the command text captured by the regex
          parser.
        + Added warning for the output processing section about possible data
          loss if the data is not first saved locally before trying to move it
          to networked share drives.
        + Added assembly reference for Windows forms to support message box
          prompts to the user when the scan has completed.
        - Removed dead code that was left behind by testing.

    [DKI] 4/27/2017 >> Command response caching, logging, and effeciency
          improvements.
        + Added writing of the scan report to the local AppData cache directory
          to ensure that the report is always saved, even if the share drives
          are not available.
        + Added command cache, but am having trouble getting the json string
          of the cached command output to save to a file
        + Added checks to the runspace polling loop to look for jobs that have
          failed, or are otherwise not running/completed.
        ! Fixed a bug in the compliance logic for NetIds that don't have a
          validation command to run against the device.  This may have been
          intended for rules that are not applicable, but there needs to be a
          better way to identify those rules.

    [DKI] 4/24/2017 >> Scan performance enhancements.
        + Added progress bar for users to see how far along the scan is
        + Added message output for the local data cache and log file location
        + Added log file empty check at end of jobs
        ~ Changed background scanning jobs from Start-Job method that has a
          lot of over head to using a runspace pool.  Reduced scan times from
          ~20 minutes to 3.75 minutes using 8 runspaces for 39 runspaces

    [DKI] 4/23/2017 >> Bug fixes for the command execution and response.
        + Added timeout functionality to prevent ending up in infinite loops
        ! Fixed logic error in the backspace resolver for response output
        ! Fixed logic error in the timeout and response receiving algorithm
        ! Fixed bug where a command would be sent to the device, but wasn't
          being executed

    [DKI] 4/19/2017 >> Script conventions and performance overhaul.
        + Added warnings, cautions, and notes
        + Commented functionality and design decisions
        + Added check and response loop for command output that prompts with
          --More-- information
        + Added functions to emulate the cisco | <filter> <expression> commands
          reducing total scan time from 3hrs to ~20 minutes
        + Added time out for establishing connections
        ! Fixed flow logic error in device scanning script block where the
          scan was opening multiple connections to the same device
        ! Fixed local AppData caching of STIG rule csv
        ! Fixed bug where line endings that didn't match were breaking the
          regular expression matching of multi-line output
        ! Fixed bug where sessions where being removed by the Posh-SSH module
          while they were still in use
        ~ Broke script into sections and re-ordered for a clearer logical flow
        ~ Revamped variable names & conventions for clarity
        ~ Replaced usage of static arrays with ArrayLists for memory and speed
          performance
        ~ Changed the static 5 second wait time for device response to commands
          to a 100 millisecond wait loop that checks the ssh stream data
          available flag and prompt checking for speed performance
#>
#//////////////////////////////////////////////////////////////////////////////
# (WARNING) DO NOT MODIFY THIS SCRIPT FROM THE SHARE DRIVE!
#
# This script is designed to be run from the share drive location. Editing the
# script in place may result in someone else executing your broken script
# before you have properly tested and debugged your new code.
#
# To edit the script:
#         Create a local copy
#         Test all changes against a subset of devices or test bed
#         Update author and change log
#         Backup the share drive script
#         Upload the new script to the share drive
#//////////////////////////////////////////////////////////////////////////////
###############################################################################
# Assembly Loading
#region
Write-Host ("/" * 80) -ForegroundColor Green
Write-Host "Configuring PowerShell Environment..." -ForegroundColor Green
Write-Host ("-" * 80) -ForegroundColor Green

#//////////////////////////////////////////////////////////////////////////////
# (WARNING) External libraries MUST come from a trusted source or be thoroughly
# verified that they do not contain malicious logic before being included for
# use on the AFNET.
#//////////////////////////////////////////////////////////////////////////////

Add-Type -AssemblyName Microsoft.VisualBasic
Add-Type -AssemblyName System.Windows.Forms
#endregion

###############################################################################
# Resource Path Configuration
#region
#//////////////////////////////////////////////////////////////////////////////
# (CAUTION) Using mapped share drives may cause unexpected behavior for other
# users who do not have the same drive letter mappings. Use \\Server\Share
# UNC file path format instead.
#//////////////////////////////////////////////////////////////////////////////

#//////////////////////////////////////////////////////////////////////////////
# Note: Precede folder names with "\", but do place a "\" at the end of the
#       path.
#//////////////////////////////////////////////////////////////////////////////

# Default LocalData Directory
$CachePath = "$HOME\AppData\Roaming\STIGScanner"

# Relative Paths
$dialog = New-Object System.Windows.Forms.FolderBrowserDialog
$dialog.Description = "Select scan output directory"

if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $ExportBasePath = $dialog.SelectedPath
}
else {
    return
}

# Source Configuration File Names
$dialog = New-Object System.Windows.Forms.OpenFileDialog
$dialog.ShowHelp    = $false
$dialog.Multiselect = $false

$dialog.Title  = "Device List"
$dialog.Filter = "Device List *.csv|*.csv"
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $NodelistAbsolutePath = $dialog.FileName
    $NodeListFileName     = Split-Path $dialog.FileName -Leaf
}
else {
    return
}

$dialog.Title  = "Checklist Rules"
$dialog.Filter = "Checklist Rules *.csv|*.csv"
if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
    $ChecklistAbsolutePath = $dialog.FileName
    $ChecklistFileName     = Split-Path $dialog.FileName -Leaf
}
else {
    return
}

# Build Absolute File Paths
$ExportFileName = ("Scan_{0}_{1}.{2}.{3}.csv" -f
    ([DateTime]::Now.ToShortDateString() -replace "/", "."),
    [DateTime]::Now.Hour,
    [DateTime]::Now.Minute,
    [DateTime]::Now.Second)

$ExportCachePath    = Join-Path $CachePath $ExportFileName
$ExportAbsolutePath = Join-Path $ExportBasePath $ExportFileName
#endregion

# Start Logging
Start-Transcript -LiteralPath (Join-Path $CachePath "Scan-Summary.txt") -Force

###############################################################################
# Posh-SSH Verification & Loading
#region
#//////////////////////////////////////////////////////////////////////////////
# (WARNING) External libraries MUST come from a trusted source or be thoroughly
# verified that they do not contain malicious logic before being included for
# use on the AFNET.
#//////////////////////////////////////////////////////////////////////////////

#//////////////////////////////////////////////////////////////////////////////
# (CAUTION) Native .NET managed SSH libraries are not supported on all versions
# of the Windows Standard Desktop Configuration.
#
# Native .NET SSH support is available by default for Windows 10 and later.
#//////////////////////////////////////////////////////////////////////////////

#//////////////////////////////////////////////////////////////////////////////
# Note: Posh-SSH library is being used For mixed workstation environments where
#       native .NET SSH support is not guaranteed.
#
#       Posh-SSH is a Non-DoD Sourced .NET secure shell library from GitHub:
#       https://github.com/darkoperator/Posh-SSH
#
#       Using Version: 1.7.2
#//////////////////////////////////////////////////////////////////////////////
$ApplicationPath = "$HOME\Documents\WindowsPowerShell\Programs\NOSC"
$PoshModulePath  = "$ApplicationPath\Modules\Posh-SSH"

Import-Module $PoshModulePath -ErrorAction Stop

if ((Get-PoshSSHModVersion).InstalledVersion -ne "1.7.2") {
    throw (New-Object System.ApplicationException( ("Invalid Posh-SSH version: {0}; install version 1.7.2" -f (Get-PoshSSHModVersion).InstalledVersion) ))
}
#endregion

###############################################################################
# Local Data Cache Setup & Import
#region
Write-Host ("/" * 80) -ForegroundColor Green

if (!(Test-Path $CachePath)){
    New-Item $CachePath -Type Directory | Out-Null
}

Write-Host ("Using node list named:`r`n {0}" -f $NodelistAbsolutePath) -ForegroundColor Green
Write-Host ("-" * 80) -ForegroundColor Green
Copy-Item $NodelistAbsolutePath (Join-Path $CachePath $NodelistFileName) -Force -ErrorAction Stop
$Nodelist = Import-Csv (Join-Path $CachePath $NodelistFileName)

Write-Host ("Using checklist CSV named:`r`n {0}" -f $ChecklistAbsolutePath) -ForegroundColor Green
Write-Host ("-" * 80) -ForegroundColor Green
Copy-Item $ChecklistAbsolutePath (Join-Path $CachePath $ChecklistFileName) -Force -ErrorAction Stop
$Checklist = Import-Csv (Join-Path $CachePath $ChecklistFileName)

Write-Host ("Local data cache and log files:`r`n {0}" -f $CachePath) -ForegroundColor Green
Write-Host ("-" * 80) -ForegroundColor Green

Write-Host ("Exporting completed scan data CSV to:`r`n {0}" -f $ExportAbsolutePath) -ForegroundColor Green
Write-Host ("-" * 80) -ForegroundColor Green

$FilterColumn = "stig"
$FilterItem   = $Checklist.'device type' -split "," | Select-Object -Unique

# Debugging
# Write-Debug $FilterColumn
# Write-Debug $FilterItem
#endregion

###############################################################################
# Device Scanning Job Script and Support Functions
#region
#//////////////////////////////////////////////////////////////////////////////
# (WARNING) Sending multiple commands to a device all at once at the same time
# using a single Posh-SSH session will cause the command output to be garbled.
#
# Posh-SSH does not have a mechanism to validate that all commands have run and
# all output has been received before sending received data to a session's read
# stream.
#//////////////////////////////////////////////////////////////////////////////

#//////////////////////////////////////////////////////////////////////////////
# (WARNING) Powershell version 4.0 (default for Windows 7) does not properly
# output logging information using the Start-Transcript command.
#
# Check is performed after the background runspace threads have completed to
# determine if the logs are empty, and tries to send data to the logs if
# needed.
#//////////////////////////////////////////////////////////////////////////////

#//////////////////////////////////////////////////////////////////////////////
# (CAUTION) Sending multiple <show running-configuration> commands to a device
# causes a lot of processor load on the device and is very slow.
#
# If multiple checks of the running configuration are needed; store the running
# configuration in a variable and then run the checks as regular expression
# matching against the stored configuration.
#//////////////////////////////////////////////////////////////////////////////

#//////////////////////////////////////////////////////////////////////////////
# Note: Send-Command is used to communicate with the remote device.  This
#       function only works well with one command at a time. (See Warning above)
#
#       If multiple commands must be run against a device as a batch or
#       transaction then the commands should be passed individually to the
#       Send-Command function and the output validated after all commands
#       have been executed.
#//////////////////////////////////////////////////////////////////////////////

$sb = {
    param ($device, $stigs, $checklist, $logpath, $credential)

    # Synchronous Command Execution Routine
    function Send-Command([String]$Command, [Object]$Stream, [String]$cli, [Bool]$DebugMode = $false) {
        $response = New-Object System.Text.StringBuilder
        $confirmation = New-Object System.Text.StringBuilder
        $start = [DateTime]::UtcNow
        $invalid = "% Invalid input detected"
        $ambiguous = "% Ambiguous command"
        $unrecognized = "% Unrecognized command"

        # Refresh the terminal prompt
        $Stream.Write( [Char]0x0d )
        $timeout = [DateTime]::UtcNow
        $wrap = 0
        do {
            if ($Stream.DataAvailable) {
                [void]$response.Append( (Receive-Response -Stream $stream -cli $cli -Timeout 15) )
                $timeout = [DateTime]::UtcNow
            }
            if (Test-Timeout $timeout 15) {
                Write-Warning "Remote server is not responding to commands, or synchronization was lost."
                return "Remote server is not responding to commands, or synchronization was lost."
            }
            $wrap++
            if ($wrap -eq 79) {
                Write-Host "." -ForegroundColor DarkYellow
                $wrap = 0
            }
            else {
                Write-Host "." -ForegroundColor DarkYellow -NoNewline
            }
            Start-Sleep -Milliseconds 100
        } while ($response.ToString() -notmatch $cli)
        $response.Length = 0

        Write-Host ("Executing {0} # {1}" -f $start.ToShortTimeString(), $Command) -ForegroundColor DarkYellow
        Write-Host "Waiting command response: " -ForegroundColor DarkYellow -NoNewline

        # Execute Command
        $Stream.WriteLine($Command)
        Write-Host "!" -ForegroundColor Red -NoNewline

        # Command confirmation loop
        $wrap = 0
        $response.Length = 0
        while (!$stream.DataAvailable) {
            $wrap++
            if ($wrap -eq 79) {
                Write-Host "." -ForegroundColor DarkYellow
                $wrap = 0
            }
            else {
                Write-Host "." -ForegroundColor DarkYellow -NoNewline
            }
            Start-Sleep -Milliseconds 100
        }

        # Resend Enter Key to ensure command execution
        $stream.Write( [char]0x0d )

        $timeout = [DateTime]::UtcNow
        do {
            if ($stream.DataAvailable) {
                [void]$response.Append( $stream.Read() )
            }
            $wrap++
            if ($wrap -eq 79) {
                Write-Host "." -ForegroundColor DarkYellow
                $wrap = 0
            }
            else {
                Write-Host "." -ForegroundColor DarkYellow -NoNewline
            }
            Start-Sleep -Milliseconds 100

            # Timeout test
            if (Test-Timeout $timeout 15) {
                $stop = [DateTime]::UtcNow.Subtract($start)
                Write-Host (" Time Out: {0} Milliseconds" -f ($stop.Seconds * 1000 + $stop.Milliseconds)) -ForegroundColor Red
                return "Operation timed out."
            }

            # Test for end of the command playback line
            $pos = $response.ToString().IndexOf("`n")
            if ($pos -ge 0) {
                [void]$confirmation.Append( $response.ToString().Substring(0, $pos) )
                Resolve-Backspaces $confirmation
                Write-Host $confirmation.ToString() -ForegroundColor Green
                $confirmation.Length = 0
                [void]$response.Remove(0, $pos + 1)
            }

        } while ($pos -lt 0)

        # Invalid Input Check
        if ($response.ToString() -match $invalid) {
            [void]$stream.Read()
            $stop = [DateTime]::UtcNow.Subtract($start)
            Write-Host (" Invalid Command: {0} Milliseconds" -f ($stop.Seconds * 1000 + $stop.Milliseconds)) -ForegroundColor Red
            return $response.ToString()
        }
        $response.Length = 0

        # Ambiguous Input Check
        if ($response.ToString() -match $ambiguous) {
            [void]$stream.Read()
            $stop = [DateTime]::UtcNow.Subtract($start)
            Write-Host (" Ambiguous Command: {0} Milliseconds" -f ($stop.Seconds * 1000 + $stop.Milliseconds)) -ForegroundColor Red
            return $response.ToString()
        }
        $response.Length = 0

        # Ambiguous Input Check
        if ($response.ToString() -match $unrecognized) {
            [void]$stream.Read()
            $stop = [DateTime]::UtcNow.Subtract($start)
            Write-Host (" Unrecognized Command: {0} Milliseconds" -f ($stop.Seconds * 1000 + $stop.Milliseconds)) -ForegroundColor Red
            return $response.ToString()
        }
        $response.Length = 0

        # Command response loop
        [void]$response.Append( (Receive-Response -Stream $Stream -cli $cli -Timeout 30) )

        $stop = [DateTime]::UtcNow.Subtract($start)
        Write-Host (" Execution Time: {0} Milliseconds" -f ($stop.Seconds * 1000 + $stop.Milliseconds)) -ForegroundColor DarkYellow

        # Trim backspaces from command output
        Resolve-Backspaces $response

        return ($response.ToString() -replace $cli)
    }

    # Connection Stream Establishment Automation Logic for Cisco Devices
    function Get-SSHStream([Object]$Session) {
        Write-Host "Establishing Session Stream..." -ForegroundColor DarkYellow -NoNewline
        $response = New-Object System.Text.StringBuilder
        $stream  = New-SSHShellStream -SSHSession $Session

        # Wait for cli prompt from device to confirm ready to accept commands
        while (!$stream.DataAvailable) {
            Start-Sleep -Milliseconds 100
        }
        do {
            [void]$response.Append($stream.Read())
            Start-Sleep -Milliseconds 100
        } while ($stream.DataAvailable)

        #//////////////////////////////////////////////////////////////////////////////
        # (WARNING) Initial response after establishing the session stream may contain
        # several lines of text other than the cli prompt.  Such text may be from the
        # banner motd... Only the last line fo text during initial stream establishment
        # should be the cli prompt.
        #//////////////////////////////////////////////////////////////////////////////
        # Command Line Interface (CLI) Parsing
        $lines = $response.ToString().Split("`r`n")
        $prompt = $lines[-1].Trim()

        # Set cli regex expression
        #$cli = "(\r\n)?" + [System.Text.RegularExpressions.Regex]::Escape( $prompt )
        $cli = [System.Text.RegularExpressions.Regex]::Escape( $prompt )
        $response.Length = 0

        # Attach CLI prompt regular expression to the stream object
        Add-Member -InputObject $stream -MemberType NoteProperty -Name cli -Value $cli
        
        Write-Host "Complete, Prompt: [$prompt]" -ForegroundColor DarkYellow

        return $stream
    }

    # Send-Command Timeout
    function Test-Timeout([DateTime]$UtcStarted, [Int]$Seconds, [String]$cli) {
        $diff = [DateTime]::UtcNow.Subtract($UtcStarted)
        if ($diff.Seconds -gt $Seconds) {
            return $true
        }
        return $false
    }

    # Send-Command Response Handler
    function Receive-Response([Object]$Stream, [String]$cli, [Int]$Timeout, [Switch]$WriteHost) {
        $response = New-Object System.Text.StringBuilder
        $chunk = New-Object System.Text.StringBuilder
        $start = [DateTime]::UtcNow
        $wrap = 0
        do {
            $more = $true
            do {
                if ($Stream.DataAvailable) {
                    [void]$chunk.Append( $Stream.Read() )
                }
                if($chunk.ToString() -match "--More--") {
                    [Void]$response.Append( ($chunk.ToString()) )
                    $chunk.Length = 0

                    # Send space key to prompt continuation of command response
                    $Stream.Write( " " )

                    while (!$Stream.DataAvailable) {
                        $wrap++
                        if ($wrap -eq 79) {
                            Write-Host "." -ForegroundColor Cyan
                            $wrap = 0
                        }
                        else {
                            Write-Host "." -ForegroundColor Cyan -NoNewline
                        }
                        Start-Sleep -Milliseconds 100
                    }
                }
                else {
                    $more = $false
                    $wrap++
                    if ($wrap -eq 79) {
                        Write-Host "." -ForegroundColor Cyan
                        $wrap = 0
                    }
                    else {
                        Write-Host "." -ForegroundColor Cyan -NoNewline
                    }
                    Start-Sleep -Milliseconds 100
                }
            } while ($more)
            [Void]$response.Append( $chunk.ToString() )
            $chunk.Length = 0

            # Timeout test
            if (Test-Timeout $start $Timeout) {
                $stop = [DateTime]::UtcNow.Subtract($start)
                Write-Host (" Time Out: {0} Milliseconds" -f ($stop.Seconds * 1000 + $stop.Milliseconds)) -ForegroundColor Red
                return "Operation timed out"
            }
        } while ($response.ToString() -notmatch $cli)
        return $response.ToString()
    }

    # Send-Command Response Backspace Format Handler
    function Resolve-Backspaces([System.Text.StringBuilder]$Response, [Bool]$DebugMode = $false) {
        $buffer = $response.ToString()

        if ($response.Length -eq 0) {
            return
        }

        # Honor Backspaces
        $deleted = 0
        $backspace = [Char]0x08
        $pos = $buffer.IndexOf( $backspace )
        while ($pos -ge 0) {
            $i = 0
            $rem = $pos - $deleted

            while($response[$rem + $i] -eq $backspace) {
                $i++
            }

            if ($pos -eq 0) {
                [Void]$response.Remove(0, $i)
                Write-Debug ("Deleted Leading {0} chars: [{1}]" -f $i, $buffer.Substring($pos, $i))
                $deleted += $i
            }
            else {
                $idx = $rem - $i
                $len =  $i * 2
                if ($idx -lt 0) {
                    $len += $idx # subtract length by negative index value
                    $idx = 0
                }

                [Void]$response.Remove($idx, $len)
                Write-Debug ("Deleted {0} chars: [{1}]" -f $len, $buffer.Substring($idx + $deleted, $len))
                $deleted += $len
            }

            $pos = $buffer.IndexOf($backspace, $pos + $i)
        }
    }

    # Equivalent of IOS command [show <command> | i <expression>]
    function Filter-Include([String]$Expression, [String]$Configuration) {
        $result = New-Object System.Text.StringBuilder
        $regex = '(?i).*' + [System.Text.RegularExpressions.Regex]::Escape($Expression) + '.*'

        $match = [System.Text.RegularExpressions.Regex]::Match($Configuration, $regex)
        while ($match.Success) {
            [void]$result.Append($Configuration.Substring($match.Index, $match.Length))
            $match = $match.NextMatch()
        }

        # Normalize result line endings
        return $result.ToString()
    }

    # Equivalent of IOS command [show <command> | e <expression>]
    function Filter-Exclude([String]$Expression, [String]$Configuration) {
        $result = New-Object System.Collections.ArrayList
        $regex = '(?i).*' + [System.Text.RegularExpressions.Regex]::Escape($Expression) + '.*'

        [void]$result.AddRange( $Configuration.Split([System.Environment]::NewLine) )
        foreach ($line in $result) {
            if ([System.Text.RegularExpressions.Regex]::Match($line, $regex)) {
                [void]$result.Remove($line)
            }
        }

        return ($result -join [System.Environment]::NewLine)
    }

    # Equivalent of IOS command [show <command> | b <expression>]
    function Filter-Begin([String]$Expression, [String]$Configuration) {
        $regex = '(?i).*' + [System.Text.RegularExpressions.Regex]::Escape($Expression) + '.*'

        $match = [System.Text.RegularExpressions.Regex]::Match($Configuration, $regex)
        if ($match.Success) {
            $start  = $match.Index
            $length = $Configuration.Length - $start
        }

        return $Configuration.Substring($start, $length)
    }

    # Equivalent of IOS command [show <command> | sec <expression>]
    function Filter-Section([String]$Expression, [String]$Configuration) {
        $result = New-Object System.Text.StringBuilder
        $expr = '.*' + [System.Text.RegularExpressions.Regex]::Escape($Expression) + '.*'
        $regex = New-Object System.Text.RegularExpressions.Regex($expr,
            (
                [System.Text.RegularExpressions.RegexOptions]::Compiled -bor
                [System.Text.RegularExpressions.RegexOptions]::IgnoreCase
            )
        )
        [char[]]$return = @("`r", "`n")
        [char] $space = " "


        $match = $regex.Match($Configuration)
        $start  = 0
        $length = 0
        while ($match.Success) {
            $newline = $false
            $start  = $match.Index
            $length = 0
            for ($i = $start; $i -le $Configuration.Length -1; $i++) {
                if ($newline -and $return -notcontains $Configuration[$i]) {
                    if ($Configuration[$i] -ne $space) {
                        # Capture seperation [!] exclamation mark to support validation scan parsing
                        if ($Configuration[$i] -eq '!') {
                            [void]$result.Append("!`r`n")
                        }
                        break
                    }
                    $newline = $false
                }
                if ($return -contains $Configuration[$i]) {
                    $newline = $true
                }
                $length++
            }
            [void]$result.Append($Configuration.Substring($start, $length))
            $match = $regex.Match($Configuration, ($start + $length))
        }

        return $result.ToString()
    }

    # Filter-Count ... Not Yet Implemented
    function Filter-Count ([String]$Expression, [String]$Configuration) {
        Write-Error -Exception (New-Object System.NotImplementedException)
    }

    $regex = @{}
    $regex.ShowRunFilter = New-Object System.Text.RegularExpressions.Regex(
        "sh(ow)?\s+run[^|]+\|\s+(?<filter>\w+)\s+(?<expr>.*)",
        [System.Text.RegularExpressions.RegexOptions]::Compiled)

    $regex.Command = New-Object System.Text.RegularExpressions.Regex(
        "(?<cmd>[^|]+)(?<mod>\|\s+(?<filter>\w+)\s+(?<expr>.*))?",
        [System.Text.RegularExpressions.RegexOptions]::Compiled)

    $cache = @{}
    $scripts = @{}

    $report     = New-Object System.Collections.ArrayList($stigs.Count)
    $response   = New-Object System.Text.StringBuilder

    $log        = Join-Path $logpath ("log_{0}.txt" -f $device.Device_Hostname)
    $CachePath  = Join-Path $logpath ("{0}.cache" -f $device.Device_Hostname)
    $checkpoint = Join-Path $logpath ("{0}.chk" -f $device.Device_Hostname)

    Start-Transcript -LiteralPath $log -Force | Out-Null

    #//////////////////////////////////////////////////////////////////////////////
    # (WARNING) Unhandled output from function calls, etc... will end up in the
    # Powershell pipeline (implicity), cluttering up the data output of the script
    # with data that was not explicitly returned by the script.
    #
    # Proper output handling should prevent data from entering the pipeline
    # implicitly, but an alternative is to execute code returning implicit data
    # inside of a scriptblock with the output sent to null.  Store the data that
    # the code should explicitly return in an HashTable or ArrayList defined
    # outside of the code block.
    #//////////////////////////////////////////////////////////////////////////////
    # Implicit Output Filter
    $null = & {
        $ip       = $device.ip
        $orion    = $device.Orion_Hostname
        $mob      = $device.MOB
        $gsu      = $device.MOB_GSU
        $Hostname = $device.Device_Hostname

        # Print device information for logging
        Write-Host ("Scanning...`r`n{0}" -f ($device | Format-List -Property ip, Orion_Hostname, MOB, MOB_GSU, Device_Hostname | Out-String))

        $RunningConfig = [String]::Empty
        $session = New-SshSession -ComputerName $ip -Credential $credential -AcceptKey -Verbose -ErrorAction SilentlyContinue

        if ($session.Connected) {
            #$stream  = New-SSHShellStream -SSHSession $session
            #
            ## Wait for cli prompt from device to confirm ready to accept commands
            #while (!$stream.DataAvailable) {
            #    Start-Sleep -Milliseconds 100
            #}
            #do {
            #    [void]$response.Append($stream.Read())
            #    Start-Sleep -Milliseconds 100
            #} while ($stream.DataAvailable)
            #
            ## Set regex replace expression
            #$cli = "(\r\n)?" + [System.Text.RegularExpressions.Regex]::Escape( $response.ToString().Trim() )
            #$response.Length = 0

            $stream = Get-SSHStream $session
            $cli = $stream.cli

            # Turn off --more-- prompting and return all command response data at one time
            Send-Command -Command "terminal length 0" -Stream $stream -cli $cli | Out-Null

            $RunningConfig = Send-Command -Command "sh run" -Stream $stream -cli $cli

            if ([String]::IsNullOrEmpty($RunningConfig)) {
                Write-Error "Failed to get running configuration!"
            }
            else {
                $cache.RunningConfig = $RunningConfig
            }
        }
        else {
            Write-Warning "$Hostname [$ip] not reachable. Edited Results to reflect."
        }

        foreach ($stig in $stigs -match $checklist){
            $category      = $stig.Category
            $netid         = $stig.NetID
            $batch         = $stig.Command.Split([System.Environment]::NewLine)
            $compliance    = ($stig.Expectations_for_compliance -replace ("`r", "`n") -replace ("`n`n", "`n")).Trim()
            $noncompliance = ($stig.Expectations_for_noncompliance -replace ("`r", "`n") -replace ("`n`n", "`n")).Trim()

            if ([String]::IsNullOrEmpty($noncompliance)) {
                $expected = $compliance
            }
            else {
                $expected = $noncompliance
            }

            $row = [PSCustomObject]@{
                Category    = $category
                Device_Type = $checklist
                NetId       = $netid
                MOB         = $mob
                GSU         = $gsu
                Device      = $ip
                Hostname    = $Hostname
                OrionName   = $orion
                Command     = $stig.Command
                Results     = [String]::Empty
                Expected    = $expected
                Findings    = [String]::Empty
            }

            if (!$session.Connected) {
                $row.results  = "Device not reachable"
                $row.findings = "Manual check required"
                [void]$report.Add($row)
                continue
            }

            ###############################################################################
            # Execute Validation Commands and Collect Data
            Write-Host ("Validating {0}" -f $stig.NetId) -ForegroundColor Magenta
            $response.Length = 0
            $valid = $false
            foreach ($command in $batch) {

                # Enforce standard command formatting
                $command = $command.ToLower().Trim()
                
                if ([string]::IsNullOrWhiteSpace($command)) {
                    continue
                }
                $valid = $true

                # Custom match show running-configuration... any variation of the command
                $m = $regex.ShowRunFilter.Match($command)

                if ($m.Success) {
                    switch -Regex ($m.Groups['filter'].Value) {
                        '^i$' {
                            [void]$response.Append( (Filter-Include -Expression $m.Groups['expr'] -Configuration $RunningConfig) )
                        }
                        '^e$' {
                            [void]$response.Append( (Filter-Exclude -Expression $m.Groups['expr'] -Configuration $RunningConfig) )
                        }
                        '^b$' {
                            [void]$response.Append( (Filter-Begin -Expression $m.Groups['expr'] -Configuration $RunningConfig) )
                        }
                        '^sec$' {
                            [void]$response.Append( (Filter-Section -Expression $m.Groups['expr'] -Configuration $RunningConfig) )
                        }
                        default {
                            Write-Error ("Unknown IOS pipe command [{0}] output modifier: [{1}]" -f $command, $m.Groups['filter'].Value)
                        }
                    }

                    # This Timer is to help reduce processor overloading
                    Start-Sleep -Milliseconds 100
                }
                else {
                    $m = $regex.Command.Match($command)

                    # Check command response cache
                    if ($m.Success) {

                        $cmd    = $m.Groups['cmd'].Value.Trim()
                        $mod    = $m.Groups['mod'].Value.Trim()
                        $filter = $m.Groups['filter'].Value.Trim()
                        $expr   = $m.Groups['expr'].Value.Trim()

                        if (!$cache.ContainsKey($cmd)) {
                            # Execute base command
                            $cache.Add($cmd, (Send-Command -Command $m.Groups['cmd'].Value -Stream $stream -cli $cli))
                        }

                        # Filter Response if required
                        if ($mod.Length -gt 0) {
                            switch -Regex ($filter) {
                                '^i$' {
                                    [void]$response.Append( (Filter-Include -Expression $expr -Configuration $cache[$cmd]) )
                                }
                                '^e$' {
                                    [void]$response.Append( (Filter-Exclude -Expression $expr -Configuration $cache[$cmd]) )
                                }
                                '^b$' {
                                    [void]$response.Append( (Filter-Begin   -Expression $expr -Configuration $cache[$cmd]) )
                                }
                                '^sec$' {
                                    [void]$response.Append( (Filter-Section -Expression $expr -Configuration $cache[$cmd]) )
                                }
                                default {
                                    Write-Error ("Unknown IOS pipe command [{0}] output modifier: [{1}]" -f $cmd, $mod)
                                }
                            }

                            # This Timer is to help reduce
                            Start-Sleep -Milliseconds 100
                        }
                        else {
                            [void]$response.Append($cache[$cmd])
                        }
                    }

                    # If command parsing fails
                    else {
                        Write-Error "Command [$command] could not be parsed."
                        # Execute compliance check command
                        [void]$response.Append( (Send-Command -Command $command -Stream $stream -cli $cli) )

                        # Store command and output for future reference/filtering
                        if (!$cache.ContainsKey($command)) {
                            $cache.Add($command, $response.ToString())
                        }
                    }
                }
            }

            if (!$valid) {
                Write-Warning "No validaton command to execute for rule $($netid)"
                $row.Results  = "No validation command defined"
                $row.Findings = "Manual check required"
                [void]$report.Add($row)
                continue
            }

            # Normalize response line endings
            $row.Results = ($response.ToString() -replace ("`r", "`n") -replace ("`n`n", "`n")).Trim()

            ###############################################################################
            # Compliance Verification Checks
            if (!$scripts.ContainsKey($stig.Script)) {
                $scripts.Add($stig.Script, [scriptblock]::Create($stig.Script))
            }
            $compliance = & ($scripts[$stig.Script]) $row.Results $row
            if ($compliance -eq 2) {
                $row.Findings = "Complies with comments"
            }
            elseif ($compliance -eq 1) {
                $row.Findings = "Compliant"
            }
            elseif ($compliance -eq 0) {
                $row.Findings = "Non-Compliant"
            }
            elseif ($compliance -eq -1) {
                $row.Findings = "Manual check required"
            }
            elseif ($compliance -eq -2) {
                $row.Findings = "Not Applicable"
            }
            else {
                $row.Findings = "Error"
            }

            [void]$report.Add($row)
        }
        Remove-SSHSession -SSHSession $session | Out-Null

    } # End Implicit Output Filter

    # Convert the command cache to json string format and write it to the hard drive
    [string]$json = ConvertTo-Json -InputObject $cache -Compress

    Write-Host "Saving command cache"
    $json | Set-Content $CachePath -Force | Out-Null

    # Write the results to the checkpoint file
    $report | Export-Csv $checkpoint -NoTypeInformation -Force

    Stop-Transcript | Out-Null

    #return $report
}
#endregion

###############################################################################
# Network Security Baseline Scan
#region
$Credential = (Get-Credential)
$start = [DateTime]::UtcNow

[System.Management.Automation.Runspaces.RunspacePool]$RunspacePool = [System.Management.Automation.Runspaces.RunspaceFactory]::CreateRunspacePool(

    1, # Min Runspaces

    5  # Max Runspaces

    #$SessionState
)
$RunspacePool.Open()

$Running = New-Object System.Collections.ArrayList
foreach ($filter in $FilterItem){

    $rules   = ($Checklist -match $filter)
    $devices = ($Nodelist | ? $FilterColumn -match $filter)
    foreach ($device in $devices) {
        $Parameters = @{
            Device     = $device
            Stigs      = $rules
            Checklist  = $filter
            LogPath    = $CachePath
            Credential = $Credential
        }
        $Job = [PSCustomObject]@{
            Parameters = $Parameters
            Host       = $device.Device_Hostname
            Thread     = [System.Management.Automation.PowerShell]::Create()
            Handle     = $null
        }

        $Job.Thread.RunspacePool = $RunspacePool
        [void]$Job.Thread.AddScript($sb)
        [void]$Job.Thread.AddParameters($Parameters)

        $Job.Handle = $Job.Thread.BeginInvoke()
        [void]$Running.Add($job)
    }
}

$TotalJobs = $Running.Count
Write-Host "$TotalJobs Jobs Started." -ForegroundColor DarkYellow

$Completed = New-Object System.Collections.ArrayList($TotalJobs)
$RemoveList = New-Object System.Collections.ArrayList

while ($Running.Count -gt 0) {
    foreach ($job in $running) {
        if ($job.Handle.IsCompleted) {
            [void]$Completed.Add($job)
            [void]$RemoveList.Add($job)
            Write-Host ("Completed: {0}" -f $job.Host) -ForegroundColor Green
        }
        elseif ($Job.Thread.InvocationStateInfo.State -ne [System.Management.Automation.PSInvocationState]::Running) {
            # Prevent infinite looping waiting for jobs that have failed...etc...
            [void]$Completed.Add($job)
            [void]$RemoveList.Add($Job)
            Write-Host ("{0}: {1}" -f $job.Thread.InvocationStateInfo, $job.Host) -ForegroundColor Red
        }
    }
    foreach ($job in $RemoveList) {
        [void]$Running.Remove($job)
    }
    $RemoveList.Clear()
    $Percent = $Completed.Count / $TotalJobs * 100
    Write-Progress -Activity "Scanning Network Devices" -Status ("{0}% Complete" -f $Percent) -PercentComplete $Percent
    Start-Sleep -Seconds 5
}

$output = @()
foreach ($job in $Completed) {
    [void]$job.Thread.EndInvoke($job.Handle)
    $job.Thread.Dispose()
}

$stop = [DateTime]::UtcNow.Subtract( $start )
Write-Host ("Execution Time: {0} Hours, {1} Minutes, {2} Seconds, {3} Milliseconds" -f
    $stop.Hours,
    $stop.Minutes,
    $stop.Seconds,
    $stop.Milliseconds
)  -ForegroundColor DarkYellow
#endregion

###############################################################################
# Process and Export Results
#region
#//////////////////////////////////////////////////////////////////////////////
# (WARNING) Because the export path may become unavailable while the scan is
# running, the scan data should always be saved locally first to make sure that
# results are not lost.
#//////////////////////////////////////////////////////////////////////////////
#$output -notmatch "true" | Select Category,Device_Type,NetID,MOB,GSU,Device,Hostname,Orion,Command,Results,Expected,Findings | Export-Csv $ExportCachePath -NoTypeInformation
# Combine Checkpoint files into single report
$report = New-Object System.Collections.ArrayList
$report.AddRange((Get-ChildItem "$CachePath\*.chk" | % {Import-Csv -LiteralPath $_.FullName}))
$report | Export-Csv $ExportCachePath -NoTypeInformation

# Remove Checkpoint files
Get-ChildItem "$CachePath\*.chk" | %{$_.Delete()} | Out-Null
if ($ExportAbsolutePath) {
    Move-Item -LiteralPath $ExportCachePath -Destination $ExportAbsolutePath
}
else {
    Write-Warning "There was no save path specified to output a CSV."
}

[System.Windows.Forms.MessageBox]::Show(
    "Network scan complete.",
    "Baseline Compliance Scanning Utility",
    [System.Windows.Forms.MessageBoxButtons]::OK,
    [System.Windows.Forms.MessageBoxIcon]::Information
)
#endregion

# End Logging
Stop-Transcript