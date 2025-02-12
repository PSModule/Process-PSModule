[Diagnostics.CodeAnalysis.SuppressMessageAttribute(
    'PSReviewUnusedParameter', 'Path',
    Justification = 'Path is used to specify the path to the module to test.'
)]
[CmdLetBinding()]
Param(
    [Parameter(Mandatory)]
    [string] $Path
)

# These tests are for the whole module and its parts. The scope of these tests are on the src folder and the specific module folder within it.
Describe 'Script files' {
    Context 'Module design tests' {
        # It 'Script file should only contain one function or filter' {}
        # It 'All script files have tests' {} # Look for the folder name in tests called the same as section/folder name of functions
    }

    Describe 'Function/filter design' {
        # It 'comment based doc block start is indented with 4 spaces' {}
        # It 'comment based doc is indented with 8 spaces' {}
        # It 'has synopsis for all functions' {}
        # It 'has description for all functions' {}
        # It 'has examples for all functions' {}
        # It 'has output documentation for all functions' {}
        # It 'has [CmdletBinding()] attribute' {}
        # It 'boolean parameters in CmdletBinding() attribute are written without assignments' {}
        #     I.e. [CmdletBinding(ShouldProcess)] instead of [CmdletBinding(ShouldProcess = $true)]
        # It 'has [OutputType()] attribute' {}
        # It 'has verb 'New','Set','Disable','Enable' etc. and uses "ShoudProcess" in the [CmdletBinding()] attribute' {}
    }

    Describe 'Parameter design' {
        # It 'has parameter description for all functions' {}
        # It 'has parameter validation for all functions' {}
        # It 'parameters have [Parameters()] attribute' {}
        # It 'boolean parameters to the [Parameter()] attribute are written without assignments' {}
        #     I.e. [Parameter(Mandatory)] instead of [Parameter(Mandatory = $true)]
        # It 'datatype for parameters are written on the same line as the parameter name' {}
        # It 'datatype for parameters and parameter name are separated by a single space' {}
        # It 'parameters are separated by a blank line' {}
    }
}
