function Invoke-AzureFailureDelay {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [TimeSpan]$Duration
    )
    Write-PSFMessage -Level Verbose -Message "Starting delay for $Duration."


    $paramUpdateAzureFailureTrace = @{
        ResourceId        = "Delay"
        Step              = $Step
        Branch            = $Branch
        Action            = "urn:csci:microsoft:chaosStudio:timedDelay/1.0"
        ActionStatus      = "InProgress"
        ActionMessage     = ""
        ActionTriggerTime = Get-Date
    }

    Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    if ($PSCmdlet.ShouldProcess("Time Delay", "Delay")) {
        Start-Sleep -Seconds $Duration.TotalSeconds
    }

    $actionStatus = if ($WhatIfPreference) { "WhatIf" } else { "Success" }

    $paramUpdateAzureFailureTrace = @{
        ResourceId         = "Delay"
        Step               = $Step
        Branch             = $Branch
        Action             = "urn:csci:microsoft:chaosStudio:timedDelay/1.0"
        ActionStatus       = $actionStatus
        ActionMessage      = ""
        ActionCompleteTime = Get-Date
    }
    Update-AzureFailureTrace @paramUpdateAzureFailureTrace
}
