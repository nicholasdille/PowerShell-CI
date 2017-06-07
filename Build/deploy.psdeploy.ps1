﻿# Generic module deployment.
#
# ASSUMPTIONS:
#
# * folder structure either like:
#
#   - RepoFolder
#     - This PSDeploy file
#     - ModuleName
#       - ModuleName.psd1
#
#   OR the less preferable:
#   - RepoFolder
#     - RepoFolder.psd1
#
# * Nuget key in $ENV:NugetApiKey
#
# * Set-BuildEnvironment from BuildHelpers module has populated ENV:BHModulePath and related variables

# Publish to gallery with a few restrictions
if(
    $env:BHModulePath -and
    $env:BHBuildSystem -ne 'Unknown' -and
    $env:BHBranchName -eq "master" -and
    $env:BHCommitMessage -match '!deploy'
)
{
    Deploy Module {
        By PSGalleryModule {
            FromSource $ENV:BHModulePath
            To PSGallery
            WithOptions @{
                ApiKey = $ENV:NugetApiKey
            }
        }
    }
}
else
{
    "Skipping deployment to PSGallery: To deploy, ensure that...`n" +
    "`t* You are in a known build system (Current: $ENV:BHBuildSystem)`n" +
    "`t* You are committing to the master branch (Current: $ENV:BHBranchName) `n" +
    "`t* Your commit message includes !deploy (Current: $ENV:BHCommitMessage)" |
        Write-Host
}

# Create GitHub release
if(
    $env:BHModulePath -and
    $env:BHBuildSystem -eq 'AppVeyor' -and
    $env:APPVEYOR_REPO_PROVIDER -eq 'gitHub' -and
    $env:BHCommitMessage -match '!release'
)
{
    Compress-Archive -Path $env:BHModulePath -DestinationPath $ProjectRoot\$env:BHProjectName-$env:ModuleVersion.zip
    if (-Not (Test-Path -Path $ProjectRoot\$env:BHProjectName-$env:ModuleVersion.zip)) {
        Write-Error 'Failed to create archive for release'
    }

    $ReleaseNotes = Get-Content -Path .\RELEASENOTES.md | ForEach-Object { if ($_ -like "# $env:ModuleVersion") { $output = $true } elseif ($_ -like '# *') { $output = $false }; if ($output) { $_ } }
    $ReleaseNotes = $ReleaseNotes | Where-Object { $_ -notlike '# *' -and $_ -ne '' }

    $RequestBody = ConvertTo-Json -InputObject @{
        "tag_name"         = "$env:ModuleVersion"
        "target_commitish" = "$env:BHBranchName"
        "name"             = "Version $env:ModuleVersion"
        "body"             = "$ReleaseNotes"
        "draft"            = $false
        "prerelease"       = $false
    }
    $Result = Invoke-WebRequest -Method Post -Uri "https://api.github.com/repos/$ENV:APPVEYOR_REPO_NAME/releases" -Headers @{Authorization = "token $ENV:GitHubToken"} -Body $RequestBody
    if ($Result.StatusCode -ne 201) {
        Write-Error "Failed to create release. Code $($Result.StatusCode): $($Result.Content)"
    }
    $GitHubReleaseId = ($Result.Content | ConvertFrom-Json).id

    # add asset
    $RequestBody = Get-Content -Path $ProjectRoot\$env:BHProjectName-$env:ModuleVersion.zip -Raw
    $Result = Invoke-WebRequest -Method Post -Uri "https://uploads.github.com/repos/$ENV:APPVEYOR_REPO_NAME/releases/$GitHubReleaseId/assets?name=$env:BHProjectName-$env:ModuleVersion.zip" -Headers @{Authorization = "token $ENV:GitHubToken"} -ContentType 'application/zip' -Body $RequestBody
    if ($Result.StatusCode -ne 201) {
        Write-Error "Failed to upload release asset. Code $($Result.StatusCode): $($Result.Content)"
    }
}
else
{
    "Skipping deployment on GitHub: To deploy, ensure that...`n" +
    "`t* Your build system is AppVeyor (Current: $env:BHBuildSystem)`n" +
    "`t* Your repo resides on GitHub (Current: $env:APPVEYOR_REPO_PROVIDER)`n" +
    "`t* Your commit message includes !release (Current: $ENV:BHCommitMessage)" |
        Write-Host
}

# Publish to AppVeyor if we're in AppVeyor
if(
    $env:BHModulePath -and
    $env:BHBuildSystem -eq 'AppVeyor'
   )
{
    Deploy DeveloperBuild {
        By AppVeyorModule {
            FromSource $ENV:BHModulePath
            To AppVeyor
            WithOptions @{
                Version = $env:APPVEYOR_BUILD_VERSION
            }
        }
    }
}

if (
    $env:BHModulePath -and
    $env:BHBuildSystem -eq 'Unknown'
)
{
    Deploy LocalModule {
        By FileSystem {
            FromSource $env:BHModulePath
            To $env:userprofile\Documents\WindowsPowerShell\Modules\$env:BHProjectName
        }
    }
}