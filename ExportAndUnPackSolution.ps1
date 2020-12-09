[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$solutionName = 'SolutionName'

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

$rootFolder = Split-Path (Get-ScriptDirectory) -Parent
Set-Location ("$rootFolder\Solution")

Install-IfNotAlready Xrm.Framework.CI.PowerShell.Cmdlets
Install-IfNotAlready Microsoft.PowerApps.Administration.PowerShell
Install-IfNotAlready Microsoft.PowerApps.PowerShell

$credentials = Get-Credential

$unsecure = ("Url=https://powerappsinstanceurl.dynamics.com;Username=$($credentials.UserName);Password=$($credentials.GetNetworkCredential().Password);authtype=Office365")
$thisLocation = Get-Location
write-host "Exporting Unmanaged" $solutionName "Solution"
Export-XrmSolution -UniqueSolutionName $solutionName -Managed $false -OutputFolder $thisLocation -ConnectionString $unsecure
write-host "Exporting Managed" $solutionName "Solution"
Export-XrmSolution -UniqueSolutionName $solutionName -Managed $true -OutputFolder $thisLocation -ConnectionString $unsecure

#rename the solutions to zip file
$unmanagedZipName = $solutionName + '.zip'
$managedZipName = $solutionName + '_managed.zip'

$unmanagedZip = (Join-Path -Path $thisLocation -ChildPath $unmanagedZipName)
$managedZip = (Join-Path -Path $thisLocation -ChildPath $managedZipName)

#extract the files from zip
C:\CRM\Tools\CoreTools\SolutionPackager.exe /action:Extract /zipfile:$unmanagedZip /folder:$thisLocation /packagetype:Both /allowDelete:No 
write-host "Deleting exported zip files"
Remove-Item $unmanagedZip -Force
Remove-Item $managedZip -Force

# Now the flows have been extracted to become code files but the power apps are still in .msapp format. They need to be enamed to .zip and extracted.
# This is a sample code. This cannot be used as is.
Get-ChildItem -Path "$thisLocation" -Filter *.msapp -r | % { 
    $msappFileName = $_.Name.Replace(".msapp","")
    Rename-Item "$thisLocation\$msappFileName.msapp" "$msappFileName.zip"

    Expand-Archive "$thisLocation\$msappFileName.zip" -DestinationPath "$thisLocation\$msappFileName"
    Write-Host "Exctracted the app into $thisLocation\$msappFileName"
    Remove-Item -Path "$thisLocation\$msappFileName.zip" -Force
}