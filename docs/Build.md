# Build-PSModule

This action "compiles" the module source code into an efficient PowerShell module that is ready to be published to the PowerShell Gallery.

This GitHub Action is a part of the [PSModule framework](https://github.com/PSModule). It is recommended to use the [Process-PSModule workflow](https://github.com/PSModule/Process-PSModule) to automate the whole process of managing the PowerShell module.

## Supported module types

- Script module type
- Manifest module type

## Supported practices and principles

- [PowerShellGallery Publishing Guidelines and Best Practices](https://learn.microsoft.com/powershell/gallery/concepts/publishing-guidelines) are followed as much as possible.

## How it works

During the build process the following steps are performed:

1. **Runs local build scripts:** Searches for any `*build.ps1` files anywhere in the repository. These scripts are executed in **alphabetical order by filename** (irrespective of their path).
This step lets you add custom build logic to process or modify the module contents before further build steps are performed.
1. **Copies the source code** of the module to an output folder.
1. **Builds the module manifest file** based on information from the GitHub repository and the source code. For more information, please read the [Module Manifest](#module-manifest) section.
1. **Builds the root module (.psm1) file** by combining source code and adding automation into the root module file. For more information, please read the [Root module](#root-module) section.
1. **Builds the module documentation** using platyPS and comment-based help in the source code. For more information, please read the [Module documentation](#module-documentation) section.

## Usage

| Name                   | Description                                                                                                                                         | Required | Default           |
| ---------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------- | -------- | ----------------- |
| `Name`                 | Name of the module to process.                                                                                                                      | `false`  |                   |
| `Path`                 | Path to the folder where the modules are located.                                                                                                   | `false`  | `src`             |
| `ModulesOutputPath`    | Path to the folder where the built modules are outputted.                                                                                           | `false`  | `outputs/modules` |
| `DocsOutputPath`       | Path to the folder where the built docs are outputted.                                                                                              | `false`  | `outputs/docs`    |
| `ModuleArtifactName`   | Name of the module artifact to upload.                                                                                                              | `false`  | `module`          |
| `DocsArtifactName`     | Name of the docs artifact to upload.                                                                                                                | `false`  | `docs`            |
| `Debug`                | Enable debug output.                                                                                                                                | `false`  | `'false'`         |
| `Verbose`              | Enable verbose output.                                                                                                                              | `false`  | `'false'`         |
| `Version`              | Specifies the version of the GitHub module to be installed. The value must be an exact version.                                                     | `false`  |                   |
| `Prerelease`           | Allow prerelease versions if available.                                                                                                             | `false`  | `'false'`         |

## Root module

The `src` folder may contain a 'root module' file. If present, the build function will disregard this file and build a new root module file based on the source code in the module folder.

The root module file is the main file that is loaded when the module is imported. It is built from the source code files in the module folder in the following order:

1. Adds a module header from `header.ps1` if it exists and removes the file from the module folder.
1. Adds a data loader that loads files from the `data` folder as variables in the module scope, if the folder exists. The variables are available using the `$script:<filename>` syntax.
1. Adds content from the following folders into the root module file. The files on the root of a folder are added before recursively processing subfolders (folders are processed in alphabetical order). Once a file is processed, it is removed from the module folder.
   1. `init`
   1. `classes/private`
   1. `classes/public`
   1. `functions/private`
   1. `functions/public`
   1. `variables/private`
   1. `variables/public`
   1. `*.ps1` on module root
1. Adds a `class` and `enum` exporter that exports the ones from the `classes/public` folder to the caller session, using [TypeAccelerators](https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_classes?view=powershell-7.4#exporting-classes-with-type-accelerators).
1. Adds the `Export-ModuleMember` function to the end of the file, to ensure that only the functions, cmdlets, variables and aliases defined in the `public` folders are exported.

## Module manifest

The module manifest file describes the module and its contents. PowerShell uses it to load the module and its prerequisites. It also contains important metadata used by the PowerShell Gallery. If a file exists in the source code folder (`src`), it will be used as the base for the module manifest file. While most values in the module manifest are calculated during the build process, some values are preserved if specified in the source manifest file.

During the module manifest build process the following steps are performed:

1. Get the manifest file from the source code. If it does not exist, a new manifest file is created.
1. Generate and set the `RootModule` based on the module name.
1. Set a temporary `ModuleVersion` (this is updated during the release process by [Publish-PSModule](https://github.com/PSModule/Publish-PSModule)).
1. Set the `Author` and `CompanyName` based on the GitHub Owner. If a value exists in the source manifest file, that value is used.
1. Set the `Copyright` information based on a default text (`(c) 2024 >>OwnerName<<. All rights reserved.`) and includes the `Author`, `CompanyName` or both when applicable. If a value exists in the source manifest file, that value is used.
1. Set the `Description` based on the GitHub repository description. If a value exists in the source manifest file, that value is used.
1. Set various properties such as `PowerShellHostName`, `PowerShellHostVersion`, `DotNetFrameworkVersion`, `ClrVersion`, and `ProcessorArchitecture`. If values exist in the source manifest file, those values are used.
1. Get the list of files in the module source folder and set the `FileList` property in the manifest.
1. Get the list of required assemblies (`*.dll` files) from the `assemblies` and `modules` (depth = 1) folder and set the `RequiredAssemblies` property.
1. Get the list of nested modules (`*.psm1`, `*.ps1` and `*.dll` files one level down) from the `modules` folder and set the `NestedModules` property.
1. Get the list of scripts to process (`*.ps1` files) from the `scripts` folder and set the `ScriptsToProcess` property. This ensures that the scripts are loaded into the caller session.
1. Get the list of types to process by searching for `*.Types.ps1xml` files in the entire module source folder and set the `TypesToProcess` property.
1. Get the list of formats to process by searching for `*.Format.ps1xml` files in the entire module source folder and set the `FormatsToProcess` property.
1. Get the list of DSC resources to export by searching for `*.psm1` files in the `resources` folder and set the `DscResourcesToExport` property.
1. Get the list of functions, cmdlets, aliases, and variables from the respective `<type>\public` folders and set the respective properties in the manifest.
1. Get the list of modules by searching for all `*.psm1` files in the entire module source folder (excluding the root module) and set the `ModuleList` property.
1. Gather information from source files to update `RequiredModules`, `PowerShellVersion`, and `CompatiblePSEditions` properties.
1. Gather additional information from the GitHub repository:
   - `Tags` are generated from repository topics plus compatibility tags from the source files.
   - `LicenseUri` is generated assuming there is a `LICENSE` file at the repository root. If a value exists in the source manifest file, that value is used.
   - `ProjectUri` is set to the GitHub repository URL. If a value exists in the source manifest file, that value is used.
   - `IconUri` is generated assuming there is an `icon.png` file in the `icon` folder at the repository root. If a value exists in the source manifest file, that value is used.
1. `ReleaseNotes` are not automated (could be set via PR or release description).
1. `PreRelease` is managed externally by [Publish-PSModule](https://github.com/PSModule/Publish-PSModule).
1. `RequireLicenseAcceptance` defaults to `false` unless specified in the source manifest.
1. `ExternalModuleDependencies` is not automated. If specified in the source manifest, that value is used.
1. `HelpInfoURI` is not automated. If specified in the source manifest, that value is used.
1. Create a new manifest file in the output folder with the gathered information, which also generates a new `GUID` for the module.
1. Format the manifest file using the `Set-ModuleManifest` function from the [Utilities](https://github.com/PSModule/Utilities) module.

Linking the description to the module manifest file might show more how this works:

```powershell
@{
    RootModule             = 'Utilities.psm1' # Generated from the module name, <moduleName>.psm1
    ModuleVersion          = '0.0.1'          # Set during release using Publish-PSModule.
    CompatiblePSEditions   = @()              # Get from source files, requires -PSEdition <PSEdition-Name>, null if not provided.
    GUID                   = '<GUID>'         # Generated when saving the manifest using New-ModuleManifest.
    Author                 = 'PSModule'       # Derived from the GitHub Owner, unless specified in the source manifest.
    CompanyName            = 'PSModule'       # Derived from the GitHub Owner, unless specified in the source manifest.
    Copyright              = '(c) 2024 PSModule. All rights reserved.'
    Description            = 'This is a module.' # Taken from the repository description or the source manifest.
    PowerShellVersion      = ''               # Derived from source files, requires -Version <N>[.<n>], null if not provided.
    PowerShellHostName     = ''               # Taken from the manifest file, null if not provided.
    PowerShellHostVersion  = ''               # Taken from the manifest file, null if not provided.
    DotNetFrameworkVersion = ''               # Taken from the manifest file, null if not provided.
    ClrVersion             = ''               # Taken from the manifest file, null if not provided.
    ProcessorArchitecture  = ''               # Taken from the manifest file, null if not provided.
    RequiredModules        = @()              # Derived from source files, ensuring required modules are installed.
    RequiredAssemblies     = @()              # Collected from assemblies\*.dll and modules\*.dll.
    ScriptsToProcess       = @()              # Collected from scripts\*.ps1 and classes\*.ps1 ordered by name.
    TypesToProcess         = @()              # Collected from *.Types.ps1xml files in the source folder.
    FormatsToProcess       = @()              # Collected from *.Format.ps1xml files in the source folder.
    NestedModules          = @()              # Collected from modules\*.psm1, modules\*.ps1, and modules\*.dll.
    FunctionsToExport      = @()              # Collected from public\*.ps1 files.
    CmdletsToExport        = @()              # Taken from the manifest file, or empty if not provided.
    VariablesToExport      = @()              # Collected from variables\public\*.ps1.
    AliasesToExport        = '*'              # Derived from functions\public\*.ps1.
    DscResourcesToExport   = @()              # Collected from resources\*.psm1.
    ModuleList             = @()              # A listing of all .\*.psm1 files (informational only).
    FileList               = @()              # A listing of all .\* files (informational only).
    PrivateData            = @{
        PSData = @{
            Tags                       = @() # Derived from repository topics and compatibility tags.
            LicenseUri                 = ''  # Generated public link to .\LICENSE.
            ProjectUri                 = ''  # Generated public link to the GitHub Repository.
            IconUri                    = ''  # Derived from .\icon\icon.png.
            ReleaseNotes               = ''  # To be updated during release.
            Prerelease                 = ''  # Normalized version of the branch name, updated during release.
            RequireLicenseAcceptance   = $false
            ExternalModuleDependencies = @()
            ExperimentalFeatures       = @(
                @{
                    Name        = "SomeExperimentalFeature"
                    Description = "This is an experimental feature."
                }
            )
        }
        OtherKeys = @{}
    }
    HelpInfoURI            = ''  # Taken from the source manifest if provided.
    DefaultCommandPrefix   = ''  # Taken from the source manifest if provided.
}
```

## Module documentation

The module documentation is built using `platyPS` and comment-based help in the source code. The documentation is currently not published anywhere but is expected to be published to GitHub Pages in a future release.

## Permissions

This action does not require any special permissions.

## Sources

**Module manifest:**

- [about_Module_Manifests](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/about/about_module_manifests)
- [How to write a PowerShell module manifest](https://learn.microsoft.com/powershell/scripting/developer/module/how-to-write-a-powershell-module-manifest)
- [New-ModuleManifest](https://learn.microsoft.com/powershell/module/microsoft.powershell.core/new-modulemanifest)
- [Update-ModuleManifest](https://learn.microsoft.com/powershell/module/powershellget/update-modulemanifest)
- [Package metadata values that impact the PowerShell Gallery UI](https://learn.microsoft.com/powershell/gallery/concepts/package-manifest-affecting-ui#powershell-gallery-feature-elements-controlled-by-the-module-manifest)
- [PowerShellGallery Publishing Guidelines and Best Practices](https://learn.microsoft.com/en-us/powershell/gallery/concepts/publishing-guidelines#tag-your-package-with-the-compatible-pseditions-and-platforms)

**Modules:**

- [PowerShell scripting performance considerations](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/script-authoring-considerations)
- [PowerShell module authoring considerations](https://learn.microsoft.com/powershell/scripting/dev-cross-plat/performance/module-authoring-considerations)

**Documentation:**

- [platyPS reference](https://learn.microsoft.com/powershell/module/platyps/?source=recommendations)
- [PlatyPS overview](https://learn.microsoft.com/powershell/utility-modules/platyps/overview?view=ps-modules)
- [about_Comment_Based_Help](https://go.microsoft.com/fwlink/?LinkID=123415)
- [Supporting Updatable Help](https://learn.microsoft.com/powershell/scripting/developer/help/supporting-updatable-help)
