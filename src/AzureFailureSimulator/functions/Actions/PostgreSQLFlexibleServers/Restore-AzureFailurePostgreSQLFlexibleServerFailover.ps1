function Restore-AzureFailurePostgreSQLFlexibleServerFailover {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        [string] $Duration,

        [bool] $ForcedFailover = $false #This parameter is ignored in restore operation.

    )

    $actionName = "urn:csci:microsoft:DBforPostgreSLFlexibleServers:failover/1.0" #TODO: Apply this logic to all other actions.


    if ($ForcedFailover) {
        Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), action ($actionName):Forced Failover enabled. This may cause data loss."
    }

    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Failing Over."

        $targetTrace = Get-AzureFailureTrace | Where-Object {
            $_.ResourceId -eq $target -and
            $_.Step -eq $Step -and
            $_.Branch -eq $Branch -and
            $_.Action -eq $actionName
        }

        if ($targetTrace.ActionSkipped) {
            Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Action was previously skipped. Skipping restore."
            $actionsJobs += $false
            continue
        }

        $rgName = ($target -split '/')[4]
        $serverName = ($target -split '/')[-1]
        $actionJobs += Restart-AzPostgreSqlFlexibleServer -ResourceGroupName $rgName -Name $serverName -RestartWithFailover -FailoverMode 'PlannedFailover' -AsJob

        $paramUpdateAzureFailureTrace = @{
            ResourceId               = $target
            Step                     = $Step
            Branch                   = $Branch
            Action                   = $actionName
            ActionRestoreTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }

    if ($actionJobs | Where-Object { $_ -ne $false }) {

        Write-PSFMessage -Level Verbose -Message "Waiting for PostgreSQL Flexible Server failover jobs to complete"

        $null = Wait-Job -Job $actionJobs

        Write-PSFMessage -Level Verbose -Message "PostgreSQL Flexible Server failover jobs complete"
    }
    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        $actionCompleteTime = if ($actionJobs[$i]) { $actionJobs[$i].PSEndTime } else { Get-Date }
        if ($actionJobs[$i]) {
            $paramUpdateAzureFailureTrace = @{
                ResourceId                = $TargetResourceId[$i]
                Step                      = $Step
                Branch                    = $Branch
                Action                    = $actionName
                ActionRestoreCompleteTime = $actionCompleteTime
            }
            Update-AzureFailureTrace @paramUpdateAzureFailureTrace
        }
    }
}
