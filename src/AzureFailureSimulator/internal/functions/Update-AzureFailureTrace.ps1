function Update-AzureFailureTrace {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string] $TraceOutputPath = $Script:TraceOutputPath,

        [Parameter(Mandatory = $true)]
        [string] $ResourceId,

        [Parameter(Mandatory = $false)]
        [hashtable] $TargetDetails,

        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string] $Action,

        [Parameter(Mandatory = $false)]
        [bool] $ActionSkipped,

        [Parameter(Mandatory = $false)]
        [string] $ActionSkipMessage,

        [Parameter(Mandatory = $false)]
        [DateTime] $ActionTriggerTime,

        [Parameter(Mandatory = $false)]
        [DateTime] $ActionCompleteTime,

        [Parameter(Mandatory = $false)]
        [DateTime] $ActionRestoreTriggerTime,

        [Parameter(Mandatory = $false)]
        [DateTime] $ActionRestoreCompleteTime

    )
    # Find if an entry exist for the current ResourceId, Step, Branch, Action
    $existingEntry = $script:tracerOutput | Where-Object {
        $_.ResourceId -eq $ResourceId -and
        $_.Step -eq $Step -and
        $_.Branch -eq $Branch -and
        $_.Action -eq $Action
    }
    if ($existingEntry) {
        if ($ActionTriggerTime) {
            $existingEntry.ActionTriggerTime = $ActionTriggerTime
        }
        if ($ActionCompleteTime) {
            if($existingEntry.ActionSkipped) {
                $existingEntry.ActionCompleteTime = $existingEntry.ActionTriggerTime
            }
            else{
                $existingEntry.ActionCompleteTime = $ActionCompleteTime
            }
            if ($existingEntry.ActionTriggerTime) {
                $existingEntry.ActionDuration = $ActionCompleteTime - $existingEntry.ActionTriggerTime
            }
        }
        if ($ActionRestoreTriggerTime) {
            $existingEntry.ActionRestoreTriggerTime = $ActionRestoreTriggerTime
        }
        if ($ActionRestoreCompleteTime) {
            if($existingEntry.ActionSkipped) {
                $existingEntry.ActionRestoreCompleteTime = $existingEntry.ActionRestoreTriggerTime
            }
            else{
                $existingEntry.ActionRestoreCompleteTime = $ActionRestoreCompleteTime
            }
            if ($existingEntry.ActionRestoreTriggerTime) {
                $existingEntry.ActionRestoreDuration = $ActionRestoreCompleteTime - $existingEntry.ActionRestoreTriggerTime
            }
        }
        if ($existingEntry.ActionCompleteTime -and $existingEntry.ActionRestoreCompleteTime) {
            $existingEntry.DowntimeDuration = $existingEntry.ActionRestoreCompleteTime - $existingEntry.ActionCompleteTime
        }
        # Update the existing entry
    }
    else {
        # Create a new entry
        $newEntry = [PSCustomObject]@{
            ResourceId                = $ResourceId
            Step                      = $Step
            Branch                    = $Branch
            TargetDetails             = $TargetDetails
            TargetDetailsJson         = if ($TargetDetails) { $TargetDetails | ConvertTo-Json -Compress -Depth 3 } else { $null }
            Action                    = $Action
            ActionSkipped             = $ActionSkipped
            ActionSkipMessage         = $ActionSkipMessage
            ActionTriggerTime         = if ($ActionTriggerTime) { $ActionTriggerTime }         else { $null }
            ActionCompleteTime        = if ($ActionCompleteTime) { $ActionCompleteTime }        else { $null }
            ActionDuration            = $null

            ActionRestoreTriggerTime  = if ($ActionRestoreTriggerTime) { $ActionRestoreTriggerTime }  else { $null }
            ActionRestoreCompleteTime = if ($ActionRestoreCompleteTime) { $ActionRestoreCompleteTime } else { $null }
            ActionRestoreDuration     = $null

            DowntimeDuration          = $null
        }
        if ($newEntry.ActionCompleteTime -and $newEntry.ActionTriggerTime) {
            $newEntry.ActionDuration = $newEntry.ActionCompleteTime - $newEntry.ActionTriggerTime
        }
        if ($newEntry.ActionRestoreCompleteTime -and $newEntry.ActionRestoreTriggerTime) {
            $newEntry.ActionRestoreDuration = $newEntry.ActionRestoreCompleteTime - $newEntry.ActionRestoreTriggerTime
        }
        if ($newEntry.ActionCompleteTime -and $newEntry.ActionRestoreCompleteTime) {
            $newEntry.DowntimeDuration = $newEntry.ActionRestoreCompleteTime - $newEntry.ActionCompleteTime
        }
        $script:tracerOutput += $newEntry
    }

    if ($TraceOutputPath) {
        Write-PSFMessage -Level Verbose -Message "Exporting trace output to $TraceOutputPath"
        $script:tracerOutput | Select-Object -ExcludeProperty TargetDetails| Export-Csv -Path $TraceOutputPath
    }
}