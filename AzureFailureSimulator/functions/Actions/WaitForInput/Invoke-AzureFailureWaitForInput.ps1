function Invoke-AzureFailureWaitForInput {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $false)]
        [bool] $RequireResumeOnRestore = $false,

        [string] $ActionName = "urn:csci:microsoft:chaosStudio:waitForInput/1.0"
    )

    Write-PSFMessage -Level Host -Message "Step ($Step), Branch ($Branch): Waiting for user input to continue..."
    Write-PSFMessage -Level Host -Message "Type 'resume' and press Enter to continue the experiment."

    $actionTriggerTime = Get-Date
    $actionStatus = "InProgress"

    $paramUpdateAzureFailureTrace = @{
        ResourceId        = "WaitForInput"
        Step              = $Step
        Branch            = $Branch
        Action            = $ActionName
        ActionStatus      = $actionStatus
        ActionTriggerTime = $actionTriggerTime
        ActionMessage     = "Waiting for user input"
        TargetDetails     = @{
            RequireResumeOnRestore = $RequireResumeOnRestore
        }
    }
    Update-AzureFailureTrace @paramUpdateAzureFailureTrace

    if ($PSCmdlet.ShouldProcess("Experiment", "Wait for user input")) {
        $userInput = ""
        while ($userInput -ne "resume") {
            $userInput = Read-Host "Enter 'resume' to continue"
            if ($userInput -ne "resume") {
                Write-PSFMessage -Level Warning -Message "Invalid input. Please type 'resume' to continue."
            }
        }
        Write-PSFMessage -Level Host -Message "Resuming experiment execution..."
        $actionStatus = "Success"
    }
    else {
        Write-PSFMessage -Level Host -Message "WhatIf: Would wait for user to type 'resume' to continue."
        $actionStatus = "WhatIf"
    }

    $actionCompleteTime = Get-Date

    $paramUpdateAzureFailureTrace = @{
        ResourceId         = "WaitForInput"
        Step               = $Step
        Branch             = $Branch
        Action             = $ActionName
        ActionStatus       = $actionStatus
        ActionCompleteTime = $actionCompleteTime
    }
    Update-AzureFailureTrace @paramUpdateAzureFailureTrace
}
