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
        return "$(Get-ProfileDirectory)\WarpMap.xml"
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


## Commands --------------------------------------------------------------------

function Set-LocationFromWarp {
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

function Repair-WarpLocations {
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


## Modules Exports -------------------------------------------------------------
Export-ModuleMember Set-LocationFromWarp
Export-ModuleMember New-WarpLocation
Export-ModuleMember Remove-WarpLocation
Export-ModuleMember Get-WarpLocation
Export-ModuleMember Repair-WarpLocations
