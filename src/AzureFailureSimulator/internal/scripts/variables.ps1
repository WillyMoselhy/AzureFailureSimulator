$script:APIVersion = "2025-09-22"

$script:Selectors = @{}

$script:TargetTypes = @(
    "Microsoft.Compute/virtualMachines"
)

$script:Steps = @()
$script:Branches = @()

$script:tracerOutput = @()

$script:ActionList = @{
    "urn:csci:microsoft:virtualMachine:shutdown/1.0" = @{
        TargetType       = "Microsoft.Compute/virtualMachines"
        Parameters       = @(
            @{ Name = "abruptShutdown"; Type = "bool"; Required = $false }
        )
        SupportsDuration = $true
        Command          = "Invoke-AzureFailureVMShutdown"
        RestoreCommand   = "Restore-AzureFailureVMShutdown"
    }
    "urn:csci:microsoft:chaosStudio:timedDelay/1.0"  = @{
        TargetType       = "delay"
        Parameters       = @()
        SupportsDuration = $true
        Command          = "Invoke-AzureFailureDelay"

    }
}
