﻿# PSake makes variables declared here available in other scriptblocks
# Init some things
Properties {
    # Find the build folder based on build system
        $ProjectRoot = $ENV:BHProjectPath
        if(-not $ProjectRoot)
        {
            $ProjectRoot = Resolve-Path "$PSScriptRoot\.."
        }

    $Timestamp = Get-Date -UFormat "%Y%m%d-%H%M%S"
    $PSVersion = $PSVersionTable.PSVersion.Major
    $TestFile = "TestResults_PS$PSVersion`_$TimeStamp.xml"
    $lines = '----------------------------------------------------------------------'

    $Verbose = @{}
    if($ENV:BHCommitMessage -match "!verbose")
    {
        $Verbose = @{Verbose = $True}
    }
}

Task Default -Depends Test

Task Init {
    $lines
    Set-Location $ProjectRoot
    "Build System Details:"
    Get-Item ENV:BH*
    "`n"
}

Task Test -Depends Init  {
    $lines
    "`n`tSTATUS: Testing with PowerShell $PSVersion"

    # Gather test results. Store them in a variable and file
    if ($env:PSModulePath -notlike "$ProjectRoot;*") {
        $env:PSModulePath = "$ProjectRoot;$env:PSModulePath"
    }
    $TestResults = Invoke-Pester -Path $ProjectRoot\Tests -PassThru -OutputFormat NUnitXml -OutputFile "$ProjectRoot\$TestFile" -CodeCoverage "$env:BHModulePath\$env:BHProjectName.psm1"

    # In Appveyor?  Upload our tests! #Abstract this into a function?
    If($ENV:BHBuildSystem -eq 'AppVeyor')
    {
        (New-Object 'System.Net.WebClient').UploadFile(
            "https://ci.appveyor.com/api/testresults/nunit/$($env:APPVEYOR_JOB_ID)",
            "$ProjectRoot\$TestFile" )
    }

    Remove-Item "$ProjectRoot\$TestFile" -Force -ErrorAction SilentlyContinue

    # Failed tests?
    # Need to tell psake or it will proceed to the deployment. Danger!
    if($TestResults.FailedCount -gt 0)
    {
        Write-Error "Failed '$($TestResults.FailedCount)' tests, build failed"
    }
    "`n"
}

Task Docs {
    $lines

    New-ExternalHelp -Path $ProjectRoot\docs -OutputPath $env:BHModulePath\en-US -Force
}

Task Build -Depends Test,Docs {
    $lines
    
    # Load the module, read the exported functions, update the psd1 FunctionsToExport
    Set-ModuleFunctions

    $content = Get-Content -Path $env:BHPSModuleManifest -Raw -ErrorAction Stop
    $scriptBlock = [scriptblock]::Create($content)
    [string[]] $allowedCommands = @(
        'Import-LocalizedData', 'ConvertFrom-StringData', 'Write-Host', 'Out-Host', 'Join-Path'
    )
    [string[]] $allowedVariables = @('PSScriptRoot')
    $scriptBlock.CheckRestrictedLanguage($allowedCommands, $allowedVariables, $true)
    $manifest = & $scriptBlock

    $ModuleVersion = $manifest.ModuleVersion
    If($ENV:BHBuildSystem -eq 'AppVeyor') {
        Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value "$($ModuleVersion).$env:APPVEYOR_BUILD_NUMBER" -ErrorAction stop
        $ModuleVersion = "$ModuleVersion.$env:APPVEYOR_BUILD_NUMBER"
    }
}

Task Deploy -Depends Build {
    $lines

    $Params = @{
        Path = "$ProjectRoot\Build"
        Force = $true
        Recurse = $false # We keep psdeploy artifacts, avoid deploying those : )
    }
    Invoke-PSDeploy @Verbose @Params
}