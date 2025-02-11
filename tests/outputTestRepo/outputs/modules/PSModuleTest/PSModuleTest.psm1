[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidLongLines', '', Justification = 'Contains long links.')]
[CmdletBinding()]
param()

$scriptName = $MyInvocation.MyCommand.Name
Write-Verbose "[$scriptName] Importing module"

#region - Data import
Write-Verbose "[$scriptName] - [data] - Processing folder"
$dataFolder = (Join-Path $PSScriptRoot 'data')
Write-Verbose "[$scriptName] - [data] - [$dataFolder]"
Get-ChildItem -Path "$dataFolder" -Recurse -Force -Include '*.psd1' -ErrorAction SilentlyContinue | ForEach-Object {
    Write-Verbose "[$scriptName] - [data] - [$($_.Name)] - Importing"
    New-Variable -Name $_.BaseName -Value (Import-PowerShellDataFile -Path $_.FullName) -Force
    Write-Verbose "[$scriptName] - [data] - [$($_.Name)] - Done"
}

Write-Verbose "[$scriptName] - [data] - Done"
#endregion - Data import

#region - From /init
Write-Verbose "[$scriptName] - [/init] - Processing folder"

#region - From /init/initializer.ps1
Write-Verbose "[$scriptName] - [/init/initializer.ps1] - Importing"

Write-Verbose '-------------------------------'
Write-Verbose '---  THIS IS AN INITIALIZER ---'
Write-Verbose '-------------------------------'

Write-Verbose "[$scriptName] - [/init/initializer.ps1] - Done"
#endregion - From /init/initializer.ps1

Write-Verbose "[$scriptName] - [/init] - Done"
#endregion - From /init

#region - From /classes
Write-Verbose "[$scriptName] - [/classes] - Processing folder"

#region - From /classes/Book.ps1
Write-Verbose "[$scriptName] - [/classes/Book.ps1] - Importing"

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

Write-Verbose "[$scriptName] - [/classes/Book.ps1] - Done"
#endregion - From /classes/Book.ps1
#region - From /classes/BookList.ps1
Write-Verbose "[$scriptName] - [/classes/BookList.ps1] - Importing"

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

Write-Verbose "[$scriptName] - [/classes/BookList.ps1] - Done"
#endregion - From /classes/BookList.ps1

Write-Verbose "[$scriptName] - [/classes] - Done"
#endregion - From /classes

#region - From /private
Write-Verbose "[$scriptName] - [/private] - Processing folder"

#region - From /private/Get-InternalPSModule.ps1
Write-Verbose "[$scriptName] - [/private/Get-InternalPSModule.ps1] - Importing"

Function Get-InternalPSModule {
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

Write-Verbose "[$scriptName] - [/private/Get-InternalPSModule.ps1] - Done"
#endregion - From /private/Get-InternalPSModule.ps1
#region - From /private/Set-InternalPSModule.ps1
Write-Verbose "[$scriptName] - [/private/Set-InternalPSModule.ps1] - Importing"

Function Set-InternalPSModule {
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

Write-Verbose "[$scriptName] - [/private/Set-InternalPSModule.ps1] - Done"
#endregion - From /private/Set-InternalPSModule.ps1

Write-Verbose "[$scriptName] - [/private] - Done"
#endregion - From /private

#region - From /public
Write-Verbose "[$scriptName] - [/public] - Processing folder"

#region - From /public/Get-PSModuleTest.ps1
Write-Verbose "[$scriptName] - [/public/Get-PSModuleTest.ps1] - Importing"

#Requires -Modules Utilities

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
    Write-Debug 'Debug message'
    Write-Verbose 'Verbose message'
    Write-Output "Hello, $Name!"
}

Write-Verbose "[$scriptName] - [/public/Get-PSModuleTest.ps1] - Done"
#endregion - From /public/Get-PSModuleTest.ps1
#region - From /public/New-PSModuleTest.ps1
Write-Verbose "[$scriptName] - [/public/New-PSModuleTest.ps1] - Importing"

#Requires -Modules @{ModuleName='PSSemVer'; ModuleVersion='1.0'}

function New-PSModuleTest {
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
    Write-Debug 'Debug message'
    Write-Verbose 'Verbose message'
    Write-Output "Hello, $Name!"
}

Write-Verbose "[$scriptName] - [/public/New-PSModuleTest.ps1] - Done"
#endregion - From /public/New-PSModuleTest.ps1
#region - From /public/Set-PSModuleTest.ps1
Write-Verbose "[$scriptName] - [/public/Set-PSModuleTest.ps1] - Importing"

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
    [CmdletBinding(SupportsShouldProcess)]
    param (
        # Name of the person to greet.
        [Parameter(Mandatory)]
        [string] $Name
    )
    Write-Debug 'Debug message'
    Write-Verbose 'Verbose message'
    if ($PSCmdlet.ShouldProcess($Name, 'Set-PSModuleTest')) {
        Write-Output "Hello, $Name!"
    }
}

Write-Verbose "[$scriptName] - [/public/Set-PSModuleTest.ps1] - Done"
#endregion - From /public/Set-PSModuleTest.ps1
#region - From /public/Test-PSModuleTest.ps1
Write-Verbose "[$scriptName] - [/public/Test-PSModuleTest.ps1] - Importing"

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
    Write-Debug 'Debug message'
    Write-Verbose 'Verbose message'
    Write-Output "Hello, $Name!"
}

Write-Verbose "[$scriptName] - [/public/Test-PSModuleTest.ps1] - Done"
#endregion - From /public/Test-PSModuleTest.ps1

Write-Verbose "[$scriptName] - [/public] - Done"
#endregion - From /public

#region - From /finally.ps1
Write-Verbose "[$scriptName] - [/finally.ps1] - Importing"

Write-Verbose '------------------------------'
Write-Verbose '---  THIS IS A LAST LOADER ---'
Write-Verbose '------------------------------'
Write-Verbose "[$scriptName] - [/finally.ps1] - Done"
#endregion - From /finally.ps1

$exports = @{
    Cmdlet   = ''
    Alias    = '*'
    Variable = ''
    Function = @(
        'Get-PSModuleTest'
        'New-PSModuleTest'
        'Set-PSModuleTest'
        'Test-PSModuleTest'
    )
}
Export-ModuleMember @exports

