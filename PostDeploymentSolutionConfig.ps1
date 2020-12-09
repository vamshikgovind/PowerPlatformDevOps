# Usage : .\PostDeploymentSolutionConfig.ps1 -targetEnvName '*envnamevariable*'

Param (
   [string] $targetEnvName  
)



[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$solutionName = 'solutionname'


function Install-IfNotAlready
{
    Param(
            [Parameter(Mandatory=$true, Position=0)]
            [string] $moduleName
        )
    $isInstalled = get-installedmodule $moduleName -ErrorAction Ignore
    if(!$isInstalled)
    {
        Install-Module $moduleName -Scope AllUsers -AllowClobber -SkipPublisherCheck -force
        write-host ($moduleName + " installed")
        import-module $moduleName
    }
    elseif($isInstalled)
    {
     write-host ($moduleName + " is already installed")
    }   
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

Set-Location (Get-ScriptDirectory)

Install-IfNotAlready Xrm.Framework.CI.PowerShell.Cmdlets
Install-IfNotAlready Microsoft.PowerApps.Administration.PowerShell
Install-IfNotAlready Microsoft.PowerApps.PowerShell

Add-PowerAppsAccount


$environemnt = Get-AdminPowerAppEnvironment |? DisplayName -Like $targetEnvName
$environmentName = $environemnt.EnvironmentName
$appsinSolution = @('Appname1','Appname2')


$appsinSolution | % {
    $appName = $_
    $taApp = Get-AdminPowerApp -EnvironmentName $environmentName |? DisplayName -EQ $appName
    # Adding current user as co owner
    Set-AdminPowerAppRoleAssignment -AppName $taApp.AppName -EnvironmentName $environmentName -RoleName CanEdit -PrincipalType User -PrincipalObjectId $Global:currentSession.userId
    #  Adding the security group as users- Security Group Name
    #Set-AdminPowerAppRoleAssignment -EnvironmentName $environmentName -AppName $taApp.AppName -RoleName CanView -PrincipalType Group -PrincipalObjectId GUIDOFGROUP



}