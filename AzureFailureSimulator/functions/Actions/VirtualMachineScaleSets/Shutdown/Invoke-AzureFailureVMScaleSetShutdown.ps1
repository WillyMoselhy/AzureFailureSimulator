function Invoke-AzureFailureVMScaleSetShutdown {
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

        [string] $ActionName = "urn:csci:microsoft:virtualMachineScaleSet:shutdown/2.0"
    )
    if ($AbruptShutdown) {
        Write-PSFMessage -Level Warning -Message "Abrupt Shutdown enabled. This may cause data loss or corruption on the target VM(s)."
    }

    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        $actionJob = @{
            TargetResourceId = $target
        }
        Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Getting VMSS instances"

        try {
            $vmSS = Get-AzVmss -ResourceId $target -ErrorAction Stop
            $vmSSInstances = $vmSS | Get-AzVmssVM -InstanceView

            Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Found $($vmSSInstances.Count) instances in VMSS"
            if ($Filter) {
                $vmSSInstances = $vmSSInstances | Where-Object { $_.Zones[0] -in $Filter }
                Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Filtered to $($vmSSInstances.Count) instances in Zone(s): $($Filter -join ', ')"
            }
            $vmSSInstancesToStop = $vmSSInstances | Where-Object { $_.InstanceView.Statuses[1].Code -eq "PowerState/running" }

            if ($vmSSInstancesToStop) {
                Write-PSFMessage -Level Verbose -Message "Step ($Step) - Branch ($Branch) - Target ($target): Stopping $($vmSSInstancesToStop.Count) running instances in VMSS [$($vmSSInstancesToStop.InstanceId -join ', ')]"

                if ($PSCmdlet.ShouldProcess("VMSS Instances", "Stop") ) {
                    $actionJob.Job = $vmSS | Stop-AzVmss -InstanceId $vmSSInstancesToStop.InstanceId -Force:$true -SkipShutdown:$AbruptShutdown -StayProvisioned -AsJob
                }

                $actionJob.Status = "InProgress"
                $actionJob.StatusMessage = ''
            }
            else {
                Write-PSFMessage -Level Warning -Message "Step ($Step) - Branch ($Branch) - Target ($target): No running instances found in VMSS to stop"
                $actionJob.Job = $false

                $actionJob.Status = "Skipped"
                $actionJob.StatusMessage = 'No running instances found in VM Scale set to stop'
            }

            $actionJob.TargetDetails = @{
                VMSSInstancesToStop = $vmSSInstancesToStop.InstanceId
                VMSSInstances = $vmSSInstances.InstanceId
            }
        }
        catch {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Failed to get VMSS status. Error: $($_.Exception.Message)."
            $actionJob.Job = $false
            $actionJob.Status = "Error"
            $actionJob.StatusMessage = 'Failed to get VMSS status - {0}' -f ($_.Exception.Message -replace "`r`n", "\n")
            $actionJob.TargetDetails = @{}
        }

        $actionJobs += $actionJob

        $paramUpdateAzureFailureTrace = @{
            Step              = $Step
            Branch            = $Branch
            ResourceId        = $target
            TargetDetails     = $actionJob.TargetDetails
            Action            = $actionName
            ActionStatus      = $actionJob.Status
            ActionMessage     = $actionJob.StatusMessage
            ActionTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }

    $jobsToWaitFor = ($actionJobs | Where-Object { $_.Job -ne $false }).Job
    if ($jobsToWaitFor) {
        Write-PSFMessage -Level Verbose -Message "Waiting for {0} VM Scale Set shutdown jobs to complete" -StringValues $jobsToWaitFor.Count
        $null = Wait-Job -Job $jobsToWaitFor
        Write-PSFMessage -Level Verbose -Message "VM Scale Set shutdown jobs complete"
    }

    foreach ($actionJob in $actionJobs) {
        if($actionJob.Status -in @("Error", "Skipped")) {
            $actionStatus = $actionJob.Status
        }
        elseif($actionJob.Job.State -eq "Failed") {
            $actionStatus = "Error"
            $actionJob.StatusMessage = 'VMSS shutdown job failed: {0}' -f ($actionJob.Job.Error[0].Exception.Message -replace "`r`n", "\n")
        }
        else{
            $actionStatus = if ($WhatIfPreference) { "WhatIf" } else { "Success" }
        }
        $actionCompleteTime = if ($actionJob.Job) { ($actionJob.Job | Receive-Job).EndTime } else { Get-Date }
        $paramUpdateAzureFailureTrace = @{
            ResourceId         = $actionJob.TargetResourceId
            Step               = $Step
            Branch             = $Branch
            Action             = $actionName
            ActionStatus       = $actionStatus
            ActionMessage      = $actionJob.StatusMessage
            ActionCompleteTime = $actionCompleteTime
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }
}
