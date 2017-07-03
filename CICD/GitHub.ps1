function Get-GitHubRelease {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Owner
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
        ,
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [int]
        $Id
    )

    $IwrParams = @{
        UseBasicParsing = $true
        Method          = 'Get'
        Uri             = "https://api.github.com/repos/$Owner/$Repository/releases"
        Headers         = @{
            Authorization = "token $Token"
        }
    }
    if ($Id -ne $null -and $Id -gt 0) {
        $IwrParams.Uri += "/$Id"
    }

    $Result = Invoke-WebRequest @IwrParams
    $Result.Content | ConvertFrom-Json
}

function New-GitHubRelease {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        "PSUseShouldProcessForStateChangingFunctions", 
        "", 
        Justification = "Will be added evantually."
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Owner
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Name
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Body
        ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $Branch = 'master'
        ,
        [Parameter()]
        [switch]
        $Draft
        ,
        [Parameter()]
        [switch]
        $Prerelease
    )

    $Releases = Get-GitHubRelease -Owner $Owner -Repository $Repository -Token $Token
    $Release = $Releases | Where-Object {$_.tag_name -eq $Name}
    if ($Release) {
        Write-Warning "Release with name $Name for $Owner/$repository already exist."
        $Release.id

    } else {
        $RequestBody = ConvertTo-Json -InputObject @{
            "tag_name"         = "$Name"
            "target_commitish" = "$Branch"
            "name"             = "Version $Name"
            "body"             = "$body"
            "draft"            = $false
            "prerelease"       = $false
        }
        $Result = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "https://api.github.com/repos/$Owner/$Repository/releases" -Headers @{Authorization = "token $Token"} -Body $RequestBody
        if ($Result.StatusCode -ne 201) {
            Write-Error "Failed to create release. Code $($Result.StatusCode): $($Result.Content)"
        }

        ($Result.Content | ConvertFrom-Json).id
    }
}

function Remove-GitHubRelease {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        "PSUseShouldProcessForStateChangingFunctions", 
        "", 
        Justification = "Will be added evantually."
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Owner
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]
        $Id
    )

    $IwrParams = @{
        UseBasicParsing = $true
        Uri             = "https://api.github.com/repos/$Owner/$Repository/releases/$Id"
        Method          = 'Delete'
        Headers         = @{
            Authorization = "token $Token"
        }
    }

    $Result = Invoke-WebRequest @IwrParams
    if ($Result.StatusCode -ne 204) {
        Write-Error "Failed to remove release asset with ID $Id. Code $($Result.StatusCode): $($Result.Content)"
    }
}

function Get-GitHubReleaseAsset {
    [CmdletBinding(DefaultParameterSetName = 'All')]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Owner
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]
        $Release
        ,
        [Parameter(Mandatory, ParameterSetName = 'ById')]
        [ValidateNotNullOrEmpty()]
        [int]
        $Id
    )

    $IwrParams = @{
        UseBasicParsing = $true
        Method          = 'Get'
        Uri             = "https://api.github.com/repos/$Owner/$Repository/releases/$Release/assets"
        Headers         = @{
            Authorization = "token $Token"
        }
    }
    if ($Id -ne $null -and $Id -gt 0) {
        $IwrParams.Uri += "/$Id"
    }

    $Result = Invoke-WebRequest @IwrParams
    $Result.Content | ConvertFrom-Json

}

function New-GitHubReleaseAsset {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        "PSUseShouldProcessForStateChangingFunctions", 
        "", 
        Justification = "Will be added evantually."
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Owner
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]
        $Release
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Path
        ,
        [Parameter()]
        [ValidateNotNullOrEmpty()]
        [string]
        $ContentType = 'application/zip'
    )

    if (-Not (Test-Path -Path $Path)) {
        Write-Error "File $Path does not exist."
    }

    $File = Get-Item -Path $Path
    $Name = $File.Name

    $IwrParams = @{
        UseBasicParsing = $true
        Uri             = "https://uploads.github.com/repos/$Owner/$Repository/releases/$Release/assets?name=$Name"
        Method          = 'Post'
        ContentType     = $ContentType
        Body            = Get-Content -Path $Path -Raw
        Headers         = @{
            Authorization = "token $Token"
        }
    }

    $Result = Invoke-WebRequest @IwrParams
    if ($Result.StatusCode -ne 201) {
        Write-Error "Failed to upload release asset to release ID $Release. Code $($Result.StatusCode): $($Result.Content)"
    }

    $Result.Content | ConvertFrom-Json | Select-Object -ExpandProperty id
}

function Remove-GitHubReleaseAsset {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute(
        "PSUseShouldProcessForStateChangingFunctions", 
        "", 
        Justification = "Will be added evantually."
    )]
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Owner
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Repository
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [string]
        $Token
        ,
        [Parameter(Mandatory)]
        [ValidateNotNullOrEmpty()]
        [int]
        $Id
    )

    $IwrParams = @{
        UseBasicParsing = $true
        Uri             = "https://api.github.com/repos/$Owner/$Repository/releases/assets/$Id"
        Method          = 'Delete'
        Headers         = @{
            Authorization = "token $Token"
        }
    }

    $Result = Invoke-WebRequest @IwrParams
    if ($Result.StatusCode -ne 204) {
        Write-Error "Failed to remove release asset with ID $Id. Code $($Result.StatusCode): $($Result.Content)"
    }
}