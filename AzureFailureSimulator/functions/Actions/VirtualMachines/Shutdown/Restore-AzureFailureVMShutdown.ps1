function Restore-AzureFailureVMShutdown {
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

        [string] $ActionName = "urn:csci:microsoft:virtualMachine:shutdown/1.0",

        [bool] $RestoreSkipped = $script:RestoreSkipped
    )

    Write-PSFMessage -Level Verbose -Message "Starting VM(s) for Step ($Step), Branch ($Branch), Target(s): $($TargetResourceId -join ', ')"
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

        Write-PSFMessage -Level Verbose -Message "Starting VM: $target"

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

        $actionJobs += Start-AzVM -Id $target -AsJob

    }
    if ($actionJobs | Where-Object { $_ -ne $false }) {

        $jobsToWaitFor = ($actionJobs | Where-Object { $_ -ne $false })
        Write-PSFMessage -Level Verbose -Message "Waiting for {0} VM start jobs to complete" -StringValues $jobsToWaitFor.Count

        Wait-AzureFailureJob -Jobs $jobsToWaitFor -Activity "Starting VMs"

        Write-PSFMessage -Level Verbose -Message "VM start jobs complete"
    }
    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        if ($actionJobs[$i]) {
            try {
                $jobResult = $actionJobs[$i] | Receive-Job -ErrorAction Stop
                $paramUpdateAzureFailureTrace = @{
                    ResourceId                = $TargetResourceId[$i]
                    Step                      = $Step
                    Branch                    = $Branch
                    Action                    = $ActionName
                    ActionStatus              = "Restored"
                    ActionRestoreCompleteTime = $jobResult.EndTime
                }
                Update-AzureFailureTrace @paramUpdateAzureFailureTrace
            }
            catch {
                Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($($TargetResourceId[$i])): Failed to restore VM. Error: $($_.Exception.Message)."
                $paramUpdateAzureFailureTrace = @{
                    ResourceId                = $TargetResourceId[$i]
                    Step                      = $Step
                    Branch                    = $Branch
                    Action                    = $ActionName
                    ActionStatus              = "RestoreError"
                    ActionMessage             = 'Failed to restore VM - {0}' -f ($_.Exception.Message -replace "`r`n", "\n")
                    ActionRestoreCompleteTime = Get-Date
                }
                Update-AzureFailureTrace @paramUpdateAzureFailureTrace
            }
        }
        else {
            continue
        }
    }
}