[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidLongLines', '', Justification = 'Contains long links.')]
[CmdletBinding()]
param()

$baseName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)
$script:PSModuleInfo = Test-ModuleManifest -Path "$PSScriptRoot\$baseName.psd1"
$script:PSModuleInfo | Format-List | Out-String -Stream | ForEach-Object { Write-Debug $_ }
$scriptName = $script:PSModuleInfo.Name
Write-Debug "[$scriptName] - Importing module"
#region    Data importer
Write-Debug "[$scriptName] - [data] - Processing folder"
$dataFolder = (Join-Path $PSScriptRoot 'data')
Write-Debug "[$scriptName] - [data] - [$dataFolder]"
Get-ChildItem -Path "$dataFolder" -Recurse -Force -Include '*.psd1' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Debug "[$scriptName] - [data] - [$($_.BaseName)] - Importing"
    New-Variable -Name $_.BaseName -Value (Import-PowerShellDataFile -Path $_.FullName) -Force
    Write-Debug "[$scriptName] - [data] - [$($_.BaseName)] - Done"
}
Write-Debug "[$scriptName] - [data] - Done"
#endregion Data importer
#region    [init]
Write-Debug "[$scriptName] - [init] - Processing folder"
#region    [init] - [initializer]
Write-Debug "[$scriptName] - [init] - [initializer] - Importing"
Write-Verbose '-------------------------------'
Write-Verbose '---  THIS IS AN INITIALIZER ---'
Write-Verbose '-------------------------------'
Write-Debug "[$scriptName] - [init] - [initializer] - Done"
#endregion [init] - [initializer]
Write-Debug "[$scriptName] - [init] - Done"
#endregion [init]
#region    [classes] - [private]
Write-Debug "[$scriptName] - [classes] - [private] - Processing folder"
#region    [classes] - [private] - [SecretWriter]
Write-Debug "[$scriptName] - [classes] - [private] - [SecretWriter] - Importing"
class SecretWriter {
    [string] $Alias
    [string] $Name
    [string] $Secret

    SecretWriter([string] $alias, [string] $name, [string] $secret) {
        $this.Alias = $alias
        $this.Name = $name
        $this.Secret = $secret
    }

    [string] GetAlias() {
        return $this.Alias
    }
}
Write-Debug "[$scriptName] - [classes] - [private] - [SecretWriter] - Done"
#endregion [classes] - [private] - [SecretWriter]
Write-Debug "[$scriptName] - [classes] - [private] - Done"
#endregion [classes] - [private]
#region    [classes] - [public]
Write-Debug "[$scriptName] - [classes] - [public] - Processing folder"
#region    [classes] - [public] - [Book]
Write-Debug "[$scriptName] - [classes] - [public] - [Book] - Importing"
class Book {
    # Class properties
    [string]   $Title
    [string]   $Author
    [string]   $Synopsis
    [string]   $Publisher
    [datetime] $PublishDate
    [int]      $PageCount
    [string[]] $Tags
    # Default constructor
    Book() { $this.Init(@{}) }
    # Convenience constructor from hashtable
    Book([hashtable]$Properties) { $this.Init($Properties) }
    # Common constructor for title and author
    Book([string]$Title, [string]$Author) {
        $this.Init(@{Title = $Title; Author = $Author })
    }
    # Shared initializer method
    [void] Init([hashtable]$Properties) {
        foreach ($Property in $Properties.Keys) {
            $this.$Property = $Properties.$Property
        }
    }
    # Method to calculate reading time as 2 minutes per page
    [timespan] GetReadingTime() {
        if ($this.PageCount -le 0) {
            throw 'Unable to determine reading time from page count.'
        }
        $Minutes = $this.PageCount * 2
        return [timespan]::new(0, $Minutes, 0)
    }
    # Method to calculate how long ago a book was published
    [timespan] GetPublishedAge() {
        if (
            $null -eq $this.PublishDate -or
            $this.PublishDate -eq [datetime]::MinValue
        ) { throw 'PublishDate not defined' }

        return (Get-Date) - $this.PublishDate
    }
    # Method to return a string representation of the book
    [string] ToString() {
        return "$($this.Title) by $($this.Author) ($($this.PublishDate.Year))"
    }
}

class BookList {
    # Static property to hold the list of books
    static [System.Collections.Generic.List[Book]] $Books
    # Static method to initialize the list of books. Called in the other
    # static methods to avoid needing to explicit initialize the value.
    static [void] Initialize() { [BookList]::Initialize($false) }
    static [bool] Initialize([bool]$force) {
        if ([BookList]::Books.Count -gt 0 -and -not $force) {
            return $false
        }

        [BookList]::Books = [System.Collections.Generic.List[Book]]::new()

        return $true
    }
    # Ensure a book is valid for the list.
    static [void] Validate([book]$Book) {
        $Prefix = @(
            'Book validation failed: Book must be defined with the Title,'
            'Author, and PublishDate properties, but'
        ) -join ' '
        if ($null -eq $Book) { throw "$Prefix was null" }
        if ([string]::IsNullOrEmpty($Book.Title)) {
            throw "$Prefix Title wasn't defined"
        }
        if ([string]::IsNullOrEmpty($Book.Author)) {
            throw "$Prefix Author wasn't defined"
        }
        if ([datetime]::MinValue -eq $Book.PublishDate) {
            throw "$Prefix PublishDate wasn't defined"
        }
    }
    # Static methods to manage the list of books.
    # Add a book if it's not already in the list.
    static [void] Add([Book]$Book) {
        [BookList]::Initialize()
        [BookList]::Validate($Book)
        if ([BookList]::Books.Contains($Book)) {
            throw "Book '$Book' already in list"
        }

        $FindPredicate = {
            param([Book]$b)

            $b.Title -eq $Book.Title -and
            $b.Author -eq $Book.Author -and
            $b.PublishDate -eq $Book.PublishDate
        }.GetNewClosure()
        if ([BookList]::Books.Find($FindPredicate)) {
            throw "Book '$Book' already in list"
        }

        [BookList]::Books.Add($Book)
    }
    # Clear the list of books.
    static [void] Clear() {
        [BookList]::Initialize()
        [BookList]::Books.Clear()
    }
    # Find a specific book using a filtering scriptblock.
    static [Book] Find([scriptblock]$Predicate) {
        [BookList]::Initialize()
        return [BookList]::Books.Find($Predicate)
    }
    # Find every book matching the filtering scriptblock.
    static [Book[]] FindAll([scriptblock]$Predicate) {
        [BookList]::Initialize()
        return [BookList]::Books.FindAll($Predicate)
    }
    # Remove a specific book.
    static [void] Remove([Book]$Book) {
        [BookList]::Initialize()
        [BookList]::Books.Remove($Book)
    }
    # Remove a book by property value.
    static [void] RemoveBy([string]$Property, [string]$Value) {
        [BookList]::Initialize()
        $Index = [BookList]::Books.FindIndex({
                param($b)
                $b.$Property -eq $Value
            }.GetNewClosure())
        if ($Index -ge 0) {
            [BookList]::Books.RemoveAt($Index)
        }
    }
}

enum Binding {
    Hardcover
    Paperback
    EBook
}

enum Genre {
    Mystery
    Thriller
    Romance
    ScienceFiction
    Fantasy
    Horror
}
Write-Debug "[$scriptName] - [classes] - [public] - [Book] - Done"
#endregion [classes] - [public] - [Book]
Write-Debug "[$scriptName] - [classes] - [public] - Done"
#endregion [classes] - [public]
#region    [functions] - [private]
Write-Debug "[$scriptName] - [functions] - [private] - Processing folder"
#region    [functions] - [private] - [Get-InternalPSModule]
Write-Debug "[$scriptName] - [functions] - [private] - [Get-InternalPSModule] - Importing"
function Get-InternalPSModule {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"
    #>
    [CmdletBinding()]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Output "Hello, $Name!"
}
Write-Debug "[$scriptName] - [functions] - [private] - [Get-InternalPSModule] - Done"
#endregion [functions] - [private] - [Get-InternalPSModule]
#region    [functions] - [private] - [Set-InternalPSModule]
Write-Debug "[$scriptName] - [functions] - [private] - [Set-InternalPSModule] - Importing"
function Set-InternalPSModule {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function',
        Justification = 'Reason for suppressing'
    )]
    [CmdletBinding()]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Output "Hello, $Name!"
}
Write-Debug "[$scriptName] - [functions] - [private] - [Set-InternalPSModule] - Done"
#endregion [functions] - [private] - [Set-InternalPSModule]
Write-Debug "[$scriptName] - [functions] - [private] - Done"
#endregion [functions] - [private]
#region    [functions] - [public]
Write-Debug "[$scriptName] - [functions] - [public] - Processing folder"
#region    [functions] - [public] - [Test-PSModuleTest]
Write-Debug "[$scriptName] - [functions] - [public] - [Test-PSModuleTest] - Importing"
function Test-PSModuleTest {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"
    #>
    [CmdletBinding()]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Output "Hello, $Name!"
}
Write-Debug "[$scriptName] - [functions] - [public] - [Test-PSModuleTest] - Done"
#endregion [functions] - [public] - [Test-PSModuleTest]
#region    [functions] - [public] - [PSModule]
Write-Debug "[$scriptName] - [functions] - [public] - [PSModule] - Processing folder"
#region    [functions] - [public] - [PSModule] - [Get-PSModuleTest]
Write-Debug "[$scriptName] - [functions] - [public] - [PSModule] - [Get-PSModuleTest] - Importing"
#Requires -Modules Utilities
#Requires -Modules @{ ModuleName = 'PSSemVer'; RequiredVersion = '1.0.0' }
#Requires -Modules @{ ModuleName = 'DynamicParams'; ModuleVersion = '1.1.8' }
#Requires -Modules @{ ModuleName = 'Store'; ModuleVersion = '0.3.1' }

function Get-PSModuleTest {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"
    #>
    [CmdletBinding()]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Output "Hello, $Name!"
}
Write-Debug "[$scriptName] - [functions] - [public] - [PSModule] - [Get-PSModuleTest] - Done"
#endregion [functions] - [public] - [PSModule] - [Get-PSModuleTest]
#region    [functions] - [public] - [PSModule] - [New-PSModuleTest]
Write-Debug "[$scriptName] - [functions] - [public] - [PSModule] - [New-PSModuleTest] - Importing"
#Requires -Modules @{ModuleName='PSSemVer'; ModuleVersion='1.0'}

function New-PSModuleTest {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"

        .NOTES
        Testing if a module can have a [Markdown based link](https://example.com).
        !"#¤%&/()=?`´^¨*'-_+§½{[]}<>|@£$€¥¢:;.,"
        \[This is a test\]
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function',
        Justification = 'Reason for suppressing'
    )]
    [Alias('New-PSModuleTestAlias1')]
    [Alias('New-PSModuleTestAlias2')]
    [CmdletBinding()]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Output "Hello, $Name!"
}

New-Alias New-PSModuleTestAlias3 New-PSModuleTest
New-Alias -Name New-PSModuleTestAlias4 -Value New-PSModuleTest


Set-Alias New-PSModuleTestAlias5 New-PSModuleTest
Write-Debug "[$scriptName] - [functions] - [public] - [PSModule] - [New-PSModuleTest] - Done"
#endregion [functions] - [public] - [PSModule] - [New-PSModuleTest]
Write-Debug "[$scriptName] - [functions] - [public] - [PSModule] - Done"
#endregion [functions] - [public] - [PSModule]
#region    [functions] - [public] - [SomethingElse]
Write-Debug "[$scriptName] - [functions] - [public] - [SomethingElse] - Processing folder"
#region    [functions] - [public] - [SomethingElse] - [Set-PSModuleTest]
Write-Debug "[$scriptName] - [functions] - [public] - [SomethingElse] - [Set-PSModuleTest] - Importing"
function Set-PSModuleTest {
    <#
        .SYNOPSIS
        Performs tests on a module.

        .EXAMPLE
        Test-PSModule -Name 'World'

        "Hello, World!"
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        'PSUseShouldProcessForStateChangingFunctions', '', Scope = 'Function',
        Justification = 'Reason for suppressing'
    )]
    [CmdletBinding()]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Output "Hello, $Name!"
}
Write-Debug "[$scriptName] - [functions] - [public] - [SomethingElse] - [Set-PSModuleTest] - Done"
#endregion [functions] - [public] - [SomethingElse] - [Set-PSModuleTest]
Write-Debug "[$scriptName] - [functions] - [public] - [SomethingElse] - Done"
#endregion [functions] - [public] - [SomethingElse]
Write-Debug "[$scriptName] - [functions] - [public] - Done"
#endregion [functions] - [public]
#region    [variables] - [private]
Write-Debug "[$scriptName] - [variables] - [private] - Processing folder"
#region    [variables] - [private] - [PrivateVariables]
Write-Debug "[$scriptName] - [variables] - [private] - [PrivateVariables] - Importing"
$script:HabitablePlanets = @(
    @{
        Name      = 'Earth'
        Mass      = 5.97
        Diameter  = 12756
        DayLength = 24.0
    },
    @{
        Name      = 'Mars'
        Mass      = 0.642
        Diameter  = 6792
        DayLength = 24.7
    },
    @{
        Name      = 'Proxima Centauri b'
        Mass      = 1.17
        Diameter  = 11449
        DayLength = 5.15
    },
    @{
        Name      = 'Kepler-442b'
        Mass      = 2.34
        Diameter  = 11349
        DayLength = 5.7
    },
    @{
        Name      = 'Kepler-452b'
        Mass      = 5.0
        Diameter  = 17340
        DayLength = 20.0
    }
)

$script:InhabitedPlanets = @(
    @{
        Name      = 'Earth'
        Mass      = 5.97
        Diameter  = 12756
        DayLength = 24.0
    },
    @{
        Name      = 'Mars'
        Mass      = 0.642
        Diameter  = 6792
        DayLength = 24.7
    }
)
Write-Debug "[$scriptName] - [variables] - [private] - [PrivateVariables] - Done"
#endregion [variables] - [private] - [PrivateVariables]
Write-Debug "[$scriptName] - [variables] - [private] - Done"
#endregion [variables] - [private]
#region    [variables] - [public]
Write-Debug "[$scriptName] - [variables] - [public] - Processing folder"
#region    [variables] - [public] - [Moons]
Write-Debug "[$scriptName] - [variables] - [public] - [Moons] - Importing"
$script:Moons = @(
    @{
        Planet = 'Earth'
        Name   = 'Moon'
    }
)
Write-Debug "[$scriptName] - [variables] - [public] - [Moons] - Done"
#endregion [variables] - [public] - [Moons]
#region    [variables] - [public] - [Planets]
Write-Debug "[$scriptName] - [variables] - [public] - [Planets] - Importing"
$script:Planets = @(
    @{
        Name      = 'Mercury'
        Mass      = 0.330
        Diameter  = 4879
        DayLength = 4222.6
    },
    @{
        Name      = 'Venus'
        Mass      = 4.87
        Diameter  = 12104
        DayLength = 2802.0
    },
    @{
        Name      = 'Earth'
        Mass      = 5.97
        Diameter  = 12756
        DayLength = 24.0
    }
)
Write-Debug "[$scriptName] - [variables] - [public] - [Planets] - Done"
#endregion [variables] - [public] - [Planets]
#region    [variables] - [public] - [SolarSystems]
Write-Debug "[$scriptName] - [variables] - [public] - [SolarSystems] - Importing"
$script:SolarSystems = @(
    @{
        Name    = 'Solar System'
        Planets = $script:Planets
        Moons   = $script:Moons
    },
    @{
        Name    = 'Alpha Centauri'
        Planets = @()
        Moons   = @()
    },
    @{
        Name    = 'Sirius'
        Planets = @()
        Moons   = @()
    }
)
Write-Debug "[$scriptName] - [variables] - [public] - [SolarSystems] - Done"
#endregion [variables] - [public] - [SolarSystems]
Write-Debug "[$scriptName] - [variables] - [public] - Done"
#endregion [variables] - [public]
#region    [finally]
Write-Debug "[$scriptName] - [finally] - Importing"
Write-Verbose '------------------------------'
Write-Verbose '---  THIS IS A LAST LOADER ---'
Write-Verbose '------------------------------'
Write-Debug "[$scriptName] - [finally] - Done"
#endregion [finally]
#region    Class exporter
# Get the internal TypeAccelerators class to use its static methods.
$TypeAcceleratorsClass = [psobject].Assembly.GetType(
    'System.Management.Automation.TypeAccelerators'
)
# Ensure none of the types would clobber an existing type accelerator.
# If a type accelerator with the same name exists, throw an exception.
$ExistingTypeAccelerators = $TypeAcceleratorsClass::Get
# Define the types to export with type accelerators.
$ExportableEnums = @(
    [Binding]
    [Genre]
)
$ExportableEnums | ForEach-Object { Write-Verbose "Exporting enum '$($_.FullName)'." }
foreach ($Type in $ExportableEnums) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        Write-Verbose "Enum already exists [$($Type.FullName)]. Skipping."
    } else {
        Write-Verbose "Importing enum '$Type'."
        $TypeAcceleratorsClass::Add($Type.FullName, $Type)
    }
}
$ExportableClasses = @(
    [Book]
    [BookList]
)
$ExportableClasses | ForEach-Object { Write-Verbose "Exporting class '$($_.FullName)'." }
foreach ($Type in $ExportableClasses) {
    if ($Type.FullName -in $ExistingTypeAccelerators.Keys) {
        Write-Verbose "Class already exists [$($Type.FullName)]. Skipping."
    } else {
        Write-Verbose "Importing class '$Type'."
        $TypeAcceleratorsClass::Add($Type.FullName, $Type)
    }
}

# Remove type accelerators when the module is removed.
$MyInvocation.MyCommand.ScriptBlock.Module.OnRemove = {
    foreach ($Type in ($ExportableEnums + $ExportableClasses)) {
        $TypeAcceleratorsClass::Remove($Type.FullName)
    }
}.GetNewClosure()
#endregion Class exporter
#region    Member exporter
$exports = @{
    Alias    = '*'
    Cmdlet   = ''
    Function = @(
        'Get-PSModuleTest'
        'New-PSModuleTest'
        'Set-PSModuleTest'
        'Test-PSModuleTest'
    )
    Variable = @(
        'Moons'
        'Planets'
        'SolarSystems'
    )
}
Export-ModuleMember @exports
#endregion Member exporter

