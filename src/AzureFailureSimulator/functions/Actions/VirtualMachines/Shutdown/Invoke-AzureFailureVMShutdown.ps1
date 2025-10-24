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

        $vmStatus = Get-AzVM -ResourceId $target -Status
        if ( $vmStatus.Statuses[1].Code -eq "PowerState/running") {
            $actionJobs += Stop-AzVM -Id $target -Force:$AbruptShutdown -AsJob
            $actionSkipped = $false
        }
        else {
            Write-PSFMessage -Level Warning -Message "Step ($Step), Branch ($Branch), Target ($target): VM is not in 'running' state. Current state: $($vmStatus.Statuses[1].DisplayStatus). Skipping shutdown."
            $actionsJobs += $false
            $actionSkipped = $true
            $actionSkipMessage = 'VM is not in running state'
        }

        $paramUpdateAzureFailureTrace = @{
            ResourceId        = $target
            Step              = $Step
            Branch            = $Branch
            Action            = "urn:csci:microsoft:virtualMachine:shutdown/1.0"
            ActionSkipped     = $actionSkipped
            ActionSkipMessage = $actionSkipMessage
            ActionTriggerTime = Get-Date
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }
    if ($actionJobs | Where-Object { $_ -ne $false })  {

        Write-PSFMessage -Level Verbose -Message "Waiting for VM shutdown jobs to complete"

        $null = Wait-Job -Job ($actionJobs | Where-Object { $_ -ne $false })

        Write-PSFMessage -Level Verbose -Message "VM shutdown jobs complete"
    }
    for ($i = 0; $i -lt $TargetResourceId.Count; $i++) {
        $actionCompleteTime = if ($actionJobs[$i]) { ($actionJobs[$i] | Receive-Job).EndTime } else { Get-Date }
        $paramUpdateAzureFailureTrace = @{
            ResourceId         = $TargetResourceId[$i]
            Step               = $Step
            Branch             = $Branch
            Action             = "urn:csci:microsoft:virtualMachine:shutdown/1.0"
            ActionCompleteTime = $actionCompleteTime
        }
        Update-AzureFailureTrace @paramUpdateAzureFailureTrace
    }

}
