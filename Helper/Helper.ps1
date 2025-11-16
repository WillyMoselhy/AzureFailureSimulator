
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


Reset-AzRedisCache -ResourceGroupName "vmss-demo" -Name "azurefailure" -RebootType "PrimaryNode" -Force -ShardId 0

$redis = (Get-AzRedisCache -ResourceGroupName "vmss-demo" -Name "azurefailure" -)

get-azrediscache

(Get-AzResource -ResourceGroupName "vmss-demo"  -Name "azurefailure" -ResourceType "Microsoft.Cache/Redis" -WarningAction SilentlyContinue).properties.Instances


$aksCluster = Get-AzAksCluster -Id '/subscriptions/44194899-7181-423a-9dbc-278d99a7683a/resourceGroups/vmss-demo/providers/Microsoft.ContainerService/managedClusters/aks-azurefailure'

Update-AzAksNodePool -ClusterObject $aksCluster -Name agentpool -EnableAutoScaling:$false
Update-AzAksNodePool -ClusterObject $aksCluster -Name agentpool -EnableAutoScaling:$true -MinCount 2 -MaxCount 5

$strings = (Get-ChildItem -Path .\src\AzureFailureSimulator\functions -Recurse -Filter *.ps1).BaseName | sort
Update-PSFModuleManifest -Path .\src\AzureFailureSimulator\AzureFailureSimulator.psd1 -FunctionsToExport $strings





remove-module AzureFailureSimulator -Force ; import-module .\AzureFailureSimulator

Import-AzureFailureExperiment -Path .\Helper\Simulation01-AKS.jsonc -Verbose

Invoke-AzureFailureExperiment -Verbose -LogFolderPath "C:\temp\SimulatorLogs" -TraceOutputPath "C:\temp\SimulatorLogs\tracerOutput01.csv" -WhatIf

Restore-AzureFailureExperiment -Verbose -RestoreSkipped


# ERRORS
* We Are not authenticated to Azure for example


# Find all the get-az* commands and list their module
$modulePath = ".\AzureFailureSimulator"
$commands = Get-ChildItem -Path "$modulePath\functions" -Recurse -Filter "*.ps1" | ForEach-Object {
    $content = [System.IO.File]::ReadAllText($_.FullName)
    $matches = [regex]::Matches($content, '\w*-Az[A-Za-z0-9_]+')
    foreach ($match in $matches) {
        $commandName = $match.Value
        $command = Get-Command -Name $commandName -ErrorAction SilentlyContinue
        if ($command) {
            [PSCustomObject]@{
                CommandName = $commandName
                ModuleName  = $command.ModuleName
                ModuleVersion = $command.Module.Version
                LatestModuleVersion = $moduleInfo.Version
            }
        }
    }
}
$latestModule = @{
    label = "LatestVersion"
    expression = {
        $moduleInfo = Find-PSResource -Name $_.ModuleName -ErrorAction SilentlyContinue
        $moduleInfo.Version
    }

}
$moduleList = $commands | Select-Object ModuleName, ModuleVersion -Unique | Select-Object ModuleName, ModuleVersion, $latestModule | Sort-Object ModuleName
#Print as a required module list and save it to clipboard
$moduleList | ForEach-Object {
    "        @{ ModuleName = '$($_.ModuleName)'; ModuleVersion = '$($_.ModuleVersion)' }"
} | Out-String | Set-Clipboard
