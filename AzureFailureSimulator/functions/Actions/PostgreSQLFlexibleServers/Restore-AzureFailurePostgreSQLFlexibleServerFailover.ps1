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

        [bool] $ForcedFailover = $false, #This parameter is ignored in restore operation.

        [string] $ActionName = "urn:csci:microsoft:DBforPostgreSLFlexibleServers:failover/1.0"

    )


    if ($ForcedFailover) {
        Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), action ($ActionName):Forced Failover enabled. This may cause data loss."
    }

    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Failing Over."

        $targetTrace = Get-AzureFailureTrace | Where-Object {
            $_.ResourceId -eq $target -and
            $_.Step -eq $Step -and
            $_.Branch -eq $Branch -and
            $_.Action -eq $ActionName
        }

        if ($targetTrace.ActionStatus -eq "Skipped") {
            Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Action was previously skipped. Skipping restore."
            $actionsJobs += $false
            continue
        }

        $rgName = ($target -split '/')[4]
        $serverName = ($target -split '/')[-1]

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

        $actionJobs += Restart-AzPostgreSqlFlexibleServer -ResourceGroupName $rgName -Name $serverName -RestartWithFailover -FailoverMode 'PlannedFailover' -AsJob
    }

    if ($actionJobs | Where-Object { $_ -ne $false }) {

        Write-PSFMessage -Level Verbose -Message "Waiting for PostgreSQL Flexible Server failover jobs to complete"

        $null = Wait-Job -Job ($actionJobs | Where-Object { $_ -ne $false })

        Write-PSFMessage -Level Verbose -Message "PostgreSQL Flexible Server failover jobs complete"
    }
    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        $actionCompleteTime = if ($actionJobs[$i]) { $actionJobs[$i].PSEndTime } else { Get-Date }
        if ($actionJobs[$i]) {
            try {
                $null = $actionJobs[$i] | Receive-Job -ErrorAction Stop
                $paramUpdateAzureFailureTrace = @{
                    ResourceId                = $TargetResourceId[$i]
                    Step                      = $Step
                    Branch                    = $Branch
                    Action                    = $ActionName
                    ActionStatus              = "Restored"
                    ActionRestoreCompleteTime = $actionCompleteTime
                }
                Update-AzureFailureTrace @paramUpdateAzureFailureTrace
            }
            catch {
                Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($($TargetResourceId[$i])): Failed to restore PostgreSQL Flexible Server. Error: $($_.Exception.Message)."
                $paramUpdateAzureFailureTrace = @{
                    ResourceId                = $TargetResourceId[$i]
                    Step                      = $Step
                    Branch                    = $Branch
                    Action                    = $ActionName
                    ActionStatus              = "RestoreError"
                    ActionMessage             = 'Failed to restore PostgreSQL Flexible Server - {0}' -f ($_.Exception.Message -replace "`r`n", "\n")
                    ActionRestoreCompleteTime = Get-Date
                }
                Update-AzureFailureTrace @paramUpdateAzureFailureTrace
            }
        }
    }
}
