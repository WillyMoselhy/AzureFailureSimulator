remove-module AzureFailureSimulator -Force ; import-module .\src\AzureFailureSimulator

Import-AzureFailureExperiment -Path .\src\Helper\Simulation01-PosgreSQL-Redis.jsonc -verbose


Import-AzureFailureExperiment -Path .\src\Helper\Simulation01-PosgreSQL-Redis-Samir.jsonc -verbose


Restore-AzureFailureExperiment -Verbose