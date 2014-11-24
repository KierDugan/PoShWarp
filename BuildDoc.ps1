##
## PoShWarp README documentation generator
## URL: https://github.com/DuFace/PoShWarp
## Copyright (c) 2014 Kier Dugan
##

## Table Descriptors -----------------------------------------------------------
function HeaderCell {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [String]
        $Name,

        [Parameter(Mandatory=$false)]
        [Switch]
        $Centre,

        [Parameter(Mandatory=$false)]
        [Switch]
        $Right
    )

    process {
        # Decode alignment
        $align = "Left"
        if ($Centre) {
            $align = "Centre"
        } elseif ($Right) {
            $align = "Right"
        }

        # Create a new object to return
        $cell = New-Object System.Object
        $cell | Add-Member -Type NoteProperty -Name "Name" -Value $Name
        $cell | Add-Member -Type NoteProperty -Name "Alignment" -Value $align
        $cell
    }
}

function Header {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ScriptBlock]
        $Cells
    )

    process {
        # Create a new object
        $row = New-Object System.Object
        $row | Add-Member -Type NoteProperty -Name "Type" -Value "Header"
        $row | Add-Member -Type NoteProperty -Name "Cells" -Value (&$Cells)
        $row
    }
}

function Cell {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [String]
        $Content
    )

    process {
        $content
    }
}

function Row {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ScriptBlock]
        $Cells
    )

    process {
        # Create a new object
        $row = New-Object System.Object
        $row | Add-Member -Type NoteProperty -Name "Type" -Value "Row"
        $row | Add-Member -Type NoteProperty -Name "Cells" -Value (&$Cells)
        $row
    }
}

function Describe-Table {
    [CmdletBinding()]
    param(
        [Parameter(Position=0, Mandatory=$true)]
        [ScriptBlock]
        $Content
    )

    process {
        $table = New-Object System.Object
        $rows  = @()

        # Build the table
        &$Content | foreach {
            $row = $_
            switch ($row.Type) {
                "Header" {
                    $table | Add-Member -Type NoteProperty -Name "Columns" `
                        -Value $row.Cells
                }

                "Row" {
                    $rows += ,$row.Cells
                }
            }
        }

        # Add the rows
        $table | Add-Member -Type NoteProperty -Name "Rows" -Value $rows

        # Return the constructed table
        return $table
    }
}


## Table Builder Functions -----------------------------------------------------
function ColumnCharWidths($table) {
    # Calculate the maximum length of the cell in each row of the data
    $lengths = for ($i = 0; $i -lt $table.Columns.Length; $i++) {
        ($table.Rows | foreach { $_[$i].Length } |
            Measure-Object -Maximum).Maximum
    }

    # Factor in the headings
    for ($i = 0; $i -lt $table.Columns.Length; $i++) {
        [Math]::Max($lengths[$i], $table.Columns[$i].Name.Length)
    }
}

function MakeHeaderDelimeter($width, $alignment) {
    # Make the actual bunch of dashes
    $delim = '-' * $width

    # Replace the end points
    if ($alignment -eq 'Left' -or $alignment -eq 'Centre') {
        $delim = ':' + $delim.Substring(1, $width - 1)
    }

    if ($alignment -eq 'Centre' -or $alignment -eq 'Right') {
        $delim = $delim.Substring(0, $width - 1) + ':'
    }

    # Return the delimeter
    return $delim
}

function MakeRow($cells, $widths) {
    $formattedCells = for ($i = 0; $i -lt $cells.Length; $i++) {
        [string]::Format("{0,-$($widths[$i])}", $cells[$i])
    }
    return "| $($formattedCells -join ' | ') |"
}

function Format-MarkdownTable {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Table
    )

    process {
        $mdtable  = @()

        # Compute the largest string in each column
        $lengths = ColumnCharWidths $table

        # Add the header row
        $mdtable += MakeRow ($table.Columns | foreach { $_.Name }) $lengths

        # Add the delimeter row
        $delims = for ($i = 0; $i -lt $table.Columns.Length; $i++) {
            MakeHeaderDelimeter $lengths[$i] $table.Columns[$i].Alignment
        }
        $mdtable += MakeRow $delims $lengths

        # Add each content row
        foreach ($row in $table.Rows) {
            $mdtable += MakeRow $row $lengths
        }

        return $mdtable
    }
}


## Get-Help Parsers ------------------------------------------------------------

function ConvertCommandHelp($help) {
    $doc = ""

    # Open with an anchor, sub-heading, and synopsis
    $doc += "<a id=`"$($help.Name)`"></a>`r`n"
    $doc += "## $($help.Name)`r`n"
    $doc += "`r`n"
    $doc += '```' + "`r`n"
    $doc += ($help.syntax | Out-String).Trim() + "`r`n"
    $doc += '```' + "`r`n"
    $doc += "`r`n"
    $doc += ($help.Synopsis | Out-String).Trim() + "`r`n"
    $doc += "`r`n"

    # Add detail
    $doc += "### Description`r`n"
    $doc += ($help.description | Out-String).Trim() + "`r`n"

    # Add parameters
    $paramTable = Describe-Table {
        Header {
            HeaderCell "Parameter"
            HeaderCell "Type" -Centre
            HeaderCell "Description"
        }

        foreach ($param in $help.parameters.parameter) {
            $paramName = ($param.name | Out-String).Trim()
            $paramType = ($param.type.name | Out-String).Trim()
            $paramDesc = ($param.description | Out-String).Trim()

            if ($paramType -eq 'SwitchParameter') {
                $paramType = 'Switch'
            }

            if ($paramDesc) {
                # Sanitise the description
                $paramDesc = ($paramDesc -split "`r?`n" |
                              foreach { $_.Trim() }) -join ' '

                Row {
                    Cell $paramName
                    Cell $paramType
                    Cell $paramDesc
                }
            }
        }
    }
    if ($paramTable.Rows.Length) {
        $doc += "`r`n### Parameters`r`n"
        $doc += (Format-MarkdownTable $paramTable) -join "`r`n"
        $doc += "`r`n"
    }

    return $doc
}


## Actual documentation generator ----------------------------------------------

# Import the current version of the module
Import-Module .\PoShWarp.psm1 -Force

# Load the template file
$srcdoc = Get-Content .\README.md.in

# Magic callback that does the munging
$callback = {
    ConvertCommandHelp (Get-Help $args[0].Groups[1].Value)
}
$re = [Regex]"{%\s*([\w\-]+)\s*%}"

# Generate the readme
$srcdoc | foreach { $re.Replace($_, $callback) } > README.md

