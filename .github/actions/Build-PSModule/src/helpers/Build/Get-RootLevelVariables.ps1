function Get-RootLevelVariable {
    <#
        .SYNOPSIS
        Get the root-level variables in an AST.

        .EXAMPLE
        Get-RootLevelVariable -Ast $ast
    #>
    [CmdletBinding()]
    param (
        # The abstract syntax tree (AST) to analyze.
        [System.Management.Automation.Language.ScriptBlockAst]$Ast
    )
    # Iterate over the top-level statements in the AST
    foreach ($statement in $Ast.EndBlock.Statements) {
        # Return only variables from root-level assignments.
        if ($statement -is [System.Management.Automation.Language.AssignmentStatementAst]) {
            # Get the variable name, removing the scope prefix
            $statement.Left.VariablePath.UserPath -replace '.*:'
        }
    }
}
