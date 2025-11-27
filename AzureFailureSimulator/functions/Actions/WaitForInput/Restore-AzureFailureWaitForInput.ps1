function Restore-AzureFailureWaitForInput {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $false)]
        [bool] $RequireResumeOnRestore = $false,

        [string] $ActionName = "urn:csci:microsoft:chaosStudio:waitForInput/1.0"
    )

    $targetTrace = Get-AzureFailureTrace | Where-Object {
        $_.ResourceId -eq "WaitForInput" -and
        $_.Step -eq $Step -and
        $_.Branch -eq $Branch -and
        $_.Action -eq $ActionName
    }

    if ($targetTrace.ActionStatus -eq "Skipped") {
        Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch): Action was previously skipped. Skipping restore."
        return
    }

    # Check if we need to wait for input during restore


    if (-not  $RequireResumeOnRestore) {
        Write-PSFMessage -Level Verbose -Message "Step ($Step), Branch ($Branch): Restore does not require user input. Continuing..."

        $paramUpdateAzureFailureTrace = @{
            ResourceId                = "WaitForInput"
            Step                      = $Step
            Branch                    = $Branch
            Action                    = $ActionName
            ActionStatus              = "Restored"
            ActionRestoreTriggerTime  = Get-Date
            ActionRestoreCompleteTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace

    }
    else {

        Write-PSFMessage -Level Host -Message "Step ($Step), Branch ($Branch): Waiting for user input to continue restore..."
        Write-PSFMessage -Level Host -Message "Type 'resume' and press Enter to continue the restore process."

        $actionRestoreTriggerTime = Get-Date

        # Update trace to Restoring status
        $paramUpdateAzureFailureTrace = @{
            ResourceId               = "WaitForInput"
            Step                     = $Step
            Branch                   = $Branch
            Action                   = $ActionName
            ActionStatus             = "Restoring"
            ActionMessage            = "Waiting for user input"
            ActionRestoreTriggerTime = $actionRestoreTriggerTime
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace

        try {
            $userInput = ""
            while ($userInput -ne "resume") {
                $userInput = Read-Host "Enter 'resume' to continue"
                if ($userInput -ne "resume") {
                    Write-PSFMessage -Level Warning -Message "Invalid input. Please type 'resume' to continue."
                }
            }
            Write-PSFMessage -Level Host -Message "Resuming restore process..."

            $paramUpdateAzureFailureTrace = @{
                ResourceId                = "WaitForInput"
                Step                      = $Step
                Branch                    = $Branch
                Action                    = $ActionName
                ActionStatus              = "Restored"
                ActionRestoreCompleteTime = Get-Date
            }
            Update-AzureFailureTrace @paramUpdateAzureFailureTrace
        }
        catch {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch): Failed during restore wait. Error: $($_.Exception.Message)."
            $paramUpdateAzureFailureTrace = @{
                ResourceId                = "WaitForInput"
                Step                      = $Step
                Branch                    = $Branch
                Action                    = $ActionName
                ActionStatus              = "RestoreError"
                ActionMessage             = 'Failed during restore wait - {0}' -f ($_.Exception.Message -replace "`r`n", "\n")
                ActionRestoreCompleteTime = Get-Date
            }
            Update-AzureFailureTrace @paramUpdateAzureFailureTrace
        }
    }

}
