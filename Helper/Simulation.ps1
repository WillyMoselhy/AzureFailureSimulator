Remove-Module AzureFailureSimulator -Force ; import-module .\AzureFailureSimulator

Import-AzureFailureExperiment -Path .\Helper\Simulation01-AKS.jsonc -Verbose

Invoke-AzureFailureExperiment -Verbose -LogFolderPath "C:\temp\SimulatorLogs" -TraceOutputPath "C:\temp\SimulatorLogs\tracerOutput01.csv"  -WhatIf

Restore-AzureFailureExperiment -Verbose -RestoreSkipped

