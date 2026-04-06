# Azure Failure Simulator

Azure Failure Simulator is a PowerShell module that executes controlled fault experiments against Azure resources. It uses an experiment definition format inspired by Azure Chaos Studio concepts (steps, branches, actions, selectors), then orchestrates shutdown, failover, delay, and reboot workflows with traceable restore operations.

This project is designed for resiliency testing, incident rehearsal, and validating runbooks, and can be used in production environments for controlled chaos testing.

## Why this project

- Run repeatable resilience experiments from JSON definitions.
- Target multiple Azure resource types with one orchestration model.
- Capture execution trace for post-experiment analysis.
- Restore resources in reverse execution order.
- Support scoped targeting with selector filters, including AKS zones and node pools.

## Current status

- PowerShell Gallery package: AzureFailureSimulator
- Latest published version: 1.0.16
- License: MIT
- PowerShell: 7.0+
- Primary module manifest: [AzureFailureSimulator/AzureFailureSimulator.psd1](AzureFailureSimulator/AzureFailureSimulator.psd1)

## Repository layout

- Module root: [AzureFailureSimulator](AzureFailureSimulator)
- Public functions: [AzureFailureSimulator/functions](AzureFailureSimulator/functions)
- Internal helpers: [AzureFailureSimulator/internal/functions](AzureFailureSimulator/internal/functions)
- Tests: [AzureFailureSimulator/tests](AzureFailureSimulator/tests)
- Helper experiments: [Helper](Helper)
- Build scripts: [build](build)

## Prerequisites

- PowerShell 7+
- Azure authentication with sufficient permissions on target resources
- Required modules (from module manifest):
	- PSFramework
	- Az.Aks
	- Az.Compute
	- Az.PostgreSql
	- Az.RedisCache
	- Az.Resources

## Installation

### Install from PowerShell Gallery

	Install-PSResource AzureFailureSimulator -Repository PSGallery -TrustRepository
	Import-Module AzureFailureSimulator -Force

## Quick start

1. Sign in to Azure.
2. Import the module.
3. Import an experiment JSON file.
4. Invoke experiment.
5. Review trace.
6. Restore resources.

Example:

		Connect-AzAccount
		Import-Module ./AzureFailureSimulator/AzureFailureSimulator.psd1 -Force

		Import-AzureFailureExperiment -Path ./Helper/Simulation01-AKS.jsonc
		Invoke-AzureFailureExperiment -Verbose

		Get-AzureFailureTrace | Format-List *

		Restore-AzureFailureExperiment -Verbose

## Execution model

- Steps run sequentially.
- Branches within a step run in parallel.
- Actions within a branch run sequentially.
- Restore runs in reverse order:
	- steps: reverse
	- branches: reverse
	- actions: reverse

Reference: [Helper/AnatomyOfAnExperiment.md](Helper/AnatomyOfAnExperiment.md)

## Experiment schema overview

Top-level shape:

		{
			"name": "ExperimentName",
			"apiVersion": "2025-09-22",
			"properties": {
				"selectors": [ ... ],
				"steps": [ ... ]
			}
		}

### Selectors

Selectors are named target groups.

List selector shape:

		{
			"id": "AKSSelector",
			"type": "List",
			"targets": [
				{
					"type": "ChaosTarget",
					"id": "/subscriptions/.../resourceGroups/.../providers/Microsoft.ContainerService/managedClusters/myaks"
				}
			],
			"filter": {
				"type": "Simple",
				"parameters": {
					"zones": ["1"],
					"nodepool": ["agentpool", "userpool"]
				}
			}
		}

### Steps, branches, actions

Action shape:

		{
			"name": "urn:csci:microsoft:AKS:shutdown/1.0",
			"type": "continuous",
			"selectorId": "AKSSelector",
			"duration": "PT10M",
			"parameters": [
				{ "key": "abruptShutdown", "value": true },
				{ "key": "disableAutoScale", "value": true }
			]
		}

## Supported actions

The current action catalog is defined in [AzureFailureSimulator/internal/scripts/variables.ps1](AzureFailureSimulator/internal/scripts/variables.ps1).

- urn:csci:microsoft:virtualMachine:shutdown/1.0
- urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0
- urn:csci:microsoft:AKS:shutdown/1.0
- urn:csci:microsoft:DBforPostgreSQLFlexibleServers:failover/1.0
- urn:csci:microsoft:azureClusteredCacheForRedis:reboot/1.0
- urn:csci:microsoft:chaosStudio:timedDelay/1.0
- urn:csci:microsoft:chaosStudio:waitForInput/1.0

Discover at runtime:

		Get-AzureFailureActionList

## Filters and targeting

### VM Scale Sets

- Filter supports zones array.
- Applied to VMSS instances by zone.

### PostgreSQL Flexible Server

- Filter supports zones array.
- Failover executes only when the server zone is in filter.

### AKS

- Filter now supports:
	- zones: array of zones
	- nodepool: array of AKS node pool names
- For AKS selectors, at least one of zones or nodepool is required when filter is present.
- Nodepool filter scopes the selected AKS node pools before shutdown/auto-scale operations.
- Zone filter is passed to the VMSS shutdown stage for instance-level targeting.

Example AKS filter:

		"filter": {
			"type": "Simple",
			"parameters": {
				"zones": ["1"],
				"nodepool": ["agentpool", "userpool"]
			}
		}

Example file: [Helper/Simulation01-AKS.jsonc](Helper/Simulation01-AKS.jsonc)

## Core command flow

### Import experiment

		Import-AzureFailureExperiment -Path ./Helper/Simulation01.jsonc

### Inspect parsed state

		Get-AzureFailureSelector
		Get-AzureFailureStep
		Get-AzureFailureBranch
		Get-AzureFailureActionList

### Execute

		Invoke-AzureFailureExperiment -Verbose

Optional tracing and logs:

		Invoke-AzureFailureExperiment -TraceOutputPath ./trace.json -LogFolderPath ./logs -Verbose

### Review trace

		Get-AzureFailureTrace | Format-Table -AutoSize

### Restore

		Restore-AzureFailureExperiment -Verbose

Include previously skipped resources during restore:

		Restore-AzureFailureExperiment -RestoreSkipped -Verbose

## Reference examples

- AKS sample: [Helper/Simulation01-AKS.jsonc](Helper/Simulation01-AKS.jsonc)
- Mixed sample: [Helper/Simulation01.jsonc](Helper/Simulation01.jsonc)
- VMs sample: [Helper/Simulation01-VMs.jsonc](Helper/Simulation01-VMs.jsonc)
- VMSS sample: [Helper/Simulation01-VMs-Failure.jsonc](Helper/Simulation01-VMs-Failure.jsonc)
- PostgreSQL + Redis sample: [Helper/Simulation01-PosgreSQL-Redis.jsonc](Helper/Simulation01-PosgreSQL-Redis.jsonc)

## Safety guidance

- Use dedicated test subscriptions or isolated resource groups.
- Validate role assignments before running experiments.
- Start with short durations and a narrow selector scope.
- Prefer non-abrupt shutdown unless data-loss scenarios are intended.
- Always test restore workflows.

## Testing and validation

Run test suite:

		./AzureFailureSimulator/tests/pester.ps1

Pipeline validation entrypoint:

		./build/vsts-validate.ps1

## Troubleshooting

### Import errors

- Ensure required modules are installed.
- Verify PowerShell 7+.

### Selector validation errors

- Confirm all selector targets share one resource type.
- Confirm each target id is a valid Azure resource id.
- Confirm filter shape matches target type.

### Action validation errors

- Confirm action URN exists in action list.
- Confirm action type is continuous, discrete, or delay.
- Confirm duration uses ISO 8601 format (example: PT10M).

### AKS nodepool filter mismatches

- Node pool names are matched by AKS agent pool name.
- If requested node pools are not found, warnings are emitted and the target can be skipped.

## Development

Useful files:

- Module entrypoint: [AzureFailureSimulator/AzureFailureSimulator.psm1](AzureFailureSimulator/AzureFailureSimulator.psm1)
- Action registry: [AzureFailureSimulator/internal/scripts/variables.ps1](AzureFailureSimulator/internal/scripts/variables.ps1)
- Selector registration: [AzureFailureSimulator/functions/Selectors/Register-AzureFailureSelector.ps1](AzureFailureSimulator/functions/Selectors/Register-AzureFailureSelector.ps1)
- Experiment invoke: [AzureFailureSimulator/functions/Invoke-AzureFailureExperiment.ps1](AzureFailureSimulator/functions/Invoke-AzureFailureExperiment.ps1)
- Experiment restore: [AzureFailureSimulator/functions/Restore-AzureFailureExperiment.ps1](AzureFailureSimulator/functions/Restore-AzureFailureExperiment.ps1)

## Contributing

1. Fork and create a feature branch.
2. Add or update experiments under [Helper](Helper) when behavior changes.
3. Run test suite.
4. Submit PR with behavior summary and sample trace.

## License

MIT License. See [LICENSE](LICENSE).
