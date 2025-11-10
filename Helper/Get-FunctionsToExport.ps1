
$strings = (Get-ChildItem -Path .\src\AzureFailureSimulator\functions -Recurse -Filter *.ps1).BaseName | sort
Update-PSFModuleManifest -Path .\src\AzureFailureSimulator\AzureFailureSimulator.psd1 -FunctionsToExport $strings
