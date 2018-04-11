<#
.SYNOPSIS
    A full graceful telnet client using PowerShell and the .NET Framework.

.DESCRIPTION
    This script was made with a view of using it to have full control over the text
    stream for automating Cisco router and switch configurations.

.PARAMETER Server
    The address of the server or router hosting the telnet service.
    Either IP address or DNS name.

.PARAMETER Port
    The TCP port number of the Telnet service running on the Telnet host.

.LINK
    https://gist.github.com/grantcarthew/6985142
#>
function telnet {
    [CmdletBinding()]
    param
    (
        [Parameter(Mandatory = $true)]
            [String]
            $Server,
    
        [Parameter(Mandatory = $false)]
        [ValidateRange(0,65535)]
            [Int]
            $Port = 23
    )

    # Initialize variables
    [System.Text.ASCIIEncoding]$ASCIIEncoding = [System.Text.Encoding]::ASCII
    [System.Net.Sockets.Socket]$Socket = $null

    # Debugging Set
    $DebugMembers = @(
        [System.Management.Automation.PSMemberTypes]::Property,
        [System.Management.Automation.PSMemberTypes]::CodeProperty,
        [System.Management.Automation.PSMemberTypes]::NoteProperty,
        [System.Management.Automation.PSMemberTypes]::ScriptProperty
    )

    # Checking host address and port.
    if ($Server -match ":")
    {
        try
        {
            $preference = $ErrorActionPreference
            $ErrorActionPreference = [System.Management.Automation.ActionPreference]::Stop

            $field  = $Server.Split(':')
            $Server = $field[0]
            $Port   = $field[1]
        }
        catch
        {
            Write-Error $_
            return
        }
        finally
        {
            $ErrorActionPreference = $preference
        }
    }

    # Setup and connect the TCP Socket.
    $Socket = New-Object -TypeName System.Net.Sockets.Socket(
        [System.Net.Sockets.AddressFamily]::InterNetwork,
        [System.Net.Sockets.SocketType]::Stream,
        [System.Net.Sockets.ProtocolType]::Tcp)
    $Socket.NoDelay = $true
    try
    {
        Write-Verbose ("Connecting to {0}:{1}" -f $Server,$Port)
        $Socket.Connect($Server, $Port)
    }
    catch
    {
        $Socket.Close()
        $Socket.Dispose()
        $Socket = $null
        Write-Error $_
        return
    }
    Write-Verbose ("Connected {0}" -f $Socket.RemoteEndPoint.ToString())

    # This state object is used to pass the connected Socket and the
    # PowerShell parent Host reference to the child PowerShell object.
    Write-Debug ("Initializing State:{0}{1}" -f
        ($Socket | Get-Member -MemberType $DebugMembers | Format-Table | Out-String),
        ($Host   | Get-Member -MemberType $DebugMembers | Format-Table | Out-String))
    $State = [PSCustomObject]@{"Socket"=$Socket;"Host"=$Host;"Exception"=$null}

    # This script block is used as the receive code for the Socket
    # from within the child PowerShell object.
    $Script = {
        param($state)
        # This encoding object is used to decode the return string.
        [System.Text.ASCIIEncoding]$ASCIIEncoding = [System.Text.Encoding]::ASCII

        # TELNET commands
        [Byte]$GA   = 249 # Go Ahead
        [Byte]$WILL = 251 # Desire to begin
        [Byte]$WONT = 252 # Refusal to perform
        [Byte]$DO   = 253 # Request that the other party perform
        [Byte]$DONT = 254 # Demand that the other party stop performing
        [Byte]$IAC  = 255 # Interpret as Command

        # TELNET options
        [Byte]$ECHO = 1 # Used to check the echo mode
        [Byte]$SUPP = 3 # Suppress go ahead
        
        # Used to hold the number of bytes returned from the network stream.
        [Int]$bytes = 0
        
        # Buffer to hold the returned Bytes.
        [Byte[]]$buffer = New-Object -TypeName Byte[]($state.Socket.ReceiveBufferSize)
    
        # This is the main receive loop.
        while ($state.Socket.Connected)
        {
            try
            {
                # The following statement will block the thread until data is received.
                $bytes = $state.Socket.Receive($buffer)
            }
            catch
            {
                # This exception reference is used to pass the error back to the
                # parent PowerShell process.
                $state.Exception = $Error[0]
                break
            }

            if ($bytes -gt 0)
            {
                $index = 0
                $responseLen = 0
            
                # The index is used to move through the buffer to analyze the received data
                # looking for Telnet commands and options.
                while ($index -lt $bytes)
                {
                    if ($buffer[$index] -eq $IAC)
                    {
                        try
                        {
                            switch ($buffer[$index + 1])
                            {
                                # If two IACs are together they represent one data byte 255
                                $IAC
                                {
                                    $buffer[$responseLen++] = $buffer[$index]
                                    $index += 2
                                    break
                                }
                            
                                # Ignore the Go-Ahead command
                                $GA
                                {
                                    $index += 2
                                    break
                                }
                            
                                # Respond WONT to all DOs and DONTs
                                {($_ -eq $DO) -or ($_ -eq $DONT)}
                                {
                                    $buffer[$index + 1] = $WONT
                                    $state.Socket.Send($buffer, $index, 3,
                                        [System.Net.Sockets.SocketFlags]::None) | Out-Null
                                    $index += 3
                                    break
                                }
                            
                                # Respond DONT to all WONTs
                                $WONT
                                {
                                    $buffer[$index + 1] = $DONT
                                    $state.Socket.Send($buffer, $index, 3,
                                        [System.Net.Sockets.SocketFlags]::None) | Out-Null
                                    $index += 3
                                    break
                                }
                            
                                # Respond DO to WILL ECHO and WILL SUPPRESS GO-AHEAD
                                # Respond DONT to all other WILLs
                                $WILL
                                {
                                    [Byte]$action = $DONT

                                    if ($buffer[$index + 2] -eq $ECHO)
                                    {
                                        $action = $DO
                                    }
                                    elseif ($buffer[$index + 2] -eq $SUPP)
                                    {
                                        $action = $DO
                                    }

                                    $buffer[$index + 1] = $action
                                    $state.Socket.Send($buffer, $index, 3,
                                        [System.Net.Sockets.SocketFlags]::None) | Out-Null
                                    $index += 3;
                                    break;
                                }
                            }
                        }
                        catch
                        {
                            # If there aren't enough bytes to form a command, terminate the loop.
                            $index = $bytes
                        }
                    }
                    else
                    {
                        if ($buffer[$index] -ne 0)
                        {
                            $buffer[$responseLen++] = $buffer[$index]
                        }
                        $index++
                    }
                }
            
                # Displays the response with no command codes on the parent PowerShell object.
                $returnString = $ASCIIEncoding.GetString($buffer, 0, $responseLen)
                $state.Host.UI.Write($returnString)
            }
        }
    } # End of the child PowerShell script definition.

    # Create a child PowerShell object to run the background Socket receive method.
    $PS = [PowerShell]::Create()
    [void]$PS.AddScript($Script).AddArgument($State)
    [System.IAsyncResult]$AsyncResult = $null
    try
    {
        # The receive job is started asynchronously.
        #$AsyncResult = $PS.BeginInvoke()
        Add-Member -InputObject $PS -MemberType NoteProperty -Name AsyncResult -Value $PS.BeginInvoke()
        Write-Debug ("Socket Receiver Started:{0}{1}" -f
            ($PS             | Get-Member -MemberType $DebugMembers | Format-Table | Out-String),
            ($PS.AsyncResult | Get-Member -MemberType $DebugMembers | Format-Table | Out-String))
        while ($Socket.Connected -and !$PS.AsyncResult.IsCompleted)
        {
            # Wait for keys to be pressed in the parent PowerShell console window.
            # This is a blocking call so the telnet session may get disconnected
            # while waiting for a key to be pressed.
            $Key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp").Character
                
            # Check the socket and see if it is still active.
            $PollCheck1 = $Socket.Poll(5000,[System.Net.Sockets.SelectMode]::SelectRead)
            $PollCheck2 = ($Socket.Available -eq 0)
            if (($PollCheck1 -and $PollCheck2) -or ($State.Exception -ne $null))
            {
                Write-Host "Connection Timed-Out"
                break
            }

            Write-Verbose ("Sending {0} bytes..." -f $Data.Length)
            # Socket seems good, send the data.
            $Data = $ASCIIEncoding.GetBytes($key)
            [void]$Socket.Send($Data)
        }
    }
    finally
    {
        # Cleanup the socket and child PowerShell process.
        if ($Socket -ne $null)
        {
            Write-Debug "Socket Disposed"
            $Socket.Close()
            $Socket.Dispose()
            $Socket = $null
        }

        if ($PS -ne $null -and $PS.AsyncResult -ne $null)
        {
            Write-Debug "Socket Receiver Disposed"
            $PS.EndInvoke($PS.AsyncResult)
            $PS.Dispose()
        }
    }
}

Export-ModuleMember -Function *