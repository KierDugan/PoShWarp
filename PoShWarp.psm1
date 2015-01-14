##
## PoShWarp: a PowerShell port of the `wd` zshell script.
## URL: https://github.com/DuFace/PoShWarp
## Copyright (c) 2014 Kier Dugan
##

## Utility functions -----------------------------------------------------------
function GetWarpMapFilename() {
    if (-not ($env:POSHWARP_MAPFILE -eq $null)) {
        return $env:POSHWARP_MAPFILE
    } else {
        return "$((Get-Item $profile).Directory.FullName)\WarpMap.xml"
    }
}

function WarpMapExists() {
    return Test-Path (GetWarpMapFilename) -PathType Leaf
}

function OpenWarpMap() {
    $xml = New-Object XML

    if (WarpMapExists) {
        $fn = GetWarpMapFilename
        $xml.Load($fn)
    } else {
        # Initialise the empty document
        $decl = $xml.CreateXmlDeclaration("1.0", $null, $null)
        $root = $xml.CreateElement("WarpMap")

        $xml.InsertBefore($decl, $xml.DocumentElement) | Out-Null
        $xml.InsertBefore($root, $xml.DocumentElement) | Out-Null
    }

    return $xml
}

function CloseWarpMap($xml) {
    $fn = GetWarpMapFilename
    $xml.Save($fn)
}

function FindWarpLocations($xml, $name) {
    return $xml.WarpMap.Location | where { $_.Name -eq $name }
}

function ConvertElementsToObjects($elems) {
    if ($elems) {
        return $elems | foreach {
            $obj = New-Object System.Object
            $obj | Add-Member -Type NoteProperty -Name "Name" -Value $_.Name
            $obj | Add-Member -Type NoteProperty -Name "Path" -Value $_.Path
            $obj
        }
    }
}

function SelectFirstNonNull() {
    return $args | where { $_ } | Select-Object -First 1
}


## Commands --------------------------------------------------------------------

<#
.SYNOPSIS

Searches the warp-map for the specified entry and sets the location accordingly.


.DESCRIPTION

Select-WarpLocation will search the active warp-map file for the entry with the
given name and attempt to `Set-Location` to the corresponding path.  An error
will be raised if no entry with the given name is found, of if the named entry
exists but points to a non-existent directory.


.PARAMETER WarpName

Entry name to search for in the warp-map.


.PARAMETER PassThru

Return the new directory object after changing into it.


.LINK

https://github.com/DuFace/PoShWarp#warpmap
https://github.com/DuFace/PoShWarp#Select-WarpLocation
#>
function Select-WarpLocation {
    [CmdletBinding()]
    param(
          [Parameter(Mandatory=$true, ValueFromPipeline=$true)]
          [String]
          $WarpName,

          [Parameter(Mandatory=$false)]
          [Switch]
          $PassThru = $false
    )

    process {
        # Open the XML warp-map
        Write-Verbose "Opening warp-map file: $(GetWarpMapFilename)"
        $xml = OpenWarpMap
        
        # Find all warp entries with the given name
        $entry = FindWarpLocations $xml $WarpName | Select-Object -First 1
        if (-not $entry) {
            Write-Error "No entry for $WarpName exists in warp-map!"
            return
        }

        # Verify the directory exists
        $name, $path = $entry.Name, $entry.Path
        if (-not (Test-Path -Path $path -PathType Container)) {
            Write-Error ("Entry '$name' points to directory '$path' which " +
                         "does not exist!")
            return
        }

        # Attempt to go to the warp location
        return Set-Location -Path $path -PassThru:$PassThru
    }
}

<#
.SYNOPSIS

Creates a new entry in the current warp-map.


.DESCRIPTION

A new entry will be added to the warp-map currently active using either the
current or specific directory path.  If the does not exist, no entry will be
created.  A warp-map XML file with be created if one does not already exist.


.PARAMETER WarpName

Name for the new warp-map entry.


.PARAMETER Path

Path to assign to WarpName.  Defaults to the current directory.


.LINK

https://github.com/DuFace/PoShWarp#warpmap
https://github.com/DuFace/PoShWarp#New-WarpLocation
#>
function New-WarpLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true, ValueFromPipeline=$false)]
        [String]
        $WarpName,

        [Parameter(Mandatory=$false, ValueFromPipeline=$false)]
        [String]
        $Path = '.'
    )

    begin {
        # Open the XML warp-map
        Write-Verbose "Opening warp-map file: $(GetWarpMapFilename)"
        $xml = OpenWarpMap
        $warpMapElem = $xml.SelectSingleNode("WarpMap")
    }

    process {
        # Target path *must* exist
        if (-not (Test-Path -Path $Path -PathType Container)) {
            Write-Error "Target path must exist."
            return
        }

        # Expand the path
        $Path = (Get-Item $Path).FullName

        # Find the first reference to the wapr name so that this can be added
        # before it, thereby overriding it.
        $exstingEntry = $xml.WarpMap.Location | 
            where { $_.Name -eq $WarpName} | Select-Object -First 1

        # Construct a new XML element to hold the mapping
        $newElem = $xml.CreateElement("Location")
        $newElem.SetAttribute("Name", $WarpName)
        $newElem.SetAttribute("Path", $Path)

        # If this warp name has not been used before, add the element to the end
        # of the document
        if (-not $exstingEntry) {
            $dirElem = $warpMapElem.AppendChild($newElem)
        } else {
            # Prevent duplication
            if (-not ($exstingEntry.Path -eq $Path)) {
                $dirElem = $warpMapElem.InsertBefore($newElem, $exstingEntry)
            }
        }

        return ConvertElementsToObjects $dirElem
    }

    end {
        # Save the changes to the warp-map
        Write-Verbose "Saving warp-map file: $(GetWarpMapFilename)"
        CloseWarpMap $xml
    }
}

<#
.SYNOPSIS

Removes the specified entry from the active warp-map.


.DESCRIPTION

Searches the active warp-map for the named entry and then removes it.  The
current directory will be used as a search term if no name is given.  All
entries that meet the criterion will be removed.  An empty warp-map file will
not be created if one does not already exist.


.PARAMETER WarpName

Warp-map entry name to search for.


.LINK

https://github.com/DuFace/PoShWarp#Remove-WarpLocation
#>
function Remove-WarpLocation {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Low")]
    param(
          [Parameter(Mandatory=$false, ValueFromPipeline=$true)]
          [String]
          $WarpName
    )

    begin {
        # Open the XML warp-map
        Write-Verbose "Opening warp-map file: $(GetWarpMapFilename)"
        $xml = OpenWarpMap
        $warpMapElem = $xml.SelectSingleNode("WarpMap")
    }

    process {
        # Find all elements to delete
        if ($WarpName) {
            $elemsToRemove = $warpMapElem.Location |
                where { $_.Name -eq $WarpName }
        } else {
            $curPath = (Get-Location).Path
            $elemsToRemove = $warpMapElem.Location |
                where { $_.Path -eq $curPath }
        }

        # Bail if there's no work to do
        if (-not $elemsToRemove) {
            if ($WarpName) {
                Write-Error "$WarpName does not exist in warp-map."
            } else {
                Write-Error "There is no entry for this directory in warp-map."
            }
            
            return
        }

        # Get confirmation from user
        if ($elemsToRemove.Length) {
            $prompt = "Remove $($elemsToRemove.Count) entries from warp-map."
        } else {
            $prompt = "Remove 1 entry from warp-map."
        }
        if ($PSCmdlet.ShouldProcess($prompt)) {
            # Remove the elements from the WarpMap tag
            foreach ($elem in $elemsToRemove) {
                $warpMapElem.RemoveChild($elem) | Out-Null
            }
            
            # Save the changes to the warp-map
            Write-Verbose "Saving warp-map file: $(GetWarpMapFilename)"
            CloseWarpMap $xml
        }
    }
}

<#
.SYNOPSIS

Gets the entries from the warp-map, optionally filtering by name or path.


.DESCRIPTION

Get-WarpLocation will return all the entries from the warp-map that meet the
given search criteria.  Zero or more entries will be returned.  Both a warp-name
and a path may be specified, and both must match to return any results.  No
error will be raised if the query results in no matches.


.PARAMETER WarpName

Name to search for in the warp-map.


.PARAMETER Path

Path to search for in the warp-map.


.LINK

https://github.com/DuFace/PoShWarp#Get-WarpLocation
#>
function Get-WarpLocation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [String]
        $WarpName,

        [Parameter(Mandatory=$false)]
        [String]
        $Path
    )

    process {
        # Actually check the warp-map even exists first
        if (WarpMapExists) {
            # Open the warp-map
            Write-Verbose "Opening warp-map file: $(GetWarpMapFilename)"
            $xml = OpenWarpMap

            # Build the warp name filter 
            if ($WarpName) {
                $nameFilter = { $_.Name -eq $WarpName }
            } else {
                $nameFilter = { $true }
            }

            # Build the path filter
            if ($Path) {
                # Expand out to full path if, and only if, it exists
                if (Test-Path -Path $Path -PathType Container) {
                    $Path = (Get-Item $Path).FullName
                    Write-Verbose "Path expanded to $Path."
                }

                # Make the actual filter block
                $pathFilter = { $_.Path -eq $Path }
            } else {
                $pathFilter = { $true }
            }

            # Apply the filters to the Location elements
            $entries = $xml.WarpMap.Location | where {
                (&$nameFilter) -and (&$pathFilter)
            }

            # Return all the locations in the map
            return ConvertElementsToObjects $entries
        }
    }
}

<#
.SYNOPSIS

Removes all invalid directory references from the warp-map.


.DESCRIPTION

Over time, a living warp-map can retain entries pointing to directories that no
longer exist.  Repair-WarpMap checks every entry in the warp-map and removes any
that reference a directory that has been deleted.  Multiple entries pointing to
the same directory will remain unchanged provided that they point to a directory
that still exists.


.LINK

https://github.com/DuFace/PoShWarp#Repair-WarpMap
#>
function Repair-WarpMap {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Low")]
    param()

    process {
        # Open the warp-map
        Write-Verbose "Opening warp-map file: $(GetWarpMapFilename)"
        $xml = OpenWarpMap
        $warpMapElem = $xml.SelectSingleNode("WarpMap")

        # Find all entries that point to missing directories
        if ($warpMapElem.Location) {
            $danglers = $warpMapElem.Location | where {
                -not (Test-Path -Path $_.Path -PathType Container)
            }
        }

        # Bail early if there's nothing to remove
        if (-not $danglers) {
            Write-Verbose "No bad entries in warp-map."
        } else {
            # Build the message to confirm with user
            if ($danglers.Length) {
                $prompt = "Remove $($danglers.Count) entries from warp-map."
            } else {
                $prompt = "Remove 1 entry from warp-map."
            }

            # Actually do it...
            if ($PSCmdlet.ShouldProcess($prompt)) {
                # Remove the elements from the WarpMap tag
                foreach ($dangler in $danglers) {
                    $warpMapElem.RemoveChild($dangler) | Out-Null
                }
                
                # Save the changes to the warp-map
                Write-Verbose "Saving warp-map file: $(GetWarpMapFilename)"
                CloseWarpMap $xml
            }
        }
    }
}

<#
.SYNOPSIS

Provides all warp-map functionality under a single utility command.


.DESCRIPTION

`wd` is a clone of the command offered in the eponymous zsh package.  It
provides an interface to all of the other commands in PoShWarp:

    wd add, wd new      -> New-WarpLocation
    wd rm, wd del       -> Remove-WarpLocation
    wd ls, wd list      -> Get-WarpLocation
    wd clean, wd repair -> Repair-WarpMap
    wd help             -> Get-Help wd

`wd` also supports `wd show <WarpName>` which lists all entries that share the
given name.  This has been provided as a convenience as it simply maps onto 
`Get-WarpLocation`, and also for compatibility with the original `wd` command.

`wd` treats the first argument as a warp-map entry name if it does not match one
of the sub-commands.  In this instance `wd <WarpName>` maps onto
`Select-WarpLocation -WarpName <WarpName>`.

As `wd` exists for compatibility with the zsh package, it primarily relies on
positional arguments as follows: `wd <sub-command> <WarpName> <Path>`.  However,
named parameters are also supported to make good use of PowerShell.


.PARAMETER WarpName

Name for the warp-map entry.


.PARAMETER Path

Path for the warp-map entry.


.PARAMETER PassThru

Only used when selecting a warp location: flag propagates directory to 
`Select-WarpLocation`.


.LINK

https://github.com/DuFace/PoShWarp#wd
#>
function wd {
    [CmdletBinding(SupportsShouldProcess=$true, ConfirmImpact="Low")]
    param(
        [Parameter(Mandatory=$false)]
        [String]
        $WarpName,

        [Parameter(Mandatory=$false)]
        [String]
        $Path,

        [Parameter(Mandatory=$false)]
        [Switch]
        $PassThru,

        [Parameter(Position=0, ValueFromRemainingArguments=$true)]
        $argv
    )

    process {
        # Make sure arguments have been specified
        if ($argv.Length -eq 0) {
            Write-Error "No sub-command or warp-name specified."
            return
        }

        # Unpack the arguments
        $warpName = SelectFirstNonNull $WarpName $argv[1]
        $path = SelectFirstNonNull $Path $argv[2] '.'

        # Redirect to appropriate command
        switch -regex ($argv[0]) {
            "add|new" {
                return New-WarpLocation -WarpName $warpName -Path $path
            }

            "rm|del" {
                return Remove-WarpLocation -WarpName $warpName
            }

            "ls|list" {
                return Get-WarpLocation
            }

            "show" {
                return Get-WarpLocation -WarpName $warpName
            }

            "clean|repair" {
                return Repair-WarpMap
            }

            "help" {
                return Get-Help wd
            }

            default {
                $warpName = SelectFirstNonNull $WarpName $argv[0]
                return Select-WarpLocation -WarpName $warpName `
                    -PassThru:$PassThru
            }
        }
    }
}


## Simple tab expansion for the wd utility function ----------------------------
$script:wdSubCommands = @("add", "new", "rm", "del", "ls", "list", "show",
                          "clean", "repair", "help")  # sub-commands of wd

if (Test-Path Function:\TabExpansion) {
    Rename-Item Function:\TabExpansion TabExpansionOld
}

function TabExpansion([string] $line, [string] $lastWord) {
    if ($line -match "^wd\s+($($script:wdSubCommands -join '|'))\s+(.*)") {
        $command = $Matches[1]
        $param   = $Matches[2]

        if ($command -match "rm|del|show") {
            $options = Get-WarpLocation | foreach { $_.Name } | Sort-Object
            return $options | where { $_ -like "$param*" }
        }
    } elseif ($line -match "^wd\s+(.*)") {
        $params  = $Matches[1]
        $options = ($script:wdSubCommands | Sort-Object) + `
            (Get-WarpLocation | foreach { $_.Name } | Sort-Object)

        if ($params -match "([a-zA-Z_]\w*)\s*(.*)") {
            $subCommand = $Matches[1]
            $options = $options | where { $_ -like "$subCommand*" }
        }

        return $options
    } 

    if (Test-Path Function:\TabExpansionOld) {
        return TabExpansionOld $line $lastWord
    }
}


## Advanced tab expansion for WarpName -----------------------------------------
if (-not $global:KJDCompleteOptions) {
    $global:KJDCompleteOptions = @{
        CustomArgumentCompleters = @{};
        NativeArgumentCompleters = @{}
    }
}

# Hook into the global completion function
$LookupCode = @'
End
{
    # KJDCompletionLookup
    if ($options -eq $null)
    {
        $options = $global:KJDCompleteOptions
    }
    else
    {
        $options += $global:KJDCompleteOptions
    }

'@

if (-not ($function:TabExpansion2 -match 'KJDCompletionLookup')) {
    $function:TabExpansion2 = $function:TabExpansion2 `
        -replace 'End\r\n{', $LookupCode
}

# Register the actual completion function
$global:KJDCompleteOptions['CustomArgumentCompleters']['WarpName'] = {
    param(
        $commandName,
        $parameterName,
        $wordToComplete,
        $commandAst,
        $fakeBoundParameter
    )

    # Correctly resolve the command name
    if ((Get-Command $commandName).CommandType -eq 'Alias') {
        $commandName = (Get-Command $commandName).ResolvedCommandName
    }

    # Make sure it's a PoShWarp command
    if ($commandName -match "(Remove|Get|Select)-WarpLocation|wd") {
        # Return a list of warp locations filtered appropriately
        $options = Get-WarpLocation | foreach { $_.Name }

        if ($wordToComplete) {
            $options = $options | where { $_ -like "$wordToComplete*" }
        }

        return $options | Sort-Object
    }
}


## Modules Exports -------------------------------------------------------------
Export-ModuleMember -Function Select-WarpLocation
Export-ModuleMember -Function New-WarpLocation
Export-ModuleMember -Function Remove-WarpLocation
Export-ModuleMember -Function Get-WarpLocation
Export-ModuleMember -Function Repair-WarpMap
Export-ModuleMember -Function wd

Export-ModuleMember -Function TabExpansion
