function Get-CodeCoverageMetrics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [pscustomobject]
        $CodeCoverage
    )

    #region Initialize data structure and add statement coverage from pester
    $CoverageMetrics = @{
        Functions = @{}
        Statement = @{
            Analyzed = $CodeCoverage.NumberOfCommandsAnalyzed
            Executed = $CodeCoverage.NumberOfCommandsExecuted
            Missed   = $CodeCoverage.NumberOfCommandsMissed
            Coverage = 0
        }
        Function = @{}
    }
    $CoverageMetrics.Statement.Coverage = [math]::Round($CoverageMetrics.Statement.Executed / $CoverageMetrics.Statement.Analyzed * 100, 2)
    #endregion

    #region Enumerate hit and missed commands and add statement coverage per function
    $CodeCoverage.HitCommands | Group-Object -Property Function | ForEach-Object {
        if (-Not $CoverageMetrics.Functions.ContainsKey($_.Name)) {
            $CoverageMetrics.Functions.Add($_.Name, @{
                Name     = $_.Name
                Analyzed = 0
                Executed = 0
                Missed   = 0
                Coverage = 0
            })
        }

        $CoverageMetrics.Functions[$_.Name].Analyzed += $_.Count
        $CoverageMetrics.Functions[$_.Name].Executed += $_.Count
    }
    $CodeCoverage.MissedCommands | Group-Object -Property Function | ForEach-Object {
        if (-Not $CoverageMetrics.Functions.ContainsKey($_.Name)) {
            $CoverageMetrics.Functions.Add($_.Name, @{
                Name     = $_.Name
                Analyzed = 0
                Executed = 0
                Missed   = 0
                Coverage = 0
            })
        }

        $CoverageMetrics.Functions[$_.Name].Analyzed += $_.Count
        $CoverageMetrics.Functions[$_.Name].Missed   += $_.Count
    }
    #endregion

    #region Enumerate function data and calculate statement coverage per function
    foreach ($function in $CoverageMetrics.Functions.Values) {
        $function.Coverage = [math]::Round($function.Executed / $function.Analyzed * 100)
    }
    #endregion

    #region Calculate function coverage
    $CoverageMetrics.Function = @{
        Analyzed = $CoverageMetrics.Functions.Count
        Executed = ($CoverageMetrics.Functions.Values | Where-Object { $_.Executed -gt 0 }).Length
        Missed   = ($CoverageMetrics.Functions.Values | Where-Object { $_.Executed -eq 0 }).Length
    }
    $CoverageMetrics.Function.Coverage = [math]::Round($CoverageMetrics.Function.Executed / $CoverageMetrics.Function.Analyzed * 100, 2)
    #endregion

    $CoverageMetrics
}