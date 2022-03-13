PoShWarp
========

PoShWarp is a PowerShell port of the [wd](https://github.com/mfaerevaag/wd)
plugin for zsh.  It aims to offer the same convenience that `wd` offers in zsh
alongside some idiomatic PowerShell commands.

Installation
------------

If you have [PsGet](http://psget.net/) installed, you can simply execute:

```PowerShell
Install-Module PoShWarp
```

Otherwise, for a manual installation:

1.  Create a `PoShWarp` directory in your modules folder.  You can determine
    where this is by looking at the `PSModulePath` environment variable.
2.  Download `PoShWarp.psm1` and place it in the newly created `PoShWarp`
    directory.
3.  PoShWarp should automatically load next time you start PowerShell.  If this
    does not happen, add `Import-Module PoShWarp` to your `$profile`.

Motivation
----------

Our systems contain projects strewn all over the place.  We aim to keep things
organised but something will always disrupt our careful organisation, and it
becomes far to easy to forget where all these things end up living.  With
PoShWarp, this problem becomes far more manageable because these commonly-used
locations can be given names.  

Let's say we have a folder that contains a set of projects:

```
E:\Projects> Get-ChildItem


    Directory: Microsoft.PowerShell.Core\FileSystem::E:\Projects


Mode           LastWriteTime       Length Name
----           -------------       ------ ----
d----    24/11/2014    17:11        <DIR> CunningEmbeddedProject
d----    24/11/2014    17:11        <DIR> SuperAwesomeProject
d----    24/11/2014    17:11        <DIR> TrendyWebProject
```

We can can create *warp-names* for two of these projects like so:

```
E:\Projects> cd .\SuperAwesomeProject\
E:\Projects\SuperAwesomeProject
E:\Projects\SuperAwesomeProject> New-WarpLocation awesome

Name                Path
----                ----
awesome             E:\Projects\SuperAwesomeProject


E:\Projects\SuperAwesomeProject> New-WarpLocation trendy ..\TrendyWebProject

Name                Path
----                ----
trendy              E:\Projects\TrendyWebProject
```

These two bindings now appear in a system-wide *warp-map* that exists in the
same directory as your `$profile` by default.  You can relocate the warp-map by
setting the `POSHWARP_MAPFILE` environment variable to point where you would
prefer it to be.  Now our sample warp-map looks like:

```
E:\> Get-WarpLocation

Name                Path
----                ----
awesome             E:\Projects\SuperAwesomeProject
trendy              E:\Projects\TrendyWebProject
```

Now we can enter into either project directory without needing to remember the
path:

```
C:\> Select-WarpLocation awesome
E:\Projects\SuperAwesomeProject> Select-WarpLocation trendy
E:\Projects\TrendyWebProject>
```

Granted, this example is rather simple but visiting directories frequently can
get annoying quite swiftly.  Especially if those paths are particularly deep or
if they contain confusing or similar sub-directories.  With PoShWarp, `cd`-ing
to that arcane directory can now be replaced with `Select-WarpLocation myplace`
or the far simpler `wd myplace`.


Commands
========

<a id="Select-WarpLocation"></a>
## Select-WarpLocation

```
Select-WarpLocation [-WarpName] <String> [-PassThru] [<CommonParameters>]
```

Searches the warp-map for the specified entry and sets the location accordingly.

### Description
Select-WarpLocation will search the active warp-map file for the entry with the
given name and attempt to `Set-Location` to the corresponding path.  An error
will be raised if no entry with the given name is found, of if the named entry
exists but points to a non-existent directory.

### Parameters
| Parameter | Type   | Description                                             |
| :-------- | :----: | :------------------------------------------------------ |
| WarpName  | String | Entry name to search for in the warp-map.               |
| PassThru  | Switch | Return the new directory object after changing into it. |

<a id="New-WarpLocation"></a>
## New-WarpLocation

```
New-WarpLocation [-WarpName] <String> [[-Path] <String>] [<CommonParameters>]
```

Creates a new entry in the current warp-map.

### Description
A new entry will be added to the warp-map currently active using either the
current or specific directory path.  If the does not exist, no entry will be
created.  A warp-map XML file with be created if one does not already exist.

### Parameters
| Parameter | Type   | Description                                                     |
| :-------- | :----: | :-------------------------------------------------------------- |
| WarpName  | String | Name for the new warp-map entry.                                |
| Path      | String | Path to assign to WarpName.  Defaults to the current directory. |

<a id="Remove-WarpLocation"></a>
## Remove-WarpLocation

```
Remove-WarpLocation [[-WarpName] <String>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

Removes the specified entry from the active warp-map.

### Description
Searches the active warp-map for the named entry and then removes it.  The
current directory will be used as a search term if no name is given.  All
entries that meet the criterion will be removed.  An empty warp-map file will
not be created if one does not already exist.

### Parameters
| Parameter | Type   | Description                        |
| :-------- | :----: | :--------------------------------- |
| WarpName  | String | Warp-map entry name to search for. |

<a id="Get-WarpLocation"></a>
## Get-WarpLocation

```
Get-WarpLocation [[-WarpName] <String>] [[-Path] <String>] [<CommonParameters>]
```

Gets the entries from the warp-map, optionally filtering by name or path.

### Description
Get-WarpLocation will return all the entries from the warp-map that meet the
given search criteria.  Zero or more entries will be returned.  Both a warp-name
and a path may be specified, and both must match to return any results.  No
error will be raised if the query results in no matches.

### Parameters
| Parameter | Type   | Description                         |
| :-------- | :----: | :---------------------------------- |
| WarpName  | String | Name to search for in the warp-map. |
| Path      | String | Path to search for in the warp-map. |

<a id="Repair-WarpMap"></a>
## Repair-WarpMap

```
Repair-WarpMap [-WhatIf] [-Confirm] [<CommonParameters>]
```

Removes all invalid directory references from the warp-map.

### Description
Over time, a living warp-map can retain entries pointing to directories that no
longer exist.  Repair-WarpMap checks every entry in the warp-map and removes any
that reference a directory that has been deleted.  Multiple entries pointing to
the same directory will remain unchanged provided that they point to a directory
that still exists.

<a id="wd"></a>
## wd

```
wd [-WarpName <String>] [-Path <String>] [-PassThru] [[-argv] <Object>] [-WhatIf] [-Confirm] [<CommonParameters>]
```

Provides all warp-map functionality under a single utility command.

### Description
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

### Parameters
| Parameter | Type   | Description                                                                                   |
| :-------- | :----: | :-------------------------------------------------------------------------------------------- |
| WarpName  | String | Name for the warp-map entry.                                                                  |
| Path      | String | Path for the warp-map entry.                                                                  |
| PassThru  | Switch | Only used when selecting a warp location: flag propagates directory to `Select-WarpLocation`. |



<a id="warpmap"></a>
The Warp-map File
=================

All warp-locations created by [`New-WarpLocation`](#New-WarpLocation) are saved
in an XML file called the *warp-map*.  By default, this file is named
`WarpMap.xml` and will be created in the same directory as your `$profile`, but
it can be placed elsewhere using the `POSHWARP_MAPFILE` environment variable. 
The commands in the example given above would lead to the following warp-map:

```XML
<?xml version="1.0"?>
<WarpMap>
  <Location Name="awesome" Path="E:\Projects\SuperAwesomeProject" />
  <Location Name="trendy" Path="E:\Projects\TrendyWebProject" />
</WarpMap>
```

The format is largely self-explanatory and has been kept deliberately simple. 
Warp-maps may be edited by hand and may include custom XML if you wish to use
the file for multiple purposes.  There is no guarantee that the additional
elements will be left undamaged, but PoShWarp commands have been designed to
modify only the elements that are necessary.  Of course, there is a risk that a
future version of PoShWarp may include additional XML that may conflict with any
custom elements that have been added.


Testing
=======

Every exported PoShWarp command includes a corresponding set of tests that can
be executed using [Pester](https://github.com/pester/Pester).  Running the 
`Invoke-Pester` command from the source directory will load `PoShWarp.Tests.ps1`
and create an environment for the tests to operate in.  This environment
includes a warp-map and a suitable directory structure which will be removed as
part of the tear-down.


Licence
=======

The MIT License (MIT)

Copyright (c) 2014-2015 Kier Dugan

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
