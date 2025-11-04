$script:APIVersion = "2025-09-22"

$script:Selectors = @{}

$script:TargetTypes = @(
    "Microsoft.Compute/virtualMachines"
    "Microsoft.Compute/virtualMachineScaleSets"
    "Microsoft.DBforPostgreSQL/flexibleServers"
    "Microsoft.Cache/Redis"
    "Microsoft.ContainerService/managedClusters"
)

$script:Steps = @()
$script:Branches = @()

$script:tracerOutput = @()

$script:RestoreSkipped  = $false

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
    "urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0" = @{
        TargetType       = "Microsoft.Compute/virtualMachineScaleSets"
        Parameters       = @(
            @{ Name = "abruptShutdown"; Type = "bool"; Required = $false }
        )
        SupportsDuration = $true
        SupportsFilter   = $true
        Command          = "Invoke-AzureFailureVMScaleSetShutdown"
        RestoreCommand   = "Restore-AzureFailureVMScaleSetShutdown"
    }
    "urn:csci:microsoft:AKS:shutdown/1.0" = @{
        TargetType       = "Microsoft.ContainerService/managedClusters"
        Parameters       = @(
            @{ Name = "abruptShutdown"; Type = "bool"; Required = $false }
        )
        SupportsDuration = $true
        SupportsFilter   = $true
        Command          = "Invoke-AzureFailureAKSShutdown"
        RestoreCommand   = "Restore-AzureFailureAKSShutdown"
    }
    "urn:csci:microsoft:DBforPostgreSLFlexibleServers:failover/1.0" = @{
        TargetType       = "Microsoft.DBforPostgreSQL/flexibleServers"
        Parameters       = @(
            @{ Name = "ForcedFailover"; Type = "bool"; Required = $false }
        )
        SupportsDuration = $true
        SupportsFilter   = $true
        Command          = "Invoke-AzureFailurePostgreSQLFlexibleServerFailover"
        RestoreCommand   = "Restore-AzureFailurePostgreSQLFlexibleServerFailover"
    }
    "urn:csci:microsoft:azureClusteredCacheForRedis:reboot/1.0" = @{
        TargetType       = "Microsoft.Cache/Redis"
        Parameters       = @(
            @{ Name = "RebootType"; Type = "string"; Required = $true } #TODO: Add ValidateSet
            @{ Name = "ShardId"; Type = "string"; Required = $false }
        )
        SupportsDuration = $false
        SupportsFilter   = $false
        Command          = "Invoke-AzureFailureCacheForRedisReboot"
    }
    "urn:csci:microsoft:chaosStudio:timedDelay/1.0"  = @{
        TargetType       = "delay"
        Parameters       = @()
        SupportsDuration = $true
        Command          = "Invoke-AzureFailureDelay"
    }
}
