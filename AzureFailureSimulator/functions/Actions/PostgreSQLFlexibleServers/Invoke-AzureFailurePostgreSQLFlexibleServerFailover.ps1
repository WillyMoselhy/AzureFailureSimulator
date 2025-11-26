function Invoke-AzureFailurePostgreSQLFlexibleServerFailover {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        [string] $Duration,

        [Parameter(Mandatory = $true)]
        [string[]] $Filter,

        [bool] $ForcedFailover = $false,

        [string] $ActionName = "urn:csci:microsoft:DBforPostgreSLFlexibleServers:failover/1.0",

        [bool] $RestoreSkipped = $script:RestoreSkipped
    )

    if ($RestoreSkipped) {
        Write-PSFMessage -Level Verbose -Message "This action does not support restore of previously skipped actions."
    }

    if ($ForcedFailover) {
        Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), action ($ActionName):Forced Failover enabled. This may cause data loss."
    }

    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        $actionJob = @{
            TargetResourceId = $target
        }
        Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Failing Over."

        try {
            $pgSQLFlexibleServer = Get-AzPostgreSqlFlexibleServer -InputObject $target -ErrorAction Stop

            if ($pgSQLFlexibleServer.HighAvailabilityMode -ne "ZoneRedundant") {
                Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Server is not configured for High Availability. Failover cannot be performed."
                $actionJob.Job = $false
                $actionJob.Status = "Skipped"
                $actionJob.StatusMessage = 'Not configured for High Availability'
            }
            elseif ($pgSQLFlexibleServer.HighAvailabilityState -ne "Healthy" -or $pgSQLFlexibleServer.State -ne "Ready") {
                Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Server is not in a Healthy and Ready State. Failover cannot be performed."
                $actionJob.Job = $false
                $actionJob.Status = "Skipped"
                $actionJob.StatusMessage = 'Not in a Healthy and Ready State'
            }
            elseif ($pgSQLFlexibleServer.AvailabilityZone -notin $Filter) {
                Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Server is not in the specified filter zones. Skipping failover."
                $actionJob.Job = $false
                $actionJob.Status = "Skipped"
                $actionJob.StatusMessage = 'Not in the specified filter zones'
            }
            else {
                if ($ForcedFailover) {
                    $paramFailoverMode = 'ForcedFailover'
                }
                else {
                    $paramFailoverMode = 'PlannedFailover'
                }
                $rgName = ($target -split '/')[4]
                $serverName = ($target -split '/')[-1]

                if ($PSCmdlet.ShouldProcess("PostgreSQL Flexible Server", "Failover")) {
                    $actionJob.Job = Restart-AzPostgreSqlFlexibleServer -ResourceGroupName $rgName -Name $serverName -RestartWithFailover -FailoverMode $paramFailoverMode -AsJob
                }

                $actionJob.Status = "InProgress"
            }
        }
        catch {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Failed to get PostgreSQL server status. Error: $($_.Exception.Message)."
            $actionJob.Job = $false
            $actionJob.Status = "Error"
            $actionJob.StatusMessage = 'Failed to get PostgreSQL server status - {0}' -f ($_.Exception.Message -replace "`r`n", "\n")
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

        Write-PSFMessage -Level Verbose -Message "Waiting for {0} PostgreSQL Flexible Server failover jobs to complete" -StringValues $jobsToWaitFor.Count

        $null = Wait-Job -Job $jobsToWaitFor

        Write-PSFMessage -Level Verbose -Message "PostgreSQL Flexible Server failover jobs complete"
    }

    foreach ($actionJob in $actionJobs) {
        if($actionJob.Status -in @("Error", "Skipped")) {
            $actionStatus = $actionJob.Status
        }
        elseif($actionJob.Job.State -eq "Failed") {
            $actionStatus = "Error"
            $actionJob.StatusMessage = 'PostgreSQL failover job failed: {0}' -f ($actionJob.Job.Error[0].Exception.Message -replace "`r`n", "\n")
        }
        else{
            $actionStatus = if ($WhatIfPreference) { "WhatIf" } else { "Success" }
        }
        $actionCompleteTime = if ($actionJob.Job) { $actionJob.Job.PSEndTime } else { Get-Date }

        $paramUpdateAzureFailureTrace = @{
            ResourceId         = $actionJob.TargetResourceId
            Step               = $Step
            Branch             = $Branch
            Action             = $ActionName
            ActionStatus       = $actionStatus
            ActionMessage      = $actionJob.StatusMessage
            ActionCompleteTime = $actionCompleteTime
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }
}
