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



Write-Host "Installing modules $($modules -join '-')" -ForegroundColor Cyan
Install-PSResource $modules -AcceptLicense -TrustRepository