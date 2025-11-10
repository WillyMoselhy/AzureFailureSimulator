param (
    [string]
    $Repository = 'PSGallery'
)

#$modules = @("Pester", "PSFramework", "PSModuleDevelopment", "PSScriptAnalyzer")
$modules = @( "PSFramework")


# Automatically add missing dependencies
$data = Import-PowerShellDataFile -Path "$PSScriptRoot\..\AzureFailureSimulator\AzureFailureSimulator.psd1"
foreach ($dependency in $data.RequiredModules) {
    if ($dependency -is [string]) {
        if ($modules -contains $dependency) { continue }
        $modules += $dependency
    }
    else {
        if ($modules -contains $dependency.ModuleName) { continue }
        $modules += $dependency.ModuleName
    }
}


foreach ($module in $modules) {
    Write-Host "Installing $module" -ForegroundColor Cyan
    Install-PSResource $module -AcceptLicense -TrustRepository
    #Import-Module $module -Force -PassThru
}