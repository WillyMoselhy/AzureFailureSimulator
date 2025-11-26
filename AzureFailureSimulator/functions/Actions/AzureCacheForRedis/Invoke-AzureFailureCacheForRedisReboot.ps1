function Invoke-AzureFailureCacheForRedisReboot {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        [ValidateSet("PrimaryNode", "SecondaryNode", "AllNodes")]
        [string] $RebootType = 'PrimaryNode',

        [string] $ShardId = '0',

        [string] $ActionName = "urn:csci:microsoft:azureClusteredCacheForRedis:reboot/1.0"


    )

    foreach ($target in $TargetResourceId) {
        Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch), Target ($target): Rebooting $($RebootType)."

        $rgName = ($target -split '/')[4]
        $serverName = ($target -split '/')[-1]

        $actionTriggerTime = Get-Date
        $actionStatus = "Success"
        $actionMessage = ''

        try {
            if ($PSCmdlet.ShouldProcess("Redis Cache", "Reboot")) {
                Reset-AzRedisCache -ResourceGroupName $rgName -Name $serverName -RebootType $RebootType -Force -ShardId $ShardId -ErrorAction Stop
                $actionStatus = if ($WhatIfPreference) { "WhatIf" } else { "Success" }
            }
            else {
                $actionStatus = "WhatIf"
            }
        }
        catch {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): Failed to reboot Redis cache. Error: $($_.Exception.Message)."
            $actionStatus = "Error"
            $actionMessage = 'Failed to reboot Redis cache - {0}' -f ($_.Exception.Message -replace "`r`n", "\n")
        }

        $actionCompleteTime = Get-Date

        $paramUpdateAzureFailureTrace = @{
            ResourceId         = $target
            Step               = $Step
            Branch             = $Branch
            Action             = $ActionName
            ActionStatus       = $actionStatus
            ActionMessage      = $actionMessage
            ActionTriggerTime  = $actionTriggerTime
            ActionCompleteTime = $actionCompleteTime

        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }

}
