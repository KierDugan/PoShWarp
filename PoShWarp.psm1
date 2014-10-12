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

        $xml.AppendChild($decl)
        $xml.AppendChild($root)
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

function ConvertElementsToHash($elems) {
    return $elems | foreach {
        @{
            "Name" = $_.Name;
            "Path" = $_.Path
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

    begin {
        # Open the XML warp-map
        Write-Verbose "Opening warp-map file: $(GetWarpMapFilename)"
        $xml = OpenWarpMap
    }

    process {
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

    end {
        # Save the changes to the warp-map
        Write-Verbose "Saving warp-map file: $(GetWarpMapFilename)"
        CloseWarpMap $xml
    }
}

function Add-WarpLocation {
    [CmdletBinding()]
    param(
    )

    process {

    }
}

function Remove-WarpLocation {
    [CmdletBinding()]
    param(
    )

    process {

    }
}

function Get-WarpLocations {
    [CmdletBinding()]
    param(
    )

    process {

    }
}

function Get-WarpLocationNames {
    [CmdletBinding()]
    param(
    )

    process {

    }
}

function Repair-WarpLocations {
    [CmdletBinding()]
    param(
    )

    process {

    }
}


## Modules Exports -------------------------------------------------------------
Export-ModuleMember Set-LocationFromWarp
Export-ModuleMember Add-WarpLocation
Export-ModuleMember Remove-WarpLocation
Export-ModuleMember Get-WarpLocations
Export-ModuleMember Get-WarpLocationNames
Export-ModuleMember Repair-WarpLocations
