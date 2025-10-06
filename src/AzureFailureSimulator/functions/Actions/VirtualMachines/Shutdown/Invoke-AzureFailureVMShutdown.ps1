function Invoke-AzureFailureVMShutdown {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string] $Step,

        [Parameter(Mandatory = $true)]
        [string] $Branch,

        [Parameter(Mandatory = $true)]
        [string[]] $TargetResourceId,

        [string] $Duration,
        [bool] $AbruptShutdown = $false
    )


    if ($AbruptShutdown) {
        Write-PSFMessage -Level Warning -Message "Abrupt Shutdown enabled. This may cause data loss or corruption on the target VM(s)."
    }

    $actionJobs = @()
    foreach ($target in $TargetResourceId) {
        Write-PSFMessage -Level Verbose -Message "Shutting down VM: $target"

        $actionJobs += Stop-AzVM -Id $target -Force:$AbruptShutdown -AsJob

        $paramUpdateAzureFailureTrace = @{
            ResourceId        = $target
            Step              = $Step
            Branch            = $Branch
            Action            = "urn:csci:microsoft:virtualMachine:shutdown/1.0"
            ActionTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }
    Write-PSFMessage -Level Verbose -Message "Waiting for VM shutdown jobs to complete"

    $null = Wait-Job -Job $actionJobs

    Write-PSFMessage -Level Verbose -Message "VM shutdown jobs complete"

    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        $paramUpdateAzureFailureTrace = @{
            ResourceId         = $TargetResourceId[$i]
            Step               = $Step
            Branch             = $Branch
            Action             = "urn:csci:microsoft:virtualMachine:shutdown/1.0"
            ActionCompleteTime = ($actionJobs[$i] | Receive-Job).EndTime
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }

}
