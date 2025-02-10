﻿@{
    Rules        = @{
        PSAlignAssignmentStatement         = @{
            Enable         = $true
            CheckHashtable = $true
        }
        PSAvoidLongLines                   = @{
            Enable            = $true
            MaximumLineLength = 150
        }
        PSAvoidSemicolonsAsLineTerminators = @{
            Enable = $true
        }
        PSPlaceCloseBrace                  = @{
            Enable             = $true
            NewLineAfter       = $false
            IgnoreOneLineBlock = $true
            NoEmptyLineBefore  = $false
        }
        PSPlaceOpenBrace                   = @{
            Enable             = $true
            OnSameLine         = $true
            NewLineAfter       = $true
            IgnoreOneLineBlock = $true
        }
        PSProvideCommentHelp               = @{
            Enable                  = $true
            ExportedOnly            = $false
            BlockComment            = $true
            VSCodeSnippetCorrection = $false
            Placement               = 'begin'
        }
        PSUseConsistentIndentation         = @{
            Enable              = $true
            IndentationSize     = 4
            PipelineIndentation = 'IncreaseIndentationForFirstPipeline'
            Kind                = 'space'
        }
        PSUseConsistentWhitespace          = @{
            Enable = $false
        }
    }
    ExcludeRules = @(
        'PSAvoidUsingCmdletAliases',
        'PSUseToExportFieldsInManifest'
    )
}
