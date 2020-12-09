Param (
   [string] $jsonPath   
)


$Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding $False




# Get JSON
$json = Get-Content -Raw -Path $jsonPath | ConvertFrom-Json 

# Functions

 function Get-ScriptDirectory 
{ 
    if ($psise) {
        Split-Path $psise.CurrentFile.FullPath
    }
    else {
        $global:PSScriptRoot
    }
}
# =====> Replace content for a specific file
function ReplaceValue {
    param([string]$path)
    $content = Get-Content -path "$path" -Raw -Encoding UTF8
    $strContent = $content
    foreach($value in $json){
        $strContent = $strContent -ireplace $value.old, $value.new
    }
    
    return $strContent
}

# ====> Edit file, replace value and export it as encoded utf8
function EditFileTemplate {
    param( [string]$path )
    $valuereplaced = ReplaceValue -path $path
    
    [System.IO.File]::WriteAllLines($path, $valuereplaced, $Utf8NoBomEncoding)
}

# ====> Parsing file and folder
function ParseFilesNFolders{
    param([string]$thisFolder)
    Write-Host "Parsing $thisFolder ..."
    $parentFolder = Get-ScriptDirectory
    $folderContent = Get-ChildItem -Path $thisFolder
    foreach($content in $folderContent){
        if($content.GetType() -eq [System.IO.DirectoryInfo]){
            ParseFilesNFolders -thisFolder "$thisFolder\$content"
        }
        else{
            $ext = [System.IO.Path]::GetExtension($content)
            Switch($ext){
                ".json"{
                    Write-Host "Replacing value in $thisFolder\$content"
                    EditFileTemplate "$thisFolder\$content"
                    Write-Host "$thisFolder\$content done" -ForegroundColor Green
                }
                ".msapp"{
                    Write-Host "Temporary extract msapp file"
                    $msappFileName = [System.IO.Path]::GetFileNameWithoutExtension("$thisFolder\$content")
                    New-Item -Path "$parentFolder\Temp\$newSolutionFolder" -Name $msappFileName -ItemType "directory" | Out-Null

                    Copy-Item "$thisFolder\$content" -Destination "$parentFolder\Temp\$newSolutionFolder\$content"
                    Rename-Item "$parentFolder\Temp\$newSolutionFolder\$content" "$msappFileName.zip"

                    Expand-Archive "$parentFolder\Temp\$newSolutionFolder\$msappFileName.zip" -DestinationPath "$parentFolder\Temp\$newSolutionFolder\$msappFileName"
                    Write-Host "Exctracted into $parentFolder\Temp\$newSolutionFolder\$msappFileName"
                    Remove-Item -Path "$parentFolder\Temp\$newSolutionFolder\$msappFileName.zip" -Force
                    Remove-Item -Path "$thisFolder\$content" -Force

                    ParseFilesNFolders -thisFolder "$parentFolder\Temp\$newSolutionFolder\$msappFileName"

                    Write-Host "Compress $parentFolder\Temp\$newSolutionFolder\$msappFileName folder and save it into $thisFolder"
                    Compress-Archive -Path "$parentFolder\Temp\$newSolutionFolder\$msappFileName\*" -DestinationPath "$thisFolder\$msappFileName.zip"
                    Write-Host "Rename $msappFileName.zip into $content"
                    Rename-Item "$thisFolder\$msappFileName.zip" "$content"
                    Write-Host "$content regenerated" -ForegroundColor Green

                }
                Default{
                    Write-Host "Default : $ext"
                }
            }
        }
    }
}


# Global Var
$rootFolder = Split-Path (Get-ScriptDirectory) -Parent
[XML]$solutionfile = Get-Content "$rootFolder\Solution\Other\Solution.xml"
$solutionName = $solutionfile.ImportExportXml.SolutionManifest.UniqueName
$strNow = Get-Date -Format "yyyyMMdd_HHmm"
$newSolutionFolder = "$($solutionName)"

################
#### SCRIPT ####
################

try{
    
    $scriptLocation = Get-ScriptDirectory
    #Check if Output and Temp folder exist
    Write-Host "Check if Output folder exist"
    If(Test-Path "$scriptLocation\Output"){
        Write-Host "Output folder exist" -ForegroundColor Green
    }
    else{
        Write-Host "Output folder doesn't exist, creation in progress" -ForegroundColor Yellow
        New-Item -Path "$scriptLocation" -Name "Output" -ItemType "directory" | Out-Null
        Write-Host "Output file created" -ForegroundColor Green
    }

    Write-Host "Check if Temp folder exist"
    If(Test-Path "$scriptLocation\Temp"){
        Write-Host "Temp folder exist" -ForegroundColor Green
    }
    else{
        Write-Host "Temp folder doesn't exist, creation in progress" -ForegroundColor Yellow
        New-Item -Path "$scriptLocation" -Name "Temp" -ItemType "directory" | Out-Null
        Write-Host "Temp file created" -ForegroundColor Green
    }

    Write-Host ""

    #Get zip file name and create folder in Output Temp file
    Write-Host "Creating folder $newSolutionFolder in Output"
    New-Item -Path "$scriptLocation\Output" -Name $newSolutionFolder -ItemType "directory" | Out-Null
    Write-Host "$newSolutionFolder created in $scriptLocation\Output" -ForegroundColor Green
    Write-Host "Creating folder $newSolutionFolder in Temp"
    New-Item -Path "$scriptLocation\Temp" -Name $newSolutionFolder -ItemType "directory" | Out-Null
    Write-Host "$newSolutionFolder created in $scriptLocation\Temp" -ForegroundColor Green
    Write-Host ""


    #Copy the source code from solution folder to output folder
        
    Copy-Item -Path "$rootFolder\Solution\*" -Destination "$scriptLocation\Output\$newSolutionFolder" -Recurse

    #Parse folder solution
    Write-Host "Parse file and folder in $scriptLocation\Output\$newSolutionFolder"

    ParseFilesNFolders -thisFolder "$scriptLocation\Output\$newSolutionFolder"

    Write-Host ""

    #Rebuild solution
    Write-Host "Rebuild solution"
    #Compress-Archive -Path ".\Output\$newSolutionFolder\*" -DestinationPath ".\Output\$newSolutionFolder.zip"
    #C:\CRM\Tools\CoreTools\SolutionPackager.exe /action:Pack /zipfile:"$scriptLocation\$newSolutionFolder.zip" /folder:"$scriptLocation\Output\$newSolutionFolder" /packagetype:Both /allowDelete:No
   
    Write-Host "New solution:" -ForegroundColor Green
    Write-Host "$scriptLocation\$newSolutionFolder.zip"-BackgroundColor DarkGreen

}
catch{
    Write-Host "ERROR:" -ForegroundColor Red
    Write-Host $_.Exception.Message -ForegroundColor Red
}

