# SCRIPT USAGE
#.\EnvironmentVariableGenerator.ps1 -targetEnvironmentName "PROD" -targetSiteUrl https://siteurl/sites/sitename -devSiteUrl https://siteurl/sites/sitename

Param (
   [string] $targetEnvironmentName,
   [string] $targetSiteUrl,
   [string] $devSiteUrl
)


#$devSiteUrl = 'https://siteurl/sites/devsitename'
#$targetSiteUrl = 'https://siteurl/sites/UATsitename'
#$targetEnvironmentName = "UAT"

class EnvironmentVariables {
[string] $TenantUrl
[string] $SiteUrl
[string] $ListNameAId
[string] $ListNameAView3Id
[string] $ListNameBId
[string] $ListNameCId
[string] $ListNameDId
[string] $ListNameDView1Id
[string] $Web1Id

}

$credentials = Get-Credential

function Get-EnvironmentVariables ($siteUrl){
    Connect-PnPOnline -Url $siteUrl -Credentials $credentials
    $env = [EnvironmentVariables]::new()
    $site = Get-PnPSite
    
    $web = Get-PnPWeb 
    $env.Web1Id = $web.Id
    $env.TenantUrl = $siteUrl.Substring(0,$siteUrl.IndexOf('/sites'))
    $env.SiteUrl = $web.ServerRelativeUrl.trim("/")
    
    $listA = Get-PnPList -Identity 'ListNameA'
    $env.ListNameAId = $listA.Id
    $env.ListNameAView3Id = (Get-PnPView -List $listA -Identity 'View 3').Id

    $listB = Get-PnPList -Identity 'ListNameB'
    $env.ListNameBId = $listB.Id

    $listC = Get-PnPList -Identity 'ListNameC'
    $env.ListNameCId = $listC.Id

    $listD = Get-PnPList -Identity 'ListNameD'
    $env.ListNameDId = $listD.Id
    $env.ListNameDView1Id = (Get-PnPView -List $listD -Identity 'View 1').Id

    return $env

}

function Get-ScriptDirectory 
{ 
    if ($psise) {
        Split-Path $psise.CurrentFile.FullPath
    }
    else {
        $global:PSScriptRoot
    }
}

Set-Location (Get-ScriptDirectory )

$devVariables = Get-EnvironmentVariables $devSiteUrl

$targetVariables = Get-EnvironmentVariables $targetSiteUrl 

$config = New-Object System.Collections.Generic.List[System.Object]

$devVariables.PSObject.Properties |% {
$propName =  $_.Name
$rowitem = @{ Property = $propName; old= $devVariables.$propName;new=$targetVariables.$propName }
$config.Add($rowitem )
}


ConvertTo-Json -InputObject $config.ToArray() | Set-Content "$targetEnvironmentName.json"


