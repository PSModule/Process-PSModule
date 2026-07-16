function Get-RootLevelVariable {
    <#
        .SYNOPSIS
        Get the root-level variables in a ast.

        .EXAMPLE
        Get-RootLevelVariable -Ast $ast
    #>
    [CmdletBinding()]
    param (
        # The Abstract Syntax Tree (AST) to analyze
        [System.Management.Automation.Language.ScriptBlockAst]$Ast
    )
    # Iterate over the top-level statements in the AST
    foreach ($statement in $Ast.EndBlock.Statements) {
        # Check if the statement is an assignment statement
        if ($statement -is [System.Management.Automation.Language.AssignmentStatementAst]) {
            # Get the variable name, removing the scope prefix
            $statement.Left.VariablePath.UserPath -replace '.*:'
        }
    }
}
