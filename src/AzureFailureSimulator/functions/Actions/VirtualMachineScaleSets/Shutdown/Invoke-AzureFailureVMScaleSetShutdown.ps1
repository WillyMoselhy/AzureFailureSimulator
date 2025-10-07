function Invoke-AzureFailureVMScaleSetShutdown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        [string] $Duration,
        [string[]] $Filter,
        [bool] $AbruptShutdown = $false
    )
    if ($AbruptShutdown) {
        Write-PSFMessage -Level Warning -Message "Abrupt Shutdown enabled. This may cause data loss or corruption on the target VM(s)."
    }
    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Getting VMSS instances"
        $vmSS = Get-AzVmss -ResourceId $target
        $vmSSInstances = $vmSS | Get-AzVmssVM -InstanceView

        Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Found $($vmSSInstances.Count) instances in VMSS"
        if ($Filter) {
            $vmSSInstances = $vmSSInstances | Where-Object { $_.Zones[0] -in $Filter }
            Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Filtered to $($vmSSInstances.Count) instances in Zone(s): $($Filter -join ', ')"
        }
        $vmSSInstances = $vmSSInstances | Where-Object { $_.InstanceView.Statuses[1].Code -eq "PowerState/running" }

        if ($vmSSInstances) {
            Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Stopping $($vmSSInstances.Count) running instances in VMSS [$($vmSSInstances.InstanceId -join ', ')]"
            $actionJobs += $vmSS | Stop-AzVmss -InstanceId $vmSSInstances.InstanceId -Force:$true -SkipShutdown:$AbruptShutdown -StayProvisioned -AsJob

            $actionSkipped = $false
        }
        else {
            Write-PSFMessage -Level Warning -Message "Step ($Step) - Branch ($Branch) - Target ($target): No running instances found in VMSS to stop"
            $actionsJobs += $false

            $actionSkipped = $true
            $actionSkipMessage = 'No running instances found in VM Scale set to stop'
        }

        $paramUpdateAzureFailureTrace = @{
            Step              = $Step
            Branch            = $Branch
            ResourceId        = $target
            TargetDetails     = if ($vmSSInstances) {
                @{
                    VMSSInstances = $vmSSInstances.InstanceId
                }
            }
            else { $null }
            Action            = "urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0"
            ActionSkipped     = $actionSkipped
            ActionSkipMessage = $actionSkipMessage
            ActionTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }

    if ($actionJobs | Where-Object { $_ -ne $false }) {
        Write-PSFMessage -Level Verbose -Message "Waiting for VM Scale Set shutdown jobs to complete"
        $null = Wait-Job -Job $actionJobs
        Write-PSFMessage -Level Verbose -Message "VM Scale Set shutdown jobs complete"
    }

    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        $actionCompleteTime = if ($actionJobs[$i]) { ($actionJobs[$i] | Receive-Job).EndTime } else { Get-Date }
        $paramUpdateAzureFailureTrace = @{
            ResourceId         = $TargetResourceId[$i]
            Step               = $Step
            Branch             = $Branch
            Action             = "urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0"
            ActionCompleteTime = $actionCompleteTime
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }
}
