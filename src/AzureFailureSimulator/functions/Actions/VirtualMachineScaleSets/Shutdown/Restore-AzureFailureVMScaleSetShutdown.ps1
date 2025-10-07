function Restore-AzureFailureVMScaleSetShutdown {
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
        [bool] $AbruptShutdown = $false
    )

    Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target(s) ($($TargetResourceId -join ', ')): Starting VM Scale Set Instances"
    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        $targetTrace = Get-AzureFailureTrace | Where-Object {
            $_.ResourceId -eq $target -and
            $_.Step -eq $Step -and
            $_.Branch -eq $Branch -and
            $_.Action -eq "urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0"
        }

        if ($targetTrace.ActionSkipped) {
            Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Action was previously skipped. No instances to start."
            $actionsJobs += $false
            continue
        }

        $targetInstances = $targetTrace.TargetDetails.VMSSInstances
        Write-PSFMessage -Level Verbose -Message "Starting VM Scale Set: $target - Instances ($($targetInstances -join ', '))"
        $vmSS = Get-AzVmss -ResourceId $target

        $actionJobs += $vmSS | Start-AzVmss -InstanceId $targetInstances -AsJob

        $paramUpdateAzureFailureTrace = @{
            ResourceId               = $target
            Step                     = $Step
            Branch                   = $Branch
            Action                   = "urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0"
            ActionRestoreTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace

    }
    if ($actionJobs | Where-Object { $_ -ne $false }) {
        Write-PSFMessage -Level Verbose -Message "Waiting for VM Scale Set start jobs to complete"
        $null = Wait-Job -Job $actionJobs
        Write-PSFMessage -Level Verbose -Message "VM Scale Set start jobs complete"
    }
    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        if ($actionJobs[$i]) {
            $paramUpdateAzureFailureTrace = @{
                ResourceId                = $TargetResourceId[$i]
                Step                      = $Step
                Branch                    = $Branch
                Action                    = "urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0"
                ActionRestoreCompleteTime = ($actionJobs[$i] | Receive-Job).EndTime
            }
            Update-AzureFailureTrace @paramUpdateAzureFailureTrace
        }
        else {
            continue
        }
    }
}