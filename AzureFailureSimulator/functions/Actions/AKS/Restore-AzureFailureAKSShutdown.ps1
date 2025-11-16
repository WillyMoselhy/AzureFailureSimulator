function Restore-AzureFailureAKSShutdown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        # These might not be used but added for consistency.
        [string] $Duration,
        [bool] $AbruptShutdown = $false,

        [string] $ActionName = "urn:csci:microsoft:AKS:shutdown/1.0"

    )

    Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target(s) ($($TargetResourceId -join ', ')): Starting AKS Instances"

    foreach ($target in $TargetResourceId) {
        $aksCluster = Get-AzAksCluster -Id $target

        $nodeResourceGroup = $aksCluster.NodeResourceGroup
        $agentPoolProfile = $aksCluster.AgentPoolProfiles

        Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Found $($agentPoolProfile.Count) Node Pools in AKS Cluster. ($($agentPoolProfile.Name -join ', '))"


        $vmssResourceIds = ($agentPoolProfile.Name | ForEach-Object { Get-AzResource -ResourceGroupName $nodeResourceGroup -ResourceType 'Microsoft.Compute/virtualMachineScaleSets' -TagName 'aks-managed-poolName' -TagValue $_ }).ResourceId
        Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Corresponding VMSS Resource Ids: $($vmssResourceIds -join ', ')"

        $paramRestoreAzureFailureVMScaleSetShutdown = @{
            Step             = $Step
            Branch           = $Branch
            TargetResourceId = $vmssResourceIds
            Duration         = $Duration
            AbruptShutdown   = $AbruptShutdown
            ActionName       = $ActionName
        }
        Restore-AzureFailureVMScaleSetShutdown @paramRestoreAzureFailureVMScaleSetShutdown


        # Restore each node pool's auto-scaling settings
        $targetTrace = Get-AzureFailureTrace | Where-Object {
            $_.ResourceId -eq $target -and
            $_.Step -eq $Step -and
            $_.Branch -eq $Branch -and
            $_.Action -eq $ActionName
        }
        $actionJobs = @()
        if ($targetTrace.ActionStatus -eq "Skipped") {
            Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Action was previously skipped. Skipping restore."
            $actionsJobs += $false

        }
        else {
            foreach ($nodePool in $agentPoolProfile) {
                $autoScaleSettings = $targetTrace.TargetDetails.$($nodePool.Name)
                if ($autoScaleSettings.AutoScaling) {
                    Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Restoring Auto-Scaling on Node Pool: $($nodePool.Name) with MinCount: $($autoScaleSettings.MinCount), MaxCount: $($autoScaleSettings.MaxCount)"
                    $actionJobs += Update-AzAksNodePool -ClusterObject $aksCluster -Name $nodePool.Name -EnableAutoScaling:$true -MinCount $autoScaleSettings.MinCount -MaxCount $autoScaleSettings.MaxCount -AsJob
                }
                else {
                    Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Auto-Scaling was not enabled on Node Pool: $($nodePool.Name). No action taken."
                    $actionJobs += $false
                }
            }
            $paramUpdateAzureFailureTrace = @{
                ResourceId               = $target
                Step                     = $Step
                Branch                   = $Branch
                Action                   = $ActionName
                ActionRestoreTriggerTime = Get-Date
            }
            Update-AzureFailureTrace @paramUpdateAzureFailureTrace
            if ($actionJobs | Where-Object { $_ -ne $false }) {
                Write-PSFMessage -Level Verbose -Message "Waiting for AKS Node Pool restore jobs to complete"
                $null = Wait-Job -Job ($actionJobs | Where-Object { $_ -ne $false })
                Write-PSFMessage -Level Verbose -Message "AKS Node Pool restore jobs complete"
            }
            $paramUpdateAzureFailureTrace = @{
                ResourceId                = $target
                Step                      = $Step
                Branch                    = $Branch
                Action                    = $ActionName
                ActionRestoreCompleteTime = Get-Date
            }
            Update-AzureFailureTrace @paramUpdateAzureFailureTrace
        }
    }
}