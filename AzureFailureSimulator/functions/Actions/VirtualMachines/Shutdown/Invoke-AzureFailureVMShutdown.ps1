function Invoke-AzureFailureVMShutdown {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        [string] $Duration,
        [bool] $AbruptShutdown = $false,

        [string] $ActionName = "urn:csci:microsoft:virtualMachine:shutdown/1.0"
    )


    if ($AbruptShutdown) {
        Write-PSFMessage -Level Warning -Message "Abrupt Shutdown enabled. This may cause data loss or corruption on the target VM(s)."
    }

    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        $actionJob = @{
            TargetResourceId = $target
        }
        Write-PSFMessage -Level Verbose -Message "Shutting down VM: $target"


        try {

            $vmStatus = Get-AzVM -ResourceId $target -Status -ErrorAction Stop
        }
        catch {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Failed to get VM status. Error: $($_.Exception.Message)."
            $actionJob.Job = $false
            $actionJob.Status = "Error"
            $actionJob.StatusMessage = 'Failed to get VM status - {0}' -f ($_.Exception.Message -replace "`r`n", "\n")

            $actionJobs += $actionJob

            $paramUpdateAzureFailureTrace = @{
                ResourceId        = $target
                Step              = $Step
                Branch            = $Branch
                Action            = $ActionName
                ActionStatus      = $actionJob.Status
                ActionMessage     = $actionJob.StatusMessage
                ActionTriggerTime = Get-Date
            }
            Update-AzureFailureTrace @paramUpdateAzureFailureTrace

            continue
        }

        if ( $vmStatus.Statuses[1].Code -eq "PowerState/running") {
            if ($PSCmdlet.ShouldProcess("Virtual Machine", "Shutdown")) {
                $actionJob.Job = Stop-AzVM -Id $target -Force:$true -SkipShutdown:$AbruptShutdown -AsJob
            }

            $actionJob.Status = "InProgress"
        }
        else {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): VM is not in 'running' state. Current state: $($vmStatus.Statuses[1].DisplayStatus). Skipping shutdown."
            $actionJob.Job = $false
            $actionJob.Status = "Skipped"
            $actionJob.StatusMessage = 'VM is not in running state'
        }

        $actionJobs += $actionJob

        $paramUpdateAzureFailureTrace = @{
            ResourceId        = $target
            Step              = $Step
            Branch            = $Branch
            Action            = $ActionName
            ActionStatus      = $actionJob.Status
            ActionMessage     = $actionJob.StatusMessage
            ActionTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }

    $jobsToWaitFor = ($actionJobs | Where-Object { $_.Job -ne $false }).Job
    if ($jobsToWaitFor) {

        Write-PSFMessage -Level Verbose -Message "Waiting for {0} VM shutdown jobs to complete" -StringValues $jobsToWaitFor.Count

        $null = Wait-Job -Job $jobsToWaitFor

        Write-PSFMessage -Level Verbose -Message "VM shutdown jobs complete"
    }

    foreach ($actionJob in $actionJobs) {
        if ($actionJob.Status -in @("Error", "Skipped")) { #TODO: Handle errors in the $actionJob.Job
            $actionStatus = $actionJob.Status
        }
        elseif ($actionJob.Job.State -eq "Failed") {
            $actionStatus = "Error"
            $actionJob.StatusMessage = 'VM shutdown job failed: {0}' -f ($actionJob.Job.Error[0].Exception.Message -replace "`r`n", "\n")
        }
        else {
            $actionStatus = if ($WhatIfPreference) { "WhatIf" } else { "Success" }
        }
        $actionCompleteTime = if ($actionJob.Job) { ($actionJob.Job | Receive-Job).EndTime } else { Get-Date }
        $paramUpdateAzureFailureTrace = @{
            ResourceId         = $actionJob.TargetResourceId
            Step               = $Step
            Branch             = $Branch
            ActionStatus       = $actionStatus
            ActionMessage      = $actionJob.StatusMessage
            Action             = $ActionName
            ActionCompleteTime = $actionCompleteTime
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }


}
