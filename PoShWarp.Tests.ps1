##
## Unit tests for the PoShWarp PowerShell module.
## URL: https://github.com/DuFace/PoShWarp
## Copyright (c) 2014 Kier Dugan
##

## Prerequisite modules --------------------------------------------------------
Import-Module .\PoShWarp.psm1 -Force


## Enviroment setup ------------------------------------------------------------
$TestRoot      = "Testing"
$TestWarpMap   = "WarpMap.xml"
$TestWarpMapMT = "EmptyWarpMap.xml"
$TestStructure = @(
    @{ "Name"="proja"; "Path"="ProjectA"; "Exists"=$true,  "Entry"=$true  },
    @{ "Name"="projb"; "Path"="ProjectB"; "Exists"=$true,  "Entry"=$true  },
    @{ "Name"="projc"; "Path"="ProjectC"; "Exists"=$false, "Entry"=$true  },
    @{ "Name"="projd"; "Path"="ProjectB"; "Exists"=$false, "Entry"=$true  }
    @{ "Name"="proje"; "Path"="ProjectE"; "Exists"=$true,  "Entry"=$false }
)
$TestRootDir = Join-Path (Get-Location) $TestRoot
$TestOldMap  = $env:POSHWARP_MAPFILE

# Helper functions
function GetFullPathForMapping($warpName) {
    $entry = $TestStructure | where { $_.Name -eq $warpName }
    return (Join-Path $TestRootDir $entry.Path)
}
function WriteStatusMsg($msg) {
    Write-Host -ForegroundColor DarkGray $msg
}
function HideWarpMap {
    if (Test-Path $env:POSHWARP_MAPFILE -Type Leaf) {
        Rename-Item $env:POSHWARP_MAPFILE "$env:POSHWARP_MAPFILE.hidden"
    }
}
function RestoreWarpMap {
    if (Test-Path "$env:POSHWARP_MAPFILE.hidden" -Type Leaf) {
        Rename-Item "$env:POSHWARP_MAPFILE.hidden" $env:POSHWARP_MAPFILE
    }
}
function UseEmptyWarpMap {
    $env:POSHWARP_MAPFILE = Join-Path $TestRootDir $TestWarpMapMT
}
function UseNormalWarpMap {
    $env:POSHWARP_MAPFILE = Join-Path $TestRootDir $TestWarpMap
}

# Actual environment set-up
WriteStatusMsg "Creating directory structure for tests"
$TestStructure | where { $_.Exists } | foreach {
    $path = Join-Path $TestRoot $_.Path
    if (-not (Test-Path -Path $path -PathType Container)) {
        WriteStatusMsg "  creating $path..."
        New-Item -Path $path -Type Container | Out-Null
    } else {
        WriteStatusMsg "  skipping $path..."
    }
}

function CreateWarpMap {
    $xml = New-Object XML

    # Add the standard XML declaration
    $decl = $xml.CreateXmlDeclaration("1.0", $null, $null)
    $xml.InsertBefore($decl, $xml.DocumentElement) | Out-Null

    # Add the root node
    $rootNode = $xml.CreateElement("WarpMap")
    $xml.InsertBefore($rootNode, $xml.DocumentElement) | Out-Null

    # Save an empty warp-map
    $xmlFilename = Join-Path $TestRootDir $TestWarpMapMT
    WriteStatusMsg "  saving empty warp-map as $xmlFilename"
    $xml.Save($xmlFilename)

    # Add all the mappings specified above
    $TestStructure | where { $_.Entry } | foreach {
        WriteStatusMsg "  adding mapping $($_.Name):$($_.Path)"

        $mapping = $xml.CreateElement("Location")
        $mapping.SetAttribute("Name", $_.Name)
        $mapping.SetAttribute("Path", (Join-Path $TestRootDir $_.Path))
        $rootNode.AppendChild($mapping) | Out-Null
    }

    # Save the file
    $xmlFilename = Join-Path $TestRootDir $TestWarpMap
    WriteStatusMsg "  saving warp-map as $xmlFilename"
    $xml.Save($xmlFilename)

    # Set the environment variable to point at this new file
    $env:POSHWARP_MAPFILE = $xmlFilename
}
WriteStatusMsg "Creating warp-map for tests"
CreateWarpMap

Write-Host ' '


## Unit tests ------------------------------------------------------------------
Describe "Set-LocationFromWarp" {
    # Store the current directory to return to it
    Push-Location .

    Context "when WarpName is not in the warp-map" {
        Set-LocationFromWarp -WarpName "Invalid Name" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        It "should fail with error message" {
            $result | Should Not BeNullOrEmpty
        }
    }

    Context "when WarpName points to non-existant directory" {
        Set-LocationFromWarp -WarpName "projc" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        It "should fail with error message" {
            $result | Should Not BeNullOrEmpty
        }
    }

    Context "when warp-map does not exist" {
        HideWarpMap
        Set-LocationFromWarp -WarpName "proja" -ErrorVariable result `
            -ErrorAction SilentlyContinue
        RestoreWarpMap

        It "should fail with error message" {
            $result | Should Not BeNullOrEmpty
        }
    }

    Context "when warp-map exists but is empty" {
        $prelocation = (Get-Location).Path

        UseEmptyWarpMap
        Set-LocationFromWarp -WarpName "proja" -ErrorVariable result `
            -ErrorAction SilentlyContinue
        UseNormalWarpMap

        $postlocation = (Get-Location).Path

        It "should fail with error message" {
            $result | Should Not BeNullOrEmpty
        }
        It "should not have changed directory" {
            $prelocation | Should Be $postlocation
        }
    }

    Context "when WarpName points to valid directory" {
        $mapName  = "proja"
        $expected = GetFullPathForMapping $mapName

        Set-LocationFromWarp -WarpName $mapName -ErrorVariable result
        $actual = Get-Location

        It "should change current location correctly" {
            $actual | Should Be $expected
        }
        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
    }

    Context "when WarpName points to valid directory and PassThru is enabled" {
        $mapName  = "projb"
        $expected = GetFullPathForMapping $mapName

        $actual = Set-LocationFromWarp -WarpName $mapName -PassThru `
            -ErrorVariable result -ErrorAction SilentlyContinue

        It "should change current location correctly" {
            $actual | Should Be $expected
        }
        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
    }

    # Return to original directory
    Pop-Location
}

Describe "Get-WarpLocations" {
    Context "when warp-map is correctly populated" {
        $locations = Get-WarpLocations -ErrorVariable result `
            -ErrorAction SilentlyContinue

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should match the test warp-map exactly" {
            for ($i = 0; $i -lt $locations.Length; $i++) {
                $name, $path = $locations.Keys[$i], $locations.Values[$i]
                $mapEntry    = $TestStructure[$i]

                $name | Should BeExactly $mapEntry.Name
                $path | Should BeExactly (Join-Path $TestRootDir $mapEntry.Path)
            }
        }
    }

    Context "when warp-map does not exist" {
        HideWarpMap
        $locations = Get-WarpLocations -ErrorVariable result `
            -ErrorAction SilentlyContinue
        RestoreWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should return an empty map" {
            $locations | Should BeNullOrEmpty
        }
    }

    Context "when warp-map exists but is empty" {
        UseEmptyWarpMap
        $locations = Get-WarpLocations -ErrorVariable result `
            -ErrorAction SilentlyContinue
        UseNormalWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should return an empty map" {
            $locations | Should BeNullOrEmpty
        }
    }
}

Describe "Get-WarpLocationNames" {
    Context "when warp-map is correct and current directory has mappings" {
        Push-Location .
        Set-LocationFromWarp projb

        $curLocation = (Get-Location).Path
        $entries = Get-WarpLocationNames -ErrorVariable result `
            -ErrorAction SilentlyContinue

        Pop-Location

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should have returned a list of entries" {
            foreach ($name in $entries.Keys) {
                $entries.$name | Should Be $curLocation
            }
        }
    }

    Context "when warp-map is correct and current directory has no mappings" {
        Push-Location .
        Set-Location $TestRootDir

        $entries = Get-WarpLocationNames -ErrorVariable result `
            -ErrorAction SilentlyContinue

        Pop-Location

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should list no entries" {
            $entries | Should BeNullOrEmpty
        }
    }

    Context "when warp-map exists but is empty" {
        UseEmptyWarpMap
        $entries = Get-WarpLocationNames -ErrorVariable result `
            -ErrorAction SilentlyContinue
        UseNormalWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should list no entries" {
            $entries | Should BeNullOrEmpty
        }
    }

    Context "when warp-map is missing" {
        HideWarpMap
        $entries = Get-WarpLocationNames -ErrorVariable result `
            -ErrorAction SilentlyContinue
        RestoreWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should list no entries" {
            $entries | Should BeNullOrEmpty
        }
    }
}


## Enviroment teardown ---------------------------------------------------------
WriteStatusMsg "`nTeardown:"

WriteStatusMsg "  removing directory structure"
Remove-Item $TestRoot -Recurse

WriteStatusMsg "  resetting warp-map environment variable"
$env:POSHWARP_MAPFILE = $TestOldMap

Write-Host ' '
