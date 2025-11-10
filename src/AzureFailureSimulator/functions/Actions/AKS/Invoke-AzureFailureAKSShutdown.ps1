<#
    .SYNOPSIS
        Invokes a shutdown action on an Azure Kubernetes Service (AKS) cluster.
    .DESCRIPTION
        1) Find all node pools and their respective VMSS
        2) Disable Auto-Scaling on each node pool
        3) Shutdown all VMSS instances in each node pool in the targetted Zone(s) if specified.
#>
function Invoke-AzureFailureAKSShutdown {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        [string] $Duration,
        [string[]] $Filter,
        [bool] $AbruptShutdown = $false,

        [string] $ActionName = "urn:csci:microsoft:AKS:shutdown/1.0"

    )


    foreach ($target in $TargetResourceId) {
        Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Getting AKS Node Pools"

        $aksCluster = Get-AzAksCluster -Id $target

        $nodeResourceGroup = $aksCluster.NodeResourceGroup
        $agentPoolProfile = $aksCluster.AgentPoolProfiles

        Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Found $($agentPoolProfile.Count) Node Pools in AKS Cluster. ($($agentPoolProfile.Name -join ', '))"

        $autoScaleTargetDetails = @{}
        foreach ($nodePool in $agentPoolProfile) {
            $autoScaleTargetDetails[$nodePool.Name] = @{
                AutoScaling = $nodePool.EnableAutoScaling
                MinCount    = $nodePool.MinCount
                MaxCount    = $nodePool.MaxCount
            }
            $actionJobs = @()
            if ($nodePool.EnableAutoScaling) {
                Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Disabling Auto-Scaling on Node Pool: $($nodePool.Name)"
                if ($PSCmdlet.ShouldProcess("Disable Auto-Scaling on Node Pool: $($nodePool.Name)")) {
                    $actionJobs += Update-AzAksNodePool -ClusterObject $aksCluster -Name $nodePool.Name -EnableAutoScaling:$false -AsJob
                }
            }
        }
        # For AKS Nodes we are updating AutoScale on all pools as one action in the trace.
        $paramUpdateAzureFailureTrace = @{
            Step              = $Step
            Branch            = $Branch
            ResourceId        = $target
            TargetDetails     = $autoScaleTargetDetails
            Action            = $ActionName
            ActionSkipped     = $false
            ActionSkipMessage = ""
            ActionTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
        if ($actionJobs) {
            Write-PSFMessage -Level Verbose -Message "Waiting for AKS Node Pool Auto-Scaling disable jobs to complete"
            $null = Wait-Job -Job ($actionJobs | Where-Object { $_ -ne $false })
            Write-PSFMessage -Level Verbose -Message "AKS Node Pool Auto-Scaling disable jobs complete"
        }


        $actionCompleteTime = Get-Date
        $paramUpdateAzureFailureTrace = @{
            ResourceId         = $target
            Step               = $Step
            Branch             = $Branch
            Action             = $actionName
            ActionCompleteTime = $actionCompleteTime
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace



        # Utilize VMSS shutdown action to shutdown the instances in each node pool
        $vmssResourceIds = ($agentPoolProfile.Name | ForEach-Object { Get-AzResource -ResourceGroupName $nodeResourceGroup -ResourceType 'Microsoft.Compute/virtualMachineScaleSets' -TagName 'aks-managed-poolName' -TagValue $_ }).ResourceId
        Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Corresponding VMSS Resource Ids: $($vmssResourceIds -join ', ')"

        $paramInvokeAzureFailureVMScaleSetShutdown = @{
            Step             = $Step
            Branch           = $Branch
            TargetResourceId = $vmssResourceIds
            Duration         = $Duration
            Filter           = $Filter
            AbruptShutdown   = $AbruptShutdown
            ActionName       = $actionName
        }
        Invoke-AzureFailureVMScaleSetShutdown @paramInvokeAzureFailureVMScaleSetShutdown
    }
}