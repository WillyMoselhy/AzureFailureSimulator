function Invoke-AzureFailurePostgreSQLFlexibleServerFailover {
    [CmdletBinding()]
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

    if($RestoreSkipped){
        Write-PSFMessage -Level Verbose -Message "This action does not support restore of previously skipped actions."
    }

    if ($ForcedFailover) {
        Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), action ($ActionName):Forced Failover enabled. This may cause data loss."
    }

    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Failing Over."

        $pgSQLFlexibleServer = Get-AzPostgreSqlFlexibleServer -InputObject $target

        if ($pgSQLFlexibleServer.HighAvailabilityMode -ne "ZoneRedundant") {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Server is not configured for High Availability. Failover cannot be performed."
            $actionJobs += $false
            $actionSkipped = $true
            $actionSkipMessage = 'Not configured for High Availability'
        }
        elseif ($pgSQLFlexibleServer.HighAvailabilityState -ne "Healthy" -or $pgSQLFlexibleServer.State -ne "Ready") {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Server is not in a Healthy and Ready State. Failover cannot be performed."
            $actionJobs += $false
            $actionSkipped = $true
            $actionSkipMessage = 'Not in a Healthy and Ready State'
        }
        elseif ($pgSQLFlexibleServer.AvailabilityZone -notin $Filter) {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Server is not in the specified filter zones. Skipping failover."
            $actionJobs += $false
            $actionSkipped = $true
            $actionSkipMessage = 'Not in the specified filter zones'
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
            $actionJobs += Restart-AzPostgreSqlFlexibleServer -ResourceGroupName $rgName -Name $serverName -RestartWithFailover -FailoverMode $paramFailoverMode -AsJob
            $actionSkipped = $false
        }


        $paramUpdateAzureFailureTrace = @{
            ResourceId        = $target
            Step              = $Step
            Branch            = $Branch
            Action            = $ActionName
            ActionSkipped     = $actionSkipped
            ActionSkipMessage = $actionSkipMessage
            ActionTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }

    if ($actionJobs | Where-Object { $_ -ne $false }) {

        Write-PSFMessage -Level Verbose -Message "Waiting for PostgreSQL Flexible Server failover jobs to complete"

        $null = Wait-Job -Job ($actionJobs | Where-Object { $_ -ne $false })

        Write-PSFMessage -Level Verbose -Message "PostgreSQL Flexible Server failover jobs complete"
    }
    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        $actionCompleteTime = if ($actionJobs[$i]) { $actionJobs[$i].PSEndTime } else { Get-Date }
        if ($actionJobs[$i]) {
            $paramUpdateAzureFailureTrace = @{
                ResourceId         = $TargetResourceId[$i]
                Step               = $Step
                Branch             = $Branch
                Action             = $ActionName
                ActionCompleteTime = $actionCompleteTime
            }
            Update-AzureFailureTrace @paramUpdateAzureFailureTrace

        }

    }
}
