
$targets = @(
    @{
        id = "/subscripions/44194899-7181-423a-9dbc-278d99a7683a/resourceGroups/adcb-lab/providers/microsoft.compute/virtualmachines/dc"
    }
)

$targets = @(
    @{
        id = "/subscriptions/44194899-7181-423a-9dbc-278d99a7683a/resourceGroups/adcb-lab/providers/microsoft.compute/virtualmachines/dc"
    }
    @{
        id = "/subscriptions/44194898-7181-423a-9dbc-278d99a7683a/resourceGroups/adcb-lab/providers/microsoft.compute/virtualmachines/dc"
    }
)
Register-AzureFailureSelector -Id "tesst" -Targets $targets -Verbose


# Action!

@{
    Name       = "ShutdownVM"
    TargetType = "Microsoft.Compute/virtualMachines"
    Parameters = @(
        @{ Name = "abruptShutdown"; Type = "bool"; Required = $false }
    )
    SupportsDuration = $true
    Command = ''
}

$functionsToExport = (Get-ChildItem -Path .\src\AzureFailureSimulator\functions -Recurse -Filter *.ps1).BaseName | sort
$moduleManifest = Import-PowerShellDataFile -Path .\src\AzureFailureSimulator\AzureFailureSimulator.psd1
$moduleManifest.FunctionsToExport = $functionsToExport
Export-PSFPowerShellDataFile -Path .\src\AzureFailureSimulator\AzureFailureSimulator.psd1 -InputObject $moduleManifest -Depth 99

$target = '/subscriptions/44194899-7181-423a-9dbc-278d99a7683a/resourceGroups/ADCB-Lab/providers/Microsoft.Compute/virtualMachines/dc'


Set-AzContext -SubscriptionId 'Labs'


$strings = (Get-ChildItem -Path .\src\AzureFailureSimulator\functions -Recurse -Filter *.ps1).BaseName | sort
Update-PSFModuleManifest -Path .\src\AzureFailureSimulator\AzureFailureSimulator.psd1 -FunctionsToExport $strings
remove-module AzureFailureSimulator -Force ; import-module .\src\AzureFailureSimulator



Import-AzureFailureExperiment -Path .\src\Helper\Simulation01.jsonc -verbose

Invoke-AzureFailureExperiment -Verbose -LogFolderPath "C:\temp\SimulatorLogs" -TraceOutputPath "C:\temp\SimulatorLogs\tracerOutput01.csv"

Restore-AzureFailureExperiment -Verbose