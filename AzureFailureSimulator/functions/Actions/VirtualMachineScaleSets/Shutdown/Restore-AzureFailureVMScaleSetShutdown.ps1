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
        [bool] $AbruptShutdown = $false,

        [string] $ActionName = "urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0",
        [bool] $RestoreSkipped = $script:RestoreSkipped
    )

    Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target(s) ($($TargetResourceId -join ', ')): Starting VM Scale Set Instances"

    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        $targetTrace = Get-AzureFailureTrace | Where-Object {
            $_.ResourceId -eq $target -and
            $_.Step -eq $Step -and
            $_.Branch -eq $Branch -and
            $_.Action -eq $ActionName
        }

        if ($targetTrace.ActionStatus -eq "Skipped" -and -not $RestoreSkipped) {
            Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Action was previously skipped. No instances to start."
            $actionJobs += $false
            continue
        }

        if ($RestoreSkipped) {
            $targetInstances = $targetTrace.TargetDetails.VMSSInstances
        }
        else{
            $targetInstances = $targetTrace.TargetDetails.VMSSInstancesToStop
        }
        Write-PSFMessage -Level Verbose -Message "Starting VM Scale Set: $target - Instances ($($targetInstances -join ', '))"
        $vmSS = Get-AzVmss -ResourceId $target

        # Update trace to Restoring status
        $paramUpdateAzureFailureTrace = @{
            ResourceId               = $target
            Step                     = $Step
            Branch                   = $Branch
            Action                   = $ActionName
            ActionStatus             = "Restoring"
            ActionRestoreTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace

        $actionJobs += $vmSS | Start-AzVmss -InstanceId $targetInstances -AsJob

    }
    if ($actionJobs | Where-Object { $_ -ne $false }) {
        Write-PSFMessage -Level Verbose -Message "Waiting for VM Scale Set start jobs to complete"
        $null = Wait-Job -Job ($actionJobs | Where-Object { $_ -ne $false })
        Write-PSFMessage -Level Verbose -Message "VM Scale Set start jobs complete"
    }
    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        if ($actionJobs[$i]) {
            try {
                $null = $actionJobs[$i] | Receive-Job -ErrorAction Stop
                $paramUpdateAzureFailureTrace = @{
                    ResourceId                = $TargetResourceId[$i]
                    Step                      = $Step
                    Branch                    = $Branch
                    Action                    = $ActionName
                    ActionStatus              = "Restored"
                    ActionRestoreCompleteTime = ($actionJobs[$i].PSEndTime )
                }
                Update-AzureFailureTrace @paramUpdateAzureFailureTrace
            }
            catch {
                Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($($TargetResourceId[$i])): Failed to restore VM Scale Set. Error: $($_.Exception.Message)."
                $paramUpdateAzureFailureTrace = @{
                    ResourceId                = $TargetResourceId[$i]
                    Step                      = $Step
                    Branch                    = $Branch
                    Action                    = $ActionName
                    ActionStatus              = "RestoreError"
                    ActionMessage             = 'Failed to restore VM Scale Set - {0}' -f ($_.Exception.Message -replace "`r`n", "\n")
                    ActionRestoreCompleteTime = Get-Date
                }
                Update-AzureFailureTrace @paramUpdateAzureFailureTrace
            }
        }
    }
}