# PSake makes variables declared here available in other scriptblocks
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

    # Load module manifest
    $Module = Get-ChildItem -Path $ProjectRoot -File -Recurse -Filter '*.psd1' | Where-Object { $_.Directory.Name -eq $_.BaseName }
    if ($Module -is [array]) {
        Write-Error 'Found more than one module manifest'
    }
    if (-Not $Module) {
        Write-Error 'Did not find any module manifest'
    }
    Import-LocalizedData -BindingVariable Manifest -BaseDirectory $Module.Directory.FullName -FileName $Module.Name
    $ModuleVersion = $Manifest.ModuleVersion
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
            "https://ci.appveyor.com/api/testresults/nunit/$env:APPVEYOR_JOB_ID",
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

    If($ENV:BHBuildSystem -eq 'AppVeyor') {
        Update-Metadata -Path $env:BHPSModuleManifest -PropertyName ModuleVersion -Value "$($Manifest.ModuleVersion).$env:APPVEYOR_BUILD_NUMBER" -ErrorAction stop
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