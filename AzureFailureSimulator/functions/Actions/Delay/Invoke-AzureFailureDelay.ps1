function Invoke-AzureFailureDelay {
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
        ActionTriggerTime = Get-Date
    }
    Update-AzureFailureTrace @paramUpdateAzureFailureTrace

    Start-Sleep -Seconds $Duration.TotalSeconds

    $paramUpdateAzureFailureTrace = @{
        ResourceId         = "Delay"
        Step               = $Step
        Branch             = $Branch
        Action             = "urn:csci:microsoft:chaosStudio:timedDelay/1.0"
        ActionCompleteTime = Get-Date
    }
    Update-AzureFailureTrace @paramUpdateAzureFailureTrace
}
