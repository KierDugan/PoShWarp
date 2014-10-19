##
## Unit tests for the PoShWarp PowerShell module.
## URL: https://github.com/DuFace/PoShWarp
## Copyright (c) 2014 Kier Dugan
##

## Prerequisite modules --------------------------------------------------------
Import-Module .\PoShWarp.psm1 -Force


## Enviroment setup ------------------------------------------------------------
$TestRoot       = "Testing"
$TestWarpMap    = "WarpMap.xml"
$TestWarpMapMT  = "EmptyWarpMap.xml"
$TestFakeDir    = "FakeDirectory"
$TestStructure  = @(
    @{ "Name"="proja"; "Path"="ProjectA"; "Exists"=$true;  "Entry"=$true  },
    @{ "Name"="projb"; "Path"="ProjectB"; "Exists"=$true;  "Entry"=$true  },
    @{ "Name"="projc"; "Path"="ProjectC"; "Exists"=$false; "Entry"=$true  },
    @{ "Name"="projd"; "Path"="ProjectB"; "Exists"=$true;  "Entry"=$true  }
    @{ "Name"="proje"; "Path"="ProjectE"; "Exists"=$true;  "Entry"=$false }
)
$TestRootDir    = Join-Path (Get-Location) $TestRoot
$TestOldMap     = $env:POSHWARP_MAPFILE

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
function RestoreWarpMapFromBackup {
    $warpMapFilename = "$env:POSHWARP_MAPFILE"

    if (Test-Path $warpMapFilename -Type Leaf) {
        Remove-Item $warpMapFilename
    }

    Copy-Item "$warpMapFilename.backup" $warpMapFilename
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
    $xml.Save("$xmlFilename.backup")

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
    $xml.Save("$xmlFilename.backup")

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
                $name, $path = $locations[$i].Name, $locations[$i].Path
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
            foreach ($entry in $entries) {
                $entry.Path | Should Be $curLocation
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

Describe "New-WarpLocation" {
    # Get the full path for the test directory
    $fakeLocation    = Join-Path $TestRootDir $TestFakeDir
    $testLocation    = GetFullPathForMapping "proje"
    $initialLocation = (Get-Location).Path

    Context "when warp-map exists and does not contain current directory" {
        Push-Location .
        Set-Location $testLocation

        $location = New-WarpLocation "proje" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        Pop-Location

        $entryAfter = Get-WarpLocations | where { $_.Name -eq "proje" }

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should return new location" {
            $location.Name | Should Be "proje"
            $location.Path | Should Be $testLocation
        }
        It "should create location pointing to the path" {
            $entryAfter.Path | Should Be $testLocation
        }
    }

    Context "when warp-map exists and contains current directory" {
        Push-Location .
        Set-Location $testLocation

        $location = New-WarpLocation "proje" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        Pop-Location

        RestoreWarpMapFromBackup

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should not return a new location" {
            $location | Should BeNullOrEmpty
        }
    }

    Context "when warp-map exists but is empty" {
        UseEmptyWarpMap

        $sizeBefore = (Get-Item $env:POSHWARP_MAPFILE).Length

        Push-Location .
        Set-Location $testLocation

        $location = New-WarpLocation "proje" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        Pop-Location

        $sizeAfter  = (Get-Item $env:POSHWARP_MAPFILE).Length
        $entryAfter = Get-WarpLocations | where { $_.Name -eq "proje" }

        RestoreWarpMapFromBackup
        UseNormalWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should return new location" {
            $location.Name | Should Be "proje"
            $location.Path | Should Be $testLocation
        }
        It "should have increase warp-map size" {
            ($sizeBefore -lt $sizeAfter) | Should Be $true
        }
        It "should create location pointing to the path" {
            $entryAfter.Path | Should Be $testLocation
        }
    }

    Context "when warp-map does not exist" {
        HideWarpMap

        $existBefore = Test-Path $env:POSHWARP_MAPFILE -Type Leaf

        Push-Location .
        Set-Location $testLocation

        $location = New-WarpLocation "proje" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        Pop-Location

        $existAfter = Test-Path $env:POSHWARP_MAPFILE -Type Leaf
        $sizeAfter  = (Get-Item $env:POSHWARP_MAPFILE).Length
        $entryAfter = Get-WarpLocations | where { $_.Name -eq "proje" }

        if ($existAfter) {
            Remove-Item $env:POSHWARP_MAPFILE
        }

        RestoreWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should return new location" {
            $location.Name | Should Be "proje"
            $location.Path | Should Be $testLocation
        }
        It "should have no warp-map before" {
            $existBefore | Should Be $false
        }
        It "should have created a warp-map" {
            $existAfter | Should Be $true
        }
        It "should create location pointing to the path" {
            $entryAfter.Path | Should Be $testLocation
        }
    }

    Context "when warp-map exists and does not contain given path" {
        $location = New-WarpLocation "proje" $testLocation `
            -ErrorVariable result -ErrorAction SilentlyContinue

        $entryAfter = Get-WarpLocations | where { $_.Name -eq "proje" }

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should return new location" {
            $location.Name | Should Be "proje"
            $location.Path | Should Be $testLocation
        }
        It "should create location pointing to the path" {
            $entryAfter.Path | Should Be $testLocation
        }
    }

    Context "when warp-map exists and contains given path" {
        $location = New-WarpLocation "proje" $testLocation `
            -ErrorVariable result -ErrorAction SilentlyContinue

        RestoreWarpMapFromBackup

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should not return a new location" {
            $location | Should BeNullOrEmpty
        }
    }

    Context "when warp-map exists but is empty and command given path arg" {
        UseEmptyWarpMap

        $sizeBefore = (Get-Item $env:POSHWARP_MAPFILE).Length

        $location = New-WarpLocation "proje" $testLocation `
            -ErrorVariable result -ErrorAction SilentlyContinue

        $sizeAfter  = (Get-Item $env:POSHWARP_MAPFILE).Length
        $entryAfter = Get-WarpLocations | where { $_.Name -eq "proje" }

        RestoreWarpMapFromBackup
        UseNormalWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should return new location" {
            $location.Name | Should Be "proje"
            $location.Path | Should Be $testLocation
        }
        It "should have increase warp-map size" {
            ($sizeBefore -lt $sizeAfter) | Should Be $true
        }
        It "should create location pointing to the path" {
            $entryAfter.Path | Should Be $testLocation
        }
    }

    Context "when warp-map does not exist and command given path arg" {
        HideWarpMap

        $existBefore = Test-Path $env:POSHWARP_MAPFILE -Type Leaf

        $location = New-WarpLocation "proje" $testLocation `
            -ErrorVariable result -ErrorAction SilentlyContinue

        $existAfter = Test-Path $env:POSHWARP_MAPFILE -Type Leaf
        $sizeAfter  = (Get-Item $env:POSHWARP_MAPFILE).Length
        $entryAfter = Get-WarpLocations | where { $_.Name -eq "proje" }

        if ($existAfter) {
            Remove-Item $env:POSHWARP_MAPFILE
        }

        RestoreWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should return new location" {
            $location.Name | Should Be "proje"
            $location.Path | Should Be $testLocation
        }
        It "should have no warp-map before" {
            $existBefore | Should Be $false
        }
        It "should have created a warp-map" {
            $existAfter | Should Be $true
        }
        It "should create location pointing to the path" {
            $entryAfter.Path | Should Be $testLocation
        }
    }

    Context "when warp-map exists; doesn't contain path; path doesn't exist" {
        $location = New-WarpLocation "proje" $fakeLocation `
            -ErrorVariable result -ErrorAction SilentlyContinue

        $entryAfter = Get-WarpLocations | where { $_.Name -eq "proje" }

        It "should produce an error" {
            $result | Should Not BeNullOrEmpty
        }
        It "should not return new location" {
            $location | Should BeNullOrEmpty
        }
        It "should not create location pointing to the path" {
            $entryAfter | Should BeNullOrEmpty
        }
    }

    Context "when warp-map exists; is empty; path doesn't exist" {
        UseEmptyWarpMap

        $sizeBefore = (Get-Item $env:POSHWARP_MAPFILE).Length

        $location = New-WarpLocation "proje" $fakeLocation `
            -ErrorVariable result -ErrorAction SilentlyContinue

        $sizeAfter  = (Get-Item $env:POSHWARP_MAPFILE).Length
        $entryAfter = Get-WarpLocations | where { $_.Name -eq "proje" }

        RestoreWarpMapFromBackup
        UseNormalWarpMap

        It "should produce an error" {
            $result | Should Not BeNullOrEmpty
        }
        It "should not return new location" {
            $location | Should BeNullOrEmpty
        }
        It "should not have increased warp-map size" {
            $sizeBefore | Should Be $sizeAfter
        }
        It "should not create location pointing to the path" {
            $entryAfter | Should BeNullOrEmpty
        }
    }

    Context "when warp-map doesn't exist; path doesn't exist" {
        HideWarpMap

        $existBefore = Test-Path $env:POSHWARP_MAPFILE -Type Leaf

        $location = New-WarpLocation "proje" $fakeLocation `
            -ErrorVariable result -ErrorAction SilentlyContinue

        $existAfter = Test-Path $env:POSHWARP_MAPFILE -Type Leaf
        $sizeAfter  = (Get-Item $env:POSHWARP_MAPFILE).Length
        $entryAfter = Get-WarpLocations | where { $_.Name -eq "proje" }

        if ($existAfter) {
            Remove-Item $env:POSHWARP_MAPFILE
        }

        RestoreWarpMap

        It "should produce an error" {
            $result | Should Not BeNullOrEmpty
        }
        It "should not return new location" {
            $location | Should BeNullOrEmpty
        }
        It "should have no warp-map before" {
            $existBefore | Should Be $false
        }
        It "should have created a warp-map" {
            $existAfter | Should Be $true
        }
        It "should not create location pointing to the path" {
            $entryAfter | Should BeNullOrEmpty
        }
    }
}

Describe "Remove-WarpLocation" {
    Context "when warp-map exists and named entry also exists" {
        $testLocation = GetFullPathForMapping "projb"

        $beforeLocation = Get-WarpLocations | where { $_.Name -eq "projb" }

        Remove-WarpLocation -WarpName "projb" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        $afterLocation = Get-WarpLocations | where { $_.Name -eq "projb" }

        RestoreWarpMapFromBackup

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should have a valid entry before removal" {
            $beforeLocation.Name | Should Be "projb"
            $beforeLocation.Path | Should Be $testLocation
        }
        It "should have removed the entry from the warp-map" {
            $afterLocation | Should BeNullOrEmpty
        }
    }

    Context "when warp-map exists and named entry does not" {
        $beforeRemove = Get-WarpLocations

        Remove-WarpLocation -WarpName "incorrect" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        $afterRemove = Get-WarpLocations

        It "should produce an error" {
            $result | Should Not BeNullOrEmpty
        }
        It "should not have affected the warp-map" {
            $beforeRemove.Length | Should Not Be 0
            $afterRemove.Length  | Should Not Be 0

            $beforeRemove.Length | Should Be $afterRemove.Length

            for ($i = 0; $i -lt $beforeRemove.Length; $i++) {
                $beforeRemove[$i].Name | Should Be $afterRemove[$i].Name
                $beforeRemove[$i].Path | Should Be $afterRemove[$i].Path
            }
        }
    }

    Context "when warp-map exists and directory entry also exists" {
        $testLocation = GetFullPathForMapping "projb"

        $beforeRemove = Get-WarpLocations | where { $_.Path -eq $testLocation }

        Push-Location .
        Set-LocationFromWarp "projb"

        Remove-WarpLocation -ErrorVariable result -ErrorAction SilentlyContinue

        Pop-Location

        $afterRemove = Get-WarpLocations | where { $_.Path -eq $testLocation }

        RestoreWarpMapFromBackup

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should have valid entries before removal" {
            $beforeRemove | Should Not BeNullOrEmpty

            foreach ($entry in $beforeRemove) {
                $entry.Path | Should Be $testLocation
            }
        }
        It "should have removed all entries from the warp-map" {
            $afterRemove | Should BeNullOrEmpty
        }
    }

    Context "when warp-map exists and directory entry does not" {
        $beforeRemove = Get-WarpLocations

        Remove-WarpLocation -ErrorVariable result -ErrorAction SilentlyContinue

        $afterRemove = Get-WarpLocations

        It "should produce an error" {
            $result | Should Not BeNullOrEmpty
        }
        It "should not have affected the warp-map" {
            $beforeRemove.Length | Should Not Be 0
            $afterRemove.Length  | Should Not Be 0

            $beforeRemove.Length | Should Be $afterRemove.Length

            for ($i = 0; $i -lt $beforeRemove.Length; $i++) {
                $beforeRemove[$i].Name | Should Be $afterRemove[$i].Name
                $beforeRemove[$i].Path | Should Be $afterRemove[$i].Path
            }
        }
    }

    Context "when warp-map exists but is empty" {
        UseEmptyWarpMap

        $beforeRemove = Get-WarpLocations

        Remove-WarpLocation "test" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        $afterRemove = Get-WarpLocations

        UseNormalWarpMap

        It "should produce an error" {
            $result | Should Not BeNullOrEmpty
        }
        It "should not have affected warp-map" {
            $beforeRemove | Should BeNullOrEmpty
            $afterRemove | Should BeNullOrEmpty
        }
    }

    Context "when warp-map does not exist" {
        HideWarpMap

        $existsBefore = Test-Path $env:POSHWARP_MAPFILE -PathType Leaf

        Remove-WarpLocation "test" -ErrorVariable result `
            -ErrorAction SilentlyContinue

        $existsAfter = Test-Path $env:POSHWARP_MAPFILE -PathType Leaf

        RestoreWarpMap

        It "should produce an error" {
            $result | Should Not BeNullOrEmpty
        }
        It "should not have a warp-map before command" {
            $existsBefore | Should Be $false
        }
        It "should not have created a new warp-map" {
            $existsAfter | Should Be $false
        }
    }
}

Describe "Repair-WarpLocations" {
    Context "when warp-map exists and contains dangling entries" {
        $beforeLocations = @(Get-WarpLocations)

        Repair-WarpLocations -ErrorVariable result -ErrorAction SilentlyContinue

        $afterLocations = @(Get-WarpLocations)

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should have dangling warp-map entries before invocation" {
            $TestStructure | where { -not $_.Exists } | foreach {
                $path    = Join-Path $TestRootDir $_.Path
                $entries = $beforeLocations | where { $_.Path -eq $path }
                $entries | Should Not BeNullOrEmpty
            }
        }
        It "should not have dangling entires after invocation" {
            $TestStructure | where { -not $_.Exists } | foreach {
                $path    = Join-Path $TestRootDir $_.Path
                $entries = $afterLocations | where { $_.Path -eq $path }
                $entries | Should BeNullOrEmpty
            }
        }
    }

    Context "when warp-map exists and does not contain dangling entries" {
        $beforeLocations = @(Get-WarpLocations)

        Repair-WarpLocations -ErrorVariable result -ErrorAction SilentlyContinue

        $afterLocations = @(Get-WarpLocations)

        RestoreWarpMapFromBackup

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should not have changed the warp-map" {
            $afterLocations.Length | Should Be $beforeLocations.Length

            for ($i = 0; $i -lt $beforeLocations.Length; $i++) {
                $beforeLocations.Name | Should Be $afterLocations.Name
                $beforeLocations.Path | Should Be $afterLocations.Path
            }
        }
    }

    Context "when warp-map exists but is empty" {
        UseEmptyWarpMap

        $beforeLocations = @(Get-WarpLocations)

        Repair-WarpLocations -ErrorVariable result -ErrorAction SilentlyContinue

        $afterLocations = @(Get-WarpLocations)

        UseNormalWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should have empty warp-map before" {
            $beforeLocations.Length | Should Be 0
        }
        It "should have empty warp-map after" {
            $afterLocations.Length | Should Be 0
        }
    }

    Context "when warp-map does not exist" {
        HideWarpMap

        $existsBefore = Test-Path -Path $env:POSHWARP_MAPFILE -PathType Leaf

        Repair-WarpLocations -ErrorVariable result -ErrorAction SilentlyContinue

        $existsAfter = Test-Path -Path $env:POSHWARP_MAPFILE -PathType Leaf

        RestoreWarpMap

        It "should produce no error" {
            $result | Should BeNullOrEmpty
        }
        It "should not have a warp-map before" {
            $existsBefore | Should Be $false
        }
        It "should not have created an empty warp-map" {
            $existsAfter | Should Be $false
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
