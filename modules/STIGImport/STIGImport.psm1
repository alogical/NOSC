<#
.SYNOPSIS
    STIG rule viewer.

.DESCRIPTION
    Generates window with STIG rule data for viewing.

.NOTES
    Author: Daniel K. Ives
    Email:  daniel.ives@live.com
#>

Add-Type -AssemblyName System.Windows.Forms

###############################################################################
###############################################################################
## SECTION 01 ## PUBILC FUNCTIONS AND VARIABLES
##
## Pass-thru Export-ModuleMember calls export all functions and variables
## to the global session that were passed to this modules session from nested
## modules.
###############################################################################
###############################################################################

function Import-ChecklistDialog {
    $file_dialog = New-Object System.Windows.Forms.FileDialog
    $file_dialog.Title    = "Select Security Technical Implementation Guide Checklist"
    $file_dialog.ShowHelp = $false
    $file_dialog.Filter   = "Checklist *.xml|*.xml"

    if ($file_dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $file_xml = Get-XmlDocument $file_dialog.FileName
    }
    else {
        return
    }
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

function Read-File ([string]$FullName) {

    if ([System.IO.File]::Exists($FullName)) {
        $FileInfo = Get-Item $FullName
        $stream = $FileInfo.OpenRead()
    }
    else {
        return
    }

    $buffer = New-Object Byte[] 512
    $sb     = New-Object System.Text.StringBuilder
    $bytes  = 1

    while ($stream.CanRead -and $bytes -gt 0) {
        $bytes = $stream.Read($buffer, 0, $buffer.Length - 1)
        [void]$sb.Append([System.Text.UnicodeEncoding]::UTF8.GetChars($buffer, 0, $bytes))
    }

    $stream.Close()
    $file = $sb.ToString()

    return $file
}

function Get-XmlDocument ($FullName) {
    $file = Read-File $FullName

    if ($file) {
        [xml]$xml = $file
    }
    else {
        return
    }

    $regex = New-Object System.Text.RegularExpressions.Regex(
        "xmlns=('|`")(?<ns>[^'|`"]+)('|`")",
        [System.Text.RegularExpressions.RegexOptions]::Compiled
        )

    $match = $regex.Match($file)
    if ($match.Success) {
        $ns = $match.Groups['ns'].Value
    }
    else {
        $ns = "http://www.w3.org/1999/xhtml"
    }

    $nsm = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
    $nsm.AddNamespace('ns', $ns)
    Add-Member -InputObject $xml -MemberType NoteProperty -Name NameSpaceManager -Value $nsm

    return $xml
}

function Get-Rule ([object]$doc, [string]$netid) {
    $group = $doc.SelectSingleNode("//ns:Group[ns:Rule/ns:version[text()='$netid']]", $doc.NamespaceManager)
    $rule  = $group.SelectSingleNode("ns:Rule", $doc.NamespaceManager)

    $title       = $rule.SelectSingleNode('ns:title', $doc.NamespaceManager).InnerText

    $description = $rule.SelectSingleNode('ns:description', $doc.NamespaceManager).InnerText
    $description = $description -replace ("`n","`r`n")

    # Open Tag replace regex
    $pattern = '<([^/>]+)>'
    $replace = "`$1`r`n"
    $description = [System.Text.RegularExpressions.Regex]::Replace($description, $pattern, $replace)

    # End Tag replace regex
    $pattern = '</[^>]+>'
    $replace = "`r`n`r`n"
    $description = [System.Text.RegularExpressions.Regex]::Replace($description, $pattern, $replace)

    # End Tag replace regex
    $pattern = 'VulnDiscussion'
    $replace = ""
    $description = [System.Text.RegularExpressions.Regex]::Replace($description, $pattern, $replace)

    $check = $rule.SelectSingleNode('ns:check/ns:check-content', $doc.NamespaceManager).InnerText
    $fix   = $rule.SelectSingleNode('ns:fixtext', $doc.NamespaceManager).InnerText

    $sb = New-Object System.Text.StringBuilder
    [void]$sb.Append($title)
    [void]$sb.Append($description)
    [void]$sb.Append($check)
    [void]$sb.Append($fix)

    $sha1 = Get-SecureHashProvider

    $object = [PSCustomObject]@{
        Checklist   = $guid
        NetId       = $netid
        Title       = $title
        Description = $description
        Check       = $check
        Fix         = $fix
        Hash        = $sha1.HashString($sb.ToString())
    }

    return $object
}

function Get-SecureHashProvider {
    $provider = New-Object System.Security.Cryptography.SHA1CryptoServiceProvider

    Add-Member -InputObject $provider -MemberType ScriptMethod -Name HashFile -Value {
        param(
            [Parameter(Mandatory = $true)]
            [System.IO.FileInfo]
                $File
        )
        $reader = [System.IO.StreamReader]$File.FullName
        [void] $this.ComputeHash( $reader.BaseStream )

        $reader.Close()

        return $this.OutString
    }

    Add-Member -InputObject $provider -MemberType ScriptMethod -Name HashString -Value {
        param(
            [Parameter(Mandatory = $true)]
            [String]
                $InputString
        )

        $buffer = [System.Text.UnicodeEncoding]::UTF8.GetBytes($InputString)
        $this.ComputeHash($buffer)

        return $this.OutString
    }

    Add-Member -InputObject $provider -MemberType ScriptProperty -Name OutString -Value {
        $hash = $this.Hash | %{"{0:x2}" -f $_}
        return ($hash -join "")
    }

    return $provider
}